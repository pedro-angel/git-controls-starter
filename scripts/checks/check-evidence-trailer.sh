#!/bin/sh
# commit-msg hook (OPT-IN template): when a commit touches "live-surface" paths —
# code whose correctness rests on a run against real infrastructure (an integration
# client, deploy config, anything CI cannot prove) — require an `Evidence:` trailer
# pointing at the captured run artifact (a results file, a log, a CI-run URL).
#
# Why: this is the machine check behind the README's Evidence-trailer convention.
# The failure it prevents is real: a commit claiming "complete API coverage" once
# shipped 9 integration tests that had never run green against a live server,
# because nothing required proof to travel with the claim.
#
# Opt in: set the regex below to your live-surface paths, then uncomment the hook
# in .pre-commit-config.yaml. Fail-closed: enabling the hook without configuring
# the regex is an error, so a green run never means "checked nothing".
# $1 = path to the commit message file (pre-commit passes it for commit-msg hooks).
set -u
msg="${1:?usage: check-evidence-trailer.sh <commit-msg-file>}"

# EDIT ME on opt-in — paths whose changes demand live evidence, e.g.:
#   EVIDENCE_PATH_REGEX='^(src/integrations/|deploy/|tests/integration/)'
EVIDENCE_PATH_REGEX="${EVIDENCE_PATH_REGEX:-}"

if [ -z "$EVIDENCE_PATH_REGEX" ]; then
  echo "FAIL: check-evidence-trailer is enabled but EVIDENCE_PATH_REGEX is not set."
  echo "  Configure the live-surface path regex in scripts/checks/check-evidence-trailer.sh"
  echo "  (or export EVIDENCE_PATH_REGEX). Fail-closed by design."
  exit 1
fi

touched=$(git diff --cached --name-only | grep -E "$EVIDENCE_PATH_REGEX" || true)
[ -n "$touched" ] || exit 0 # commit doesn't touch live-surface paths

if git interpret-trailers --parse <"$msg" | grep -qiE '^Evidence:'; then
  exit 0
fi

echo "FAIL: this commit touches live-surface paths but carries no Evidence: trailer:"
printf '%s\n' "$touched" | head -5 | sed 's/^/  /'
echo "Add a trailer pointing at the captured live run, e.g.:"
echo "  Evidence: docs/evidence/integration-run-2026-07-08.md"
echo "  Evidence: https://github.com/<org>/<repo>/actions/runs/<id>"
exit 1
