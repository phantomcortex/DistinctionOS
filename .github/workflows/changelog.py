#!/usr/bin/env python3
"""
Generate a Bazzite-style changelog for DistinctionOS releases.

Produces a release page with:
  - Pinned major packages (Kernel, GNOME, Mesa, Gamescope) at the top
  - Commit messages between builds
  - Full package diff table (added/removed/updated)
  - Rebase instructions

Reads package data from the `dev.hhd.rechunk.info` OCI label embedded by
Rechunker, and derives the commit range from `org.opencontainers.image.revision`.
"""

import subprocess
import json
import re
import time
import argparse
import sys
from typing import Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_REGISTRY = "docker://ghcr.io/phantomcortex/"
RETRIES = 3
RETRY_WAIT = 5
FEDORA_PATTERN = re.compile(r"\.fc\d{1,2}")
SIG_PATTERN = re.compile(r"^sha256-.*\.sig$")
GITHUB_REPO = "phantomcortex/distinctionos"

# Major / pinned packages shown prominently at the top of every release.
# Display Name -> RPM package name used as the lookup key in rechunk metadata.
PINNED_PACKAGES: List[Tuple[str, str]] = [
    ("Kernel",    "kernel-cachyos-lto"),
    ("GNOME",     "gnome-control-center-filesystem"),
    ("Mesa",      "mesa-filesystem"),
    ("Gamescope", "gamescope"),
    ("Ptyxis", "ptyxis"),
]

# Package names that appear in the pinned table are excluded from the
# full diff table to avoid duplication.
PINNED_PKG_NAMES = {pkg for _, pkg in PINNED_PACKAGES}


# ---------------------------------------------------------------------------
# Registry helpers
# ---------------------------------------------------------------------------

def run_skopeo_inspect(registry: str, image: str, tag: str) -> Dict:
    """Fetch the manifest JSON for a given registry/image:tag using skopeo."""
    ref = f"{registry}{image}:{tag}"
    for attempt in range(1, RETRIES + 1):
        try:
            output = subprocess.run(
                ["skopeo", "inspect", ref],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            return json.loads(output)
        except subprocess.CalledProcessError:
            if attempt < RETRIES:
                print(f"  Retry {attempt}/{RETRIES} for {ref}", file=sys.stderr)
                time.sleep(RETRY_WAIT)
            else:
                raise


def get_all_tags(registry: str, image: str) -> List[str]:
    """Retrieve all non-signature, non-digest tags sorted lexicographically."""
    manifest = run_skopeo_inspect(registry, image, "latest")
    tags = manifest.get("RepoTags", []) or []
    filtered = [
        t for t in tags
        if not t.endswith(".0")
        and not SIG_PATTERN.match(t)
        and not t.startswith("sha256-")
    ]
    return sorted(filtered)


def select_two_latest(tags: List[str]) -> Tuple[str, str]:
    """Return (previous_tag, current_tag) from the sorted tag list."""
    if len(tags) < 2:
        raise ValueError(f"Not enough tags to diff, found: {tags}")
    return tags[-2], tags[-1]


# ---------------------------------------------------------------------------
# Package extraction
# ---------------------------------------------------------------------------

def extract_packages(info: Dict) -> Dict[str, str]:
    """Extract {package: version} from the rechunk metadata label."""
    labels = info.get("Labels", {}) or {}
    data = labels.get("dev.hhd.rechunk.info")
    if not data:
        return {}
    packages = json.loads(data).get("packages", {})
    return {pkg: re.sub(FEDORA_PATTERN, "", ver) for pkg, ver in packages.items()}


def extract_fedora_version(info: Dict) -> str:
    """Extract the Fedora version number from the image manifest.

    Tries the rechunk package list first (fedora-release), then falls back
    to parsing the .fcNN suffix from any package version string.
    """
    labels = info.get("Labels", {}) or {}
    data = labels.get("dev.hhd.rechunk.info")
    if data:
        packages = json.loads(data).get("packages", {})
        # fedora-release version is just the Fedora number (e.g. "43")
        fr = packages.get("fedora-release")
        if fr:
            m = re.match(r"(\d+)", fr)
            if m:
                return m.group(1)
        # Fallback: scan any package for the .fcNN suffix
        for ver in packages.values():
            m = re.search(r"\.fc(\d+)", ver)
            if m:
                return m.group(1)
    return ""


def get_version(packages: Dict[str, str], rpm_name: str) -> Optional[str]:
    """Look up a single package version, returning None if absent."""
    return packages.get(rpm_name)


# ---------------------------------------------------------------------------
# Pinned packages table
# ---------------------------------------------------------------------------

def build_pinned_table(
    prev_pkgs: Dict[str, str],
    curr_pkgs: Dict[str, str],
) -> str:
    """Render the 'Major Packages' markdown table."""
    lines = [
        "### Major Packages",
        "",
        "| Name | Version |",
        "| --- | --- |",
    ]
    for display_name, rpm_name in PINNED_PACKAGES:
        prev_ver = get_version(prev_pkgs, rpm_name)
        curr_ver = get_version(curr_pkgs, rpm_name)
        if curr_ver is None:
            lines.append(f"| **{display_name}** | *not found* |")
        elif prev_ver and prev_ver != curr_ver:
            lines.append(f"| **{display_name}** | {prev_ver} -> {curr_ver} |")
        else:
            lines.append(f"| **{display_name}** | {curr_ver} |")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Full package diff
# ---------------------------------------------------------------------------

def build_package_diff(
    prev_pkgs: Dict[str, str],
    curr_pkgs: Dict[str, str],
) -> str:
    """Render the full added/removed/updated package diff table.

    Packages already shown in the pinned table are excluded.
    """
    added   = (set(curr_pkgs) - set(prev_pkgs)) - PINNED_PKG_NAMES
    removed = (set(prev_pkgs) - set(curr_pkgs)) - PINNED_PKG_NAMES
    changed = {
        pkg for pkg in (prev_pkgs.keys() & curr_pkgs.keys())
        if prev_pkgs[pkg] != curr_pkgs[pkg] and pkg not in PINNED_PKG_NAMES
    }

    if not added and not removed and not changed:
        return ""

    # De-duplicate packages whose version string is identical to one we already
    # listed (sub-packages from the same SRPM).
    seen_versions: set = set()
    lines = [
        "### Package Changes",
        "",
        "| | Name | Previous | New |",
        "| --- | --- | --- | --- |",
    ]
    for pkg in sorted(added):
        v = curr_pkgs[pkg]
        if v in seen_versions:
            continue
        seen_versions.add(v)
        lines.append(f"| ✨ | {pkg} | | {v} |")
    for pkg in sorted(removed):
        v = prev_pkgs[pkg]
        if v in seen_versions:
            continue
        seen_versions.add(v)
        lines.append(f"| ❌ | {pkg} | {v} | |")
    for pkg in sorted(changed):
        new_v = curr_pkgs[pkg]
        if new_v in seen_versions:
            continue
        seen_versions.add(new_v)
        lines.append(f"| 🔄 | {pkg} | {prev_pkgs[pkg]} | {new_v} |")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Commit log
# ---------------------------------------------------------------------------

def get_commits(
    prev_manifest: Dict,
    curr_manifest: Dict,
    workdir: Optional[str],
) -> str:
    """Generate a markdown table of commits between two builds.

    Uses the `org.opencontainers.image.revision` label to determine the
    git SHA range, then runs `git log` in the provided workdir.
    """
    if workdir is None:
        return ""

    prev_labels = prev_manifest.get("Labels", {}) or {}
    curr_labels = curr_manifest.get("Labels", {}) or {}
    prev_sha = prev_labels.get("org.opencontainers.image.revision", "")
    curr_sha = curr_labels.get("org.opencontainers.image.revision", "")

    if not prev_sha or not curr_sha or prev_sha == curr_sha:
        return ""

    try:
        result = subprocess.run(
            [
                "git", "log",
                "--pretty=format:%H|%h|%an|%s",
                f"{prev_sha}..{curr_sha}",
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=workdir,
        )
    except subprocess.CalledProcessError:
        return ""

    raw = result.stdout.decode().strip()
    if not raw:
        return ""

    lines = [
        "### Commits",
        "",
        "| Hash | Subject | Author |",
        "| --- | --- | --- |",
    ]
    for entry in raw.splitlines():
        parts = entry.split("|", 3)
        if len(parts) < 4:
            continue
        full_hash, short_hash, author, subject = parts
        # Skip merge commits
        if subject.lower().startswith("merge"):
            continue
        link = f"https://github.com/{GITHUB_REPO}/commit/{full_hash}"
        lines.append(f"| [**{short_hash}**]({link}) | {subject} | {author} |")

    if len(lines) <= 4:
        # Only header rows, no actual commits after filtering
        return ""

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Changelog assembly
# ---------------------------------------------------------------------------

def generate_changelog(
    image: str,
    prev_tag: str,
    curr_tag: str,
    prev_manifest: Dict,
    curr_manifest: Dict,
    prev_pkgs: Dict[str, str],
    curr_pkgs: Dict[str, str],
    workdir: Optional[str] = None,
    handwritten: str = "",
) -> Tuple[str, str, str]:
    """Build the full markdown changelog, release title, and tag.

    Returns:
        (changelog_md, title, tag)
    """
    tag = curr_tag
    # Extract Fedora version and date portion from tag for title
    # Tag format is "latest.YYYYMMDD" or "YYYYMMDD"
    fedora_ver = extract_fedora_version(curr_manifest)
    date_part = curr_tag.split(".")[-1] if "." in curr_tag else curr_tag
    fedora_label = f"F{fedora_ver}.{date_part}" if fedora_ver else date_part
    title = f"DistinctionOS: latest {fedora_label}"

    sections: List[str] = []

    # Intro
    if handwritten:
        sections.append(handwritten)
    else:
        sections.append(
            f"Automatically generated changelog for **{image}:{curr_tag}**.\n\n"
            f"Compared against previous build `{prev_tag}`.\n"
            f"One package per new version shown."
        )

    # Pinned packages
    sections.append(build_pinned_table(prev_pkgs, curr_pkgs))

    # Commits
    commits_md = get_commits(prev_manifest, curr_manifest, workdir)
    if commits_md:
        sections.append(commits_md)

    # Package diff
    diff_md = build_package_diff(prev_pkgs, curr_pkgs)
    if diff_md:
        sections.append(diff_md)

    # Rebase instructions
    sections.append(
        "### How to rebase\n\n"
        "For current users, run the following to rebase to this version:\n\n"
        "```bash\n"
        f"sudo bootc switch ghcr.io/{GITHUB_REPO}:latest\n"
        f"# Or pin to this specific build:\n"
        f"sudo bootc switch ghcr.io/{GITHUB_REPO}:{curr_tag}\n"
        "```"
    )

    changelog_md = "\n\n".join(sections) + "\n"
    return changelog_md, title, tag


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate a Bazzite-style changelog for a single UBlue image"
    )
    parser.add_argument("image", help="Image name (e.g. distinctionos)")
    parser.add_argument("env_output", help="Path to write TITLE/TAG env file")
    parser.add_argument("changelog_output", help="Path to write changelog markdown")
    parser.add_argument(
        "--registry",
        default=DEFAULT_REGISTRY,
        help=f"Registry prefix (default: {DEFAULT_REGISTRY})",
    )
    parser.add_argument(
        "--workdir",
        default=None,
        help="Git working directory for commit log generation",
    )
    parser.add_argument(
        "--handwritten",
        default="",
        help="Optional handwritten message to replace the auto-generated intro",
    )
    args = parser.parse_args()

    registry = args.registry
    image = args.image

    # 1. Discover tags
    print(f"Inspecting {registry}{image}...", file=sys.stderr)
    tags = get_all_tags(registry, image)
    print(f"Found {len(tags)} tags", file=sys.stderr)

    prev_tag, curr_tag = select_two_latest(tags)
    print(f"Diffing {prev_tag} -> {curr_tag}", file=sys.stderr)

    # 2. Fetch manifests for both tags
    prev_manifest = run_skopeo_inspect(registry, image, prev_tag)
    curr_manifest = run_skopeo_inspect(registry, image, curr_tag)

    # 3. Extract package lists
    prev_pkgs = extract_packages(prev_manifest)
    curr_pkgs = extract_packages(curr_manifest)
    print(
        f"Packages: {len(prev_pkgs)} (prev) / {len(curr_pkgs)} (curr)",
        file=sys.stderr,
    )

    # 4. Generate changelog
    changelog_md, title, tag = generate_changelog(
        image=image,
        prev_tag=prev_tag,
        curr_tag=curr_tag,
        prev_manifest=prev_manifest,
        curr_manifest=curr_manifest,
        prev_pkgs=prev_pkgs,
        curr_pkgs=curr_pkgs,
        workdir=args.workdir,
        handwritten=args.handwritten.strip(),
    )

    # 5. Write env file (sourced by GitHub Actions)
    with open(args.env_output, "w") as f:
        # Shell-safe quoting
        f.write(f'TITLE="{title}"\n')
        f.write(f"TAG={tag}\n")
    print(f"Env written to {args.env_output}", file=sys.stderr)

    # 6. Write changelog
    with open(args.changelog_output, "w") as f:
        f.write(changelog_md)
    print(f"Changelog written to {args.changelog_output}", file=sys.stderr)


if __name__ == "__main__":
    main()
