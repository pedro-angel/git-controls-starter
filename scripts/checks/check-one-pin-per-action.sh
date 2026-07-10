#!/bin/sh
# pre-commit hook: every GitHub Action must be pinned to a full 40-hex commit SHA,
# and each action must resolve to exactly ONE SHA across all workflows.
#
# Why both: a moved tag can't change what runs (SHA pin), and piecemeal bumping can't
# drift — in a real repo we found checkout@v4 and @v6, upload-artifact@v4 and @v7
# coexisting across workflows, which is how "which version runs?" stops having one
# answer and stale Dependabot PRs start conflicting.
#
# Ignores local actions (./path) and docker:// refs. Fail-closed: no workflow files
# found is a FAIL, so a green run never means "ran against nothing".
# Portable POSIX sh; zero runtime deps beyond grep/sed/awk/sort.
set -u

# A repo with no workflows has nothing to pin — that's a pass, not "ran against
# nothing" (this hook is consumed remotely by repos that may not use Actions at all).
dir=".github/workflows"
[ -d "$dir" ] || { echo "ok: no $dir — nothing to pin"; exit 0; }

files=$(find "$dir" -type f \( -name '*.yml' -o -name '*.yaml' \))
[ -n "$files" ] || { echo "ok: no workflow files under $dir — nothing to pin"; exit 0; }

# Extract `uses:` refs, skipping comment lines, quotes, trailing "# vX.Y.Z" comments,
# and non-pinnable forms (./local-action, docker://image).
refs=$(grep -hE '^[^#]*[[:space:]]uses:[[:space:]]' $files \
  | sed -E 's/.*uses:[[:space:]]*//; s/["'"'"']//g; s/[[:space:]]+#.*$//; s/[[:space:]]*$//' \
  | grep -vE '^(\.|docker://)' || true)

[ -n "$refs" ] || exit 0 # workflows exist but use no remote actions: nothing to pin

status=0

# (a) every remote action ref is a full 40-hex commit SHA
bad=$(printf '%s\n' "$refs" | grep -vE '@[0-9a-f]{40}$' || true)
if [ -n "$bad" ]; then
  echo "FAIL: actions not pinned to a full 40-hex commit SHA (tag/branch refs can move):"
  printf '%s\n' "$bad" | sed 's/^/  /'
  status=1
fi

# (b) one distinct pin per action across the whole repo
for action in $(printf '%s\n' "$refs" | awk -F@ '{print $1}' | sort -u); do
  pins=$(printf '%s\n' "$refs" | awk -F@ -v a="$action" '$1 == a' | sort -u)
  n=$(printf '%s\n' "$pins" | wc -l | tr -d ' ')
  if [ "$n" -gt 1 ]; then
    echo "FAIL: $action is pinned to $n different refs — pick one:"
    printf '%s\n' "$pins" | sed 's/^/  /'
    status=1
  fi
done

exit $status
