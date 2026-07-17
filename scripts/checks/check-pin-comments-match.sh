#!/bin/sh
# CI/manual-stage check (needs network — do NOT run at commit time): every SHA-pinned
# action's trailing `# <ref>` comment must still dereference to that SHA.
#
# The incident this catches: an update bot bumped a pin to the v8.1.1 tag commit while
# the trailing comment kept saying v7.0.0 — in a SHA-pinned repo the comment is the only
# human-readable version indicator, and a lying one defeats the point.
# check-one-pin-per-action cannot see this; only a live tag lookup can, which is why
# this runs as a CI step / `--hook-stage manual`, never as a commit-time hook.
#
# Tag comments are verified strictly (peeled SHA must equal the pin). A comment naming
# a BRANCH (e.g. `# release/v1`) is noted but not failed — branches move past any pin
# legitimately; consider pinning to a tag instead. A comment naming neither is a FAIL.
# Portable POSIX sh; zero runtime deps beyond git.
set -u

dir=".github/workflows"
[ -d "$dir" ] || { echo "ok: no $dir — nothing to verify"; exit 0; }
files=$(find "$dir" -type f \( -name '*.yml' -o -name '*.yaml' \))
[ -n "$files" ] || { echo "ok: no workflow files — nothing to verify"; exit 0; }

# lines like: uses: owner/repo[/path]@<40-hex>  # <ref>   -> "action sha ref"
tmp=$(mktemp) || exit 2
# shellcheck disable=SC2086  # intentional: $files is a newline-separated list to expand into args
grep -hE '^[^#]*[[:space:]]uses:[[:space:]]' $files \
  | sed -E 's/.*uses:[[:space:]]*//; s/["'"'"']//g' \
  | grep -E '@[0-9a-f]{40}[[:space:]]+#' \
  | sed -E 's/^([^@]+)@([0-9a-f]{40})[[:space:]]+#[[:space:]]*([^[:space:]]+).*$/\1 \2 \3/' \
  | sort -u >"$tmp"

if [ ! -s "$tmp" ]; then
  rm -f "$tmp"
  echo "ok: no SHA-pinned uses with version comments"
  exit 0
fi

status=0
while IFS=' ' read -r action sha ref; do
  repo=$(printf '%s' "$action" | cut -d/ -f1,2)
  out=$(git ls-remote "https://github.com/$repo" "refs/tags/$ref" "refs/tags/$ref^{}" 2>/dev/null)
  if [ -n "$out" ]; then
    peeled=$(printf '%s\n' "$out" | grep '\^{}$' | awk '{print $1}')
    plain=$(printf '%s\n' "$out" | grep -v '\^{}$' | awk '{print $1}' | head -1)
    want=${peeled:-$plain}
    if [ "$want" != "$sha" ]; then
      echo "FAIL: $action is pinned to $sha but its comment says '$ref', which is $want"
      echo "  Fix the comment (or the pin) so the human-readable version stops lying."
      status=1
    fi
  elif [ -n "$(git ls-remote "https://github.com/$repo" "refs/heads/$ref" 2>/dev/null)" ]; then
    echo "note: $action comment '$ref' names a BRANCH — branches move, so the comment cannot be verified against the pin; consider a tag."
  else
    echo "FAIL: $action comment '$ref' matches no tag or branch on $repo — a stale or invented version label."
    status=1
  fi
done <"$tmp"
rm -f "$tmp"

[ "$status" -eq 0 ] && echo "ok: every verifiable pin comment dereferences to its SHA"
exit $status
