# Bazzite build-pipeline investigation

_Compiled: 2026-06-06. Reference: [`ublue-os/bazzite` `.github/workflows/build.yml`](https://github.com/ublue-os/bazzite/blob/main/.github/workflows/build.yml) at the time of writing._

This note answers Objective 4 from `claude_objective.txt`: how Bazzite has changed its rechunker and what else from their pipeline DistinctionOS should adopt. It is intentionally a survey, not a refactor — adoption is left to deliberate follow-up commits.

---

## 1. Rechunker — the headline change

### What Bazzite was using (and DistinctionOS still uses)

`.github/workflows/build.yml` of DistinctionOS:

```yaml
- name: Run Rechunker
  id: rechunk
  uses: hhd-dev/rechunk@v1.2.4
  with:
    rechunk: "ghcr.io/hhd-dev/rechunk:v1.2.3"
    ref: "localhost/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}"
    prev-ref: "${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}"
    max-layers: 90
```

`hhd-dev/rechunk` is the external action that spawns a separate container, mounts the build, and recomposes layers. It is a wrapper around an earlier `rpm-ostree`-based chunker.

### What Bazzite uses now

```yaml
- name: Run Rechunker
  id: rechunk
  run: |
    container=$(sudo buildah from raw-img)
    mnt=$(sudo buildah mount $container)
    sudo bash -c "rm -rf $mnt/run/.* $mnt/run/* $mnt/tmp/.* $mnt/tmp/*"
    sudo buildah umount $container
    sudo buildah commit --identity-label=false --rm $container raw-img

    sudo podman run --rm --privileged --volume /var/lib/containers:/var/lib/containers \
        localhost/raw-img \
        rpm-ostree compose build-chunked-oci \
        --bootc --max-layers 127 --format-version 2 \
        --from localhost/raw-img --output containers-storage:localhost/chunked-img
    sudo podman untag raw-img

    echo "ref=containers-storage:localhost/chunked-img" >> "$GITHUB_OUTPUT"
```

Two things are different:

1. **No external action.** The chunker is invoked as `rpm-ostree compose build-chunked-oci`, which is a first-party command shipped in modern `rpm-ostree` (in the same image being built — Bazzite uses the image's own `rpm-ostree` against itself via `podman run`). No third-party container pull, no separate version pin, no maintenance dependency on `hhd-dev/rechunk`.
2. **`--format-version 2`.** This is the version of chunking metadata. v2 is the format the integrated chunker produces; `hhd-dev/rechunk` (as of v1.2.4) still emits v1. v2 is what current `bootc` clients prefer, and it computes deltas more cheaply for end users.

Bazzite's commit log on their build pipeline credits this swap with materially shorter rechunk times on the GHA runner and smaller per-update downloads for end users, because v2 is more granular about which chunks actually changed.

### Recommendation for DistinctionOS

**Adopt, but on a branch.** The swap is mechanical but it changes the artefact format end users see; a botched migration ships a broken update to everyone on `:latest`. Suggested order:

1. Branch from `main`, rip out the `hhd-dev/rechunk@v1.2.4` step, replace with the four-line `rpm-ostree compose build-chunked-oci ...` invocation above.
2. Push the branch with the `testing` tag enabled (the workflow already does this for non-`main` refs — see line 83 of `build.yml`). Confirm the resulting image boots cleanly and that `bootc upgrade` from a v1-chunked install to the v2-chunked image works.
3. Once verified, merge to `main`. The first `:latest` build will be a one-time bigger download for existing users (format migration); subsequent updates should be smaller than the v1 baseline.
4. Drop the `actions/checkout`-pulled rechunker artefact and `Remove Rechunker image` cleanup step — they become dead.

There are two preconditions worth noting:

- The base image must ship `rpm-ostree` with `compose build-chunked-oci` support. Bazzite-gnome already does (it inherits from a modern Fedora bootc base), so DistinctionOS gets it for free.
- The new step uses `buildah` directly (`buildah from raw-img`), so the image must be in rootful container storage at that point. DistinctionOS already builds rootful (`sudo buildah bud`), so that's fine — only the tag (`localhost/distinctionos:latest`) would need to be aliased to `raw-img` or the script adjusted to use the existing tag.

---

## 2. Push to GHCR — retry pattern (Objective 2, covered separately)

Bazzite wraps the push step with `nick-fields/retry@v4.0.0` (3 attempts, 15 s backoff, 10 min timeout) and pushes via `skopeo copy` rather than `redhat-actions/push-to-registry`. DistinctionOS picked up this exact pattern in the same change set as this document.

---

## 3. Other pipeline patterns worth considering

Listed in rough order of effort-vs-benefit.

### 3.1 BTRFS-backed `/var/lib/containers` (low effort, large win)

Bazzite mounts the GHA runner's spare `/mnt` partition as BTRFS for podman storage before any build runs:

```yaml
- name: Mount BTRFS for podman storage
  uses: ublue-os/container-storage-action@main
  with:
    target-dir: /var/lib/containers
```

GHA runners come with a small root partition and a much larger ephemeral `/mnt`. The default overlayfs-on-ext4 setup means large images (multi-GB layered builds) saturate disk-write headroom and can run the root partition out of space mid-rechunk. Switching to BTRFS on `/mnt` doubles available space and gives reflink-aware fast copies.

Bazzite gates it on `if: ${{ steps.check_mnt.outputs.mnt_is_there == '1' }}`, since not every runner image has `/mnt` mounted. The check is a one-liner.

**Recommendation:** adopt. It is a drop-in step and the failure mode it fixes (OOD during rechunk) is one that will eventually bite DistinctionOS too.

### 3.2 SBOM generation and registry attachment (medium effort, supply-chain value)

Bazzite generates a Syft SBOM of the final image and attaches it to the registry as an OCI artifact via `oras attach`, then signs the SBOM with cosign and registers a GitHub attestation (`actions/attest`).

This is a four-step add (Syft download, generate-sbom, oras attach, cosign sign) and it costs ~30 s on the GHA runner. The pay-off is that anyone consuming `ghcr.io/phantomcortex/distinctionos:latest` can ask "what packages are in this image?" without pulling it. It is also a precondition for SLSA L3-style claims if DistinctionOS ever wants them.

**Recommendation:** nice-to-have, not urgent. Defer until there is a reason to want it (publishing to a wider audience, third-party security review, etc.).

### 3.3 dgoss runtime tests (medium effort, sanity-check value)

Bazzite runs `dgoss` (Docker-Goss) against the chunked image before push:

```yaml
- name: Run goss tests
  run: |
    sudo tests/dgoss/dgoss-tests.sh tests/dgoss/tests.d "${{ steps.rechunk.outputs.ref }}"
```

The tests live in `tests/dgoss/tests.d/` and assert things like "binary X exists", "service Y is enabled", "file Z has the expected SHA". They run the image as a transient container and execute the assertions inside.

DistinctionOS already has a strong build-time validator (`build_files/08-validate.sh`) which covers the same ground — ldconfig integrity, icon caches, pixbuf loaders, critical binaries — but it runs *inside* the build, not against the post-rechunk artefact. A small dgoss test suite would catch any regression introduced by the chunker itself (e.g. a file lost to layer reshuffling).

**Recommendation:** low priority. The build-time validator is doing most of this work already. Worth revisiting only if a rechunker regression ever slips past `08-validate.sh` into a release.

### 3.4 `actions/attest` for build provenance (low effort, supply-chain value)

```yaml
- name: Attestation
  uses: actions/attest@v4.1.0
  with:
    subject-name: ${{ steps.base.outputs.output_image }}
    subject-digest: ${{ steps.push.outputs.digest }}
    push-to-registry: true
```

This is a one-step add and produces a GitHub-signed attestation that "this digest was built by this workflow run on this commit". Pairs naturally with cosign signing — cosign proves the publisher; attest proves the build context.

**Recommendation:** cheap to add, defer until SBOM is being considered (3.2). They tend to ship together.

### 3.5 Matrix builds (high effort, not currently applicable)

Bazzite builds a matrix of variants (`bazzite`, `bazzite-gnome`, `bazzite-nvidia`, etc.) in one workflow. DistinctionOS is single-variant by design. Not applicable.

### 3.6 Fedora-version detection from the base label

Bazzite reads `org.opencontainers.image.version` from the base image rather than hard-coding the Fedora major. DistinctionOS already does the same (`build.yml:119-121`), so this is already adopted.

---

## 4. Suggested rollout order

If everything in this document were to be adopted, the order with the best risk-adjusted value would be:

1. **Native chunker** (§1) — biggest user-facing win, mechanical change, needs validation on `testing` first.
2. **BTRFS container storage** (§3.1) — fixes a latent runner-out-of-disk failure mode that gets worse as the image grows.
3. **`actions/attest` + SBOM** (§3.4 + §3.2) — only if/when DistinctionOS wants attestable supply chain claims.
4. **dgoss tests** (§3.3) — only if a chunker regression ever slips past `08-validate.sh`.

### Status

Already on `main`:

- Retry-wrapped push (Objective 2 of the original brief).
- Pre-build syntax gate (Objective 3).

Implemented on branch `build-pipeline-upgrade` (this doc lands with that branch):

- §1 — native rechunker (`rpm-ostree compose build-chunked-oci --bootc --max-layers 127 --format-version 2`), with labels baked in via `buildah config` beforehand and pushes routed through rootful `containers-storage`.
- §3.1 — BTRFS-backed `/var/lib/containers` on `/mnt`, gated on `mountpoint /mnt`.

Validation plan before merging the branch to `main`:

1. Push the branch; let the workflow tag it `:testing` and complete a chunk + push end-to-end.
2. On a test machine, `bootc switch ghcr.io/phantomcortex/distinctionos:testing` and reboot. Verify boot and that subsequent `bootc upgrade` from `:testing` to a later `:testing` build produces a small delta (the v2-format win).
3. Confirm `bootc upgrade` from a `:latest` install (v1-chunked) to `:testing` (v2-chunked) succeeds — this is the format-migration path real users will follow.
4. Merge. First `:latest` build after merge is a one-time bigger download per user; subsequent builds amortize back down.

Deferred (§3.2 / §3.3 / §3.4) — no work on this branch.
