#!/bin/bash
#
# Every decision about what version comes next, in one place.
#
#   version.sh next <current-version> [label...]
#       Prints the next version, or prints nothing at all when no Release is
#       due. Printing nothing is a success, not a failure: most merges are not
#       Releases.
#
#   version.sh from-tag <ref>
#       Prints the Version a Tag carries — the Tag without its leading v — or
#       fails loudly when the ref is not vMAJOR.MINOR.PATCH.
#
# It is pure. It reads no git history, makes no network call and touches no
# GitHub API. Finding the latest Tag, reading a pull request payload, pushing a
# Tag and invoking the release workflow all stay in the workflows that call
# this. CLAUDE.md puts anything with a decision in it where a fast test can
# reach it; the language happens to be shell rather than Swift, but the reason
# is the same, and the test is scripts/version-test.sh.
#
# The bump table:
#
#   feat                              MINOR
#   fix, refactor                     PATCH
#   docs, spec, chore, test, none     no Release
#   no-release                        no Release, whatever else is present
#
# The largest bump wins when several are present. MAJOR has no label and cannot
# be produced here — it is reserved to a human, because a breaking change is not
# yet definable for a local-only app with one user. See
# docs/adr/0006-labels-decide-the-version.md.
#
# bash 3.2, because that is what the macos-26 runner ships.

set -uo pipefail

# Errors go to stderr, never to stdout: stdout is the answer channel, and a
# caller reading a version out of it must never receive an error message
# instead. The workflows re-raise these as ::error:: annotations.
die() {
  printf 'version.sh: %s\n' "$1" >&2
  exit 1
}

# A component is a number without a leading zero. Rejecting 08 rather than
# normalising it is deliberate: bash reads a leading zero as octal, so $((08))
# is an error, and a version that parsed here would fail later, mid-Release,
# complaining about something else entirely.
component='(0|[1-9][0-9]*)'

major=""
minor=""
patch=""

# Splits X.Y.Z into the three globals above, or dies naming what it was given.
parse_version() {
  if [[ ! $1 =~ ^$component\.$component\.$component$ ]]; then
    die "$2"
  fi
  major="${1%%.*}"
  patch="${1##*.}"
  minor="${1#*.}"
  minor="${minor%.*}"
}

cmd_next() {
  [ "$#" -ge 1 ] || die "next needs a current version: next <current-version> [label...]"

  current="$1"
  shift
  parse_version "$current" "current version ${current:-(empty)} is not MAJOR.MINOR.PATCH"

  # 0 no Release, 1 PATCH, 2 MINOR. Ranked rather than matched so that the
  # largest wins by arithmetic, without an order of precedence written out
  # per combination.
  bump=0

  for label in "$@"; do
    case "$label" in
      # One label is enough to hold a whole pull request back, so this returns
      # rather than lowering the rank — a later feat must not undo it.
      no-release) return 0 ;;
      feat) [ "$bump" -lt 2 ] && bump=2 ;;
      fix | refactor) [ "$bump" -lt 1 ] && bump=1 ;;
      # Everything else — docs, spec, chore, test, the triage labels, anything
      # added later — cuts no Release. Silence is the safe default: forgetting
      # a label under-claims rather than over-claims.
      *) ;;
    esac
  done

  # Arithmetic, never string comparison: 1.9.0 plus a feature is 1.10.0, and a
  # string-sorted answer would put that before 1.9.0 without ever erroring.
  case "$bump" in
    2) printf '%s.%s.0\n' "$major" "$((minor + 1))" ;;
    1) printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))" ;;
    *) : ;;
  esac
}

cmd_from_tag() {
  [ "$#" -ge 1 ] || die "from-tag needs a ref: from-tag <ref>"

  ref="$1"
  # git hands out refs/tags/v1.2.3; GITHUB_REF_NAME hands out v1.2.3. Taking
  # both means no caller has to remember which it is holding.
  tag="${ref#refs/tags/}"

  # CFBundleShortVersionString is up to three period-separated integers, so a
  # tag that does not reduce to one has no Version. Caught here rather than by
  # Finder showing a blank version after the dmg was published.
  if [[ ! $tag =~ ^v$component\.$component\.$component$ ]]; then
    die "tag ${ref:-(empty)} is not vMAJOR.MINOR.PATCH"
  fi

  printf '%s\n' "${tag#v}"
}

[ "$#" -ge 1 ] || die "usage: version.sh next <current-version> [label...] | version.sh from-tag <ref>"

subcommand="$1"
shift

case "$subcommand" in
  next) cmd_next "$@" ;;
  from-tag) cmd_from_tag "$@" ;;
  *) die "unknown subcommand ${subcommand}: expected next or from-tag" ;;
esac
