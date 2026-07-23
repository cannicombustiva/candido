#!/usr/bin/env bash
# Create a worktree for one issue, so two agent sessions never share a checkout.
#
# Usage: scripts/worktree.sh <issue-number> <slug>
#   scripts/worktree.sh 14 day-boundary
#     branch   m2/14-day-boundary   (off origin/main)
#     worktree ../candido-worktrees/14-day-boundary
#
# Worktrees live in one parent directory on purpose: a sibling named
# candido-<something> reads like the milestone runs (candido-m0 is the frozen
# M0 control), and those must not be confused with day-to-day branches.

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "usage: scripts/worktree.sh <issue-number> <slug>" >&2
    echo "example: scripts/worktree.sh 14 day-boundary" >&2
    exit 64
fi

issue=$1
slug=$2
branch="m2/${issue}-${slug}"
repo_root=$(git rev-parse --show-toplevel)
# --show-toplevel already resolves to the primary checkout's root when run from
# inside a worktree, so spawning a worktree from a worktree still lands here.
common_dir=$(git rev-parse --git-common-dir)
primary=$(cd "$(dirname "$common_dir")" && pwd)
path="$(dirname "$primary")/candido-worktrees/${issue}-${slug}"

if [ -e "$path" ]; then
    echo "worktree already exists: $path" >&2
    echo "reuse it, or remove it with: git worktree remove $path" >&2
    exit 1
fi

git -C "$repo_root" fetch --quiet origin main

if git -C "$repo_root" show-ref --quiet "refs/heads/${branch}"; then
    echo "branch ${branch} exists; checking it out into the new worktree"
    git -C "$repo_root" worktree add "$path" "$branch"
else
    git -C "$repo_root" worktree add -b "$branch" "$path" origin/main
fi

cat <<EOF

Worktree ready.

  cd $path

It starts from origin/main, with its own .build/ and DerivedData/ — nothing it
builds touches another session's tree. Commit and push from there, never from
the primary checkout at $primary.

Note: every build shares the one Debug bundle identifier
(com.candido.Candido.dev) and therefore one sandbox container. Two sessions
running the app at once are reading the same dev store — launch one at a time.

When the branch has merged:
  git worktree remove $path
EOF
