#!/usr/bin/env bash
# Regression test for a rebase of android-direct on top of upstream/main.
#
# Usage (from the fork clone):
#   bash scripts/test-rebase.sh
#
# What it does:
#   1. Fetches upstream/main.
#   2. Creates a throwaway branch `rebase-test` from the current HEAD.
#   3. Rebases `rebase-test` on top of upstream/main.
#   4. Runs scripts/build-termux.sh as the regression test.
#   5. On success: prints "REBASE OK" and exits 0.
#   6. On conflict: prints the conflicting files, drops the test branch,
#      and exits 1.
#   7. On build failure: keeps the test branch so you can debug, exits 1.
#
# This script does NOT push, commit to android-direct, or modify the
# fork's tracked branches. It's safe to run repeatedly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Ensure both remotes exist and are reachable.
if ! git remote get-url upstream >/dev/null 2>&1; then
	echo "ERROR: no 'upstream' remote. Add it with:" >&2
	echo "  git remote add upstream https://github.com/can1357/oh-my-pi.git" >&2
	exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
	echo "ERROR: no 'origin' remote. Add it with:" >&2
	echo "  git remote add origin <your fork URL>" >&2
	exit 1
fi

echo ">>> Fetching upstream and origin ..."
git fetch --quiet upstream
git fetch --quiet origin

# Record the current android-direct SHA for the report at the end.
SOURCE_SHA="$(git rev-parse HEAD)"
SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

TEST_BRANCH="rebase-test-$(date +%s)"

cleanup() {
	# Best-effort: switch back to the original branch and drop the test
	# branch. We tolerate failures here (e.g. detached HEAD in CI).
	git checkout -q "${SOURCE_BRANCH}" 2>/dev/null || true
	git branch -D "${TEST_BRANCH}" 2>/dev/null || true
}
trap cleanup EXIT

echo ">>> Creating throwaway branch ${TEST_BRANCH} at ${SOURCE_SHA:0:7} ..."
git checkout -q -b "${TEST_BRANCH}" "${SOURCE_SHA}"

echo ">>> Rebasing onto upstream/main ..."
if ! git rebase --quiet upstream/main; then
	echo
	echo "REBASE FAILED — conflicts in:"
	git diff --name-only --diff-filter=U 2>/dev/null || \
		git status --porcelain | /usr/bin/awk '/^UU / {print $2}'
	echo
	echo "Resolve manually:" >&2
	echo "  1. git checkout ${TEST_BRANCH}" >&2
	echo "  2. Edit the conflicting files (see docs/port-changes.md for guidance)" >&2
	echo "  3. git add <file> && git rebase --continue" >&2
	echo "  4. Re-run this script" >&2
	exit 1
fi

echo ">>> Running build regression test (scripts/build-termux.sh) ..."
echo "    This may take 30-60 minutes on a phone."
echo
if ! bash scripts/build-termux.sh 2>&1 | /usr/bin/tee /tmp/build-termux-rebase.log | /usr/bin/grep -E "^error|Compiling pi-natives|Built:"; then
	echo
	echo "BUILD FAILED during rebase test." >&2
	echo "Full log: /tmp/build-termux-rebase.log" >&2
	echo "Test branch (still checked out, NOT deleted) is ${TEST_BRANCH} at:" >&2
	git log --oneline -1 >&2
	echo
	echo "Debug: edit the source, re-run scripts/build-termux.sh." >&2
	exit 1
fi

echo
echo "REBASE OK — ${TEST_BRANCH} passed scripts/build-termux.sh."
echo "Source: ${SOURCE_BRANCH} @ ${SOURCE_SHA:0:7}"
echo "Rebased: $(git rev-parse --short HEAD) on upstream/main"
echo
echo "When ready to publish, fast-forward android-direct:"
echo "  git checkout android-direct"
echo "  git merge --ff-only ${TEST_BRANCH}"
echo "  git push origin android-direct"
