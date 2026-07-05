#!/bin/sh
# Fail if a secret-looking file is TRACKED by git. Defense-in-depth beyond .gitignore:
# gitignore does nothing for a file that was committed *before* it was ignored, so this
# catches the one that already slipped in. Fail closed. Portable POSIX sh; zero deps.
#
# Matches by name/extension, so it's deliberately conservative — a *public* cert like
# public.pem trips it too. That's the fail-closed tradeoff; narrow the glob below if your
# repo legitimately tracks public certs. Keep this list in sync with .gitignore.
#
# This is also a worked EXAMPLE of a project invariant: glob your files, assert a
# property, exit non-zero on violation. Copy it to encode contracts specific to your
# repo ("every route has a test", "no TODO without an issue ref", …).
set -u
hits=$(git ls-files \
  | grep -E '(^|/)(\.env(\..+)?|.+\.pem|.+\.key|.+\.p12|id_rsa|id_ed25519|credentials\.json|service-account.*\.json|.+\.tfvars(\..+)?|.+\.tfstate(\..+)?)$' \
  | grep -vE '\.example$' || true)
if [ -n "$hits" ]; then
  echo "FAIL: secret-looking file(s) tracked by git — untrack, rotate the secret, and gitignore it:"
  printf '  %s\n' $hits
  exit 1
fi
echo "ok: no secret-looking files tracked"
exit 0
