#!/bin/bash
#
# The table test for version.sh. The rules are a table, so the test is one.
#
# It asserts the external behaviour of the seam only — labels and a current
# version go in, a version string or nothing comes out. It never reaches inside
# the script, and it never asserts on log lines or intermediate variables.
#
# bash 3.2, because that is what the macos-26 runner ships: no associative
# arrays, no mapfile. It needs no toolchain and runs in about a second, which is
# why it can sit in CI on every pull request rather than being discovered by a
# Release.
#
# Run it by hand with: bash scripts/version-test.sh

set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/version.sh"

# Checked up front, because a missing script would otherwise look like a pass:
# "no Release is due" and "rejected loudly" are both satisfied by a command
# that does not exist.
if [ ! -x "$script" ]; then
  echo "no executable script at $script" >&2
  exit 1
fi

checked=0
failures=0

fail() {
  failures=$((failures + 1))
  echo "FAIL  $1"
  echo "      expected: $2"
  echo "      actual:   $3"
}

# next: the label-to-bump half. An empty expectation means no Release is due —
# the script must print nothing and still succeed, because "no Release" is a
# normal answer and not an error.
expect_next() {
  expected="$1"
  current="$2"
  shift 2
  checked=$((checked + 1))
  actual=$("$script" next "$current" "$@" 2>/dev/null)
  status=$?
  if [ "$status" -ne 0 ]; then
    fail "next $current [$*]" "exit 0 and '$expected'" "exit $status"
  elif [ "$actual" != "$expected" ]; then
    fail "next $current [$*]" "'$expected'" "'$actual'"
  fi
}

# from-tag: the tag-to-version half, on the happy path.
expect_version() {
  expected="$1"
  ref="$2"
  checked=$((checked + 1))
  actual=$("$script" from-tag "$ref" 2>/dev/null)
  status=$?
  if [ "$status" -ne 0 ]; then
    fail "from-tag $ref" "exit 0 and '$expected'" "exit $status"
  elif [ "$actual" != "$expected" ]; then
    fail "from-tag $ref" "'$expected'" "'$actual'"
  fi
}

# Rejection is three things at once, and all three matter: a non-zero exit so
# the workflow stops, a message on stderr so a person knows why, and nothing on
# stdout so a malformed ref can never be silently reduced to a version.
expect_rejected() {
  label="$1"
  shift
  checked=$((checked + 1))
  stderr_file=$(mktemp)
  actual=$("$script" "$@" 2>"$stderr_file")
  status=$?
  message=$(cat "$stderr_file")
  rm -f "$stderr_file"
  if [ "$status" -eq 0 ]; then
    fail "$label" "a non-zero exit" "exit 0 and '$actual'"
  elif [ -n "$actual" ]; then
    fail "$label" "nothing on stdout" "'$actual'"
  elif [ -z "$message" ]; then
    fail "$label" "a message on stderr" "silence"
  fi
}

# --- each bumping label on its own ------------------------------------------

expect_next "1.3.0" "1.2.3" feat
expect_next "1.2.4" "1.2.3" fix
expect_next "1.2.4" "1.2.3" refactor

# A MINOR bump resets PATCH: 1.2.3 plus a feature is 1.3.0, never 1.3.3.
expect_next "0.2.0" "0.1.7" feat

# --- each non-bumping label on its own, and no label at all -----------------

expect_next "" "1.2.3" docs
expect_next "" "1.2.3" spec
expect_next "" "1.2.3" chore
expect_next "" "1.2.3" test
expect_next "" "1.2.3"
expect_next "" "1.2.3" ready-for-agent
expect_next "" "1.2.3" wontfix

# --- no-release suppresses whatever else is present -------------------------

expect_next "" "1.2.3" no-release
expect_next "" "1.2.3" feat no-release
expect_next "" "1.2.3" no-release feat
expect_next "" "1.2.3" feat fix refactor no-release

# --- several bumping labels: the largest wins -------------------------------

expect_next "1.3.0" "1.2.3" feat fix
expect_next "1.3.0" "1.2.3" fix feat
expect_next "1.3.0" "1.2.3" feat refactor
expect_next "1.2.4" "1.2.3" fix refactor
expect_next "1.2.4" "1.2.3" fix docs
expect_next "1.3.0" "1.2.3" docs feat chore

# --- MAJOR is unreachable ---------------------------------------------------
#
# There is no label to test for, so what is tested is the absence: every
# combination that bumps at all leaves MAJOR where it was.

expect_next "1.3.0" "1.2.3" feat feat
expect_next "1.3.0" "1.2.3" feat fix refactor docs spec chore test
expect_next "9.10.0" "9.9.9" feat
expect_next "0.3.0" "0.2.9" feat

# --- digits carry numerically, not by string comparison ---------------------
#
# String comparison is the obvious way to get this wrong, and it stays wrong
# quietly: 9 + 1 as strings sorts after 10.

expect_next "1.10.0" "1.9.0" feat
expect_next "1.0.10" "1.0.9" fix
expect_next "1.100.0" "1.99.3" feat
expect_next "1.2.100" "1.2.99" refactor
expect_next "10.11.0" "10.10.10" feat

# --- a current version that is not X.Y.Z is rejected ------------------------

expect_rejected "next with a v-prefixed current version" next v1.2.3 feat
expect_rejected "next with a two-part current version" next 1.2 feat
expect_rejected "next with a non-numeric current version" next foo feat
expect_rejected "next with an empty current version" next "" feat

# --- from-tag: well-formed refs --------------------------------------------

expect_version "1.2.3" "v1.2.3"
expect_version "0.1.0" "v0.1.0"
expect_version "0.0.0" "v0.0.0"
expect_version "10.20.30" "v10.20.30"

# The tagger and the release workflow read GITHUB_REF_NAME, which is the short
# name, but a full ref is what git itself hands out — accepting both means the
# caller never has to remember which it is holding.
expect_version "1.2.3" "refs/tags/v1.2.3"

# --- from-tag: every malformed shape is rejected ----------------------------

expect_rejected "from-tag with no version at all" from-tag vfoo
expect_rejected "from-tag with two components" from-tag v1.0
expect_rejected "from-tag with four components" from-tag v1.0.0.0
expect_rejected "from-tag with a prerelease suffix" from-tag v1.0.0-rc1
expect_rejected "from-tag with build metadata" from-tag v1.0.0+build
expect_rejected "from-tag without the leading v" from-tag 1.0.0
expect_rejected "from-tag with an empty ref" from-tag ""
expect_rejected "from-tag with a branch ref" from-tag refs/heads/main

# A leading zero is rejected rather than normalised. Bash reads 08 as octal and
# fails on it, so a tag like v08.0.0 that parsed here would blow up later, in
# the middle of a Release, with an error about the wrong thing.
expect_rejected "from-tag with a leading zero in MAJOR" from-tag v08.0.0
expect_rejected "from-tag with a leading zero in MINOR" from-tag v1.09.0
expect_rejected "from-tag with a leading zero in PATCH" from-tag v1.0.09

# --- the script refuses to guess -------------------------------------------

expect_rejected "an unknown subcommand" bump 1.2.3
expect_rejected "no subcommand"
expect_rejected "next with no current version" next

echo
if [ "$failures" -eq 0 ]; then
  echo "$checked version rules, all as specified"
  exit 0
fi
echo "$failures of $checked version rules broken"
exit 1
