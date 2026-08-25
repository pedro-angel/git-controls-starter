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
#
# Exit codes: 0 = every verifiable comment checks out, 1 = a comment is wrong,
# 2 = a lookup could not be performed, so this run is not authoritative.
# The 0/1/2 split is load-bearing. `git ls-remote` returns exit 0 with EMPTY output for a
# ref that genuinely does not exist, and a non-zero exit for a lookup it could not perform
# (DNS failure, refused connection, proxy 403, anonymous-git throttling). Empty output
# alone cannot tell those apart, so this check reads the EXIT STATUS: only exit 0 plus
# empty output licenses the "no such ref" verdict. A failed lookup reports that it could
# not check — never a verdict it did not earn, and never a silent pass either.
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

errf=$(mktemp) || { rm -f "$tmp"; exit 2; }

# One live ref lookup. Sets ls_rc (git's exit status), ls_out (stdout) and ls_err (stderr,
# flattened to one line). stderr is captured, never discarded: on a failed lookup it is the
# only evidence of WHY, and it goes into the report.
# Retried once after a short pause: anonymous git against github.com throttles bursts, and
# a repo with a dozen pins fires up to two lookups each back-to-back. The retry costs
# nothing on the healthy path — it fires only when a lookup has already failed.
# GIT_TERMINAL_PROMPT=0 so a repo that 404s (renamed, deleted, made private) fails fast as
# an unverifiable lookup instead of blocking on a credential prompt no CI runner can answer.
ls_remote() {
  _url=$1
  shift
  ls_out=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$_url" "$@" 2>"$errf"); ls_rc=$?
  if [ "$ls_rc" -ne 0 ]; then
    sleep 2
    ls_out=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$_url" "$@" 2>"$errf"); ls_rc=$?
  fi
  ls_err=$(tr -d '\r' <"$errf" | tr '\n' ' ')
}

# A lookup that could not be performed. Reports the repo and git's own error, and is
# deliberately worded so it can never be mistaken for a verdict on the pin.
report_unverifiable() {
  echo "could not verify: $1 comment '$2' — lookup of $3 failed after a retry: ${ls_err:-git exited $ls_rc with no message}"
  echo "  This is not a finding against the pin — the lookup did not complete. Re-run once github.com is reachable, and confirm $3 still exists under that name."
  unverified=$((unverified + 1))
}

status=0
unverified=0
while IFS=' ' read -r action sha ref; do
  repo=$(printf '%s' "$action" | cut -d/ -f1,2)
  url="https://github.com/$repo"

  ls_remote "$url" "refs/tags/$ref" "refs/tags/$ref^{}"
  if [ "$ls_rc" -ne 0 ]; then
    report_unverifiable "$action" "$ref" "$repo"
    continue
  fi

  if [ -n "$ls_out" ]; then
    peeled=$(printf '%s\n' "$ls_out" | grep '\^{}$' | awk '{print $1}')
    plain=$(printf '%s\n' "$ls_out" | grep -v '\^{}$' | awk '{print $1}' | head -1)
    want=${peeled:-$plain}
    if [ "$want" != "$sha" ]; then
      echo "FAIL: $action is pinned to $sha but its comment says '$ref', which is $want"
      echo "  Fix the comment (or the pin) so the human-readable version stops lying."
      status=1
    fi
    continue
  fi

  # exit 0 + empty output: the tag genuinely is not there. Only now is the branch fallback
  # meaningful — and it gets the identical exit-status treatment, for the identical reason.
  ls_remote "$url" "refs/heads/$ref"
  if [ "$ls_rc" -ne 0 ]; then
    report_unverifiable "$action" "$ref" "$repo"
  elif [ -n "$ls_out" ]; then
    echo "note: $action comment '$ref' names a BRANCH — branches move, so the comment cannot be verified against the pin; consider a tag."
  else
    echo "FAIL: $action comment '$ref' matches no tag or branch on $repo — a stale or invented version label."
    status=1
  fi
done <"$tmp"
rm -f "$tmp" "$errf"

# Precedence when both occur: a confirmed wrong comment (1) outranks an unreachable lookup
# (2). Exit 1 is never a false claim here — a check really did fail — and downgrading a
# real defect to "infrastructure flake, retry it" is the mirror of the bug this guards.
# The "could not verify" lines are still printed, so the incomplete coverage stays visible.
if [ "$status" -ne 0 ]; then
  [ "$unverified" -gt 0 ] && echo "warning: $unverified further comment(s) could not be checked — coverage above is incomplete."
  exit 1
fi
if [ "$unverified" -gt 0 ]; then
  echo "could not complete: $unverified comment(s) could not be checked. No comment was found wrong; none was cleared either."
  exit 2
fi
echo "ok: every verifiable pin comment dereferences to its SHA"
exit 0
