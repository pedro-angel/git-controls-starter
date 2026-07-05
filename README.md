# git-controls-starter

Project-agnostic git & GitHub discipline you can drop into **any** repo, in any language.
It makes a *machine* enforce hygiene, secret-safety, commit discipline, and a hardened CI —
so a broken invariant fails like a red build instead of slipping past a tired reviewer.

Everything here is generic: no assumptions about your stack. Distilled from the controls
in the [agent-methodology](https://github.com/pedro-angel/agent-methodology) pack, with the
pack-specific validators stripped out.

## What's inside

```text
.pre-commit-config.yaml      hygiene + conventional-commit + project invariants (one config, re-run in CI)
.github/workflows/checks.yml hardened CI that re-runs the SAME config (least-priv, SHA-pinned, timeout, concurrency)
.github/dependabot.yml       weekly bumps for the SHA-pinned Actions
.gitignore                   secret globs (structurally un-committable) + OS cruft
.gitattributes               force LF so line endings don't corrupt across OSes
.editorconfig                editors satisfy the hygiene hooks before you commit
bootstrap.sh                 one-command setup: prek, or pre-commit, or a local .venv
scripts/checks/
  check-no-tracked-secrets.sh  fail if a secret-looking file is tracked (also an example invariant)
  check-commit-trailer.sh      require a provenance trailer, so each commit is a decision record
```

## Install

```bash
# 1. from your new repo root
cp -R /path/to/git-controls-starter/. .
git init

# 2. one command sets up the hooks — no global install required
./bootstrap.sh
```

`bootstrap.sh` uses whatever's available, in this order, so it works on almost any machine:

1. **prek** — a single static binary, **zero Python** (`brew install prek`), else
2. an existing **pre-commit** on your PATH (`pipx install pre-commit` / `brew install pre-commit`), else
3. a project-local **`.venv`** with a pinned pre-commit — needs only `python3` (the venv is gitignored).

It installs both hook stages (pre-commit + commit-msg) and runs everything once. To re-run all
checks later, exactly as CI does:

```bash
pre-commit run --all-files      # or, with prek:  prek run --all-files
```

## What each control buys you

- **Local == CI.** [checks.yml](.github/workflows/checks.yml) re-runs the same
  `.pre-commit-config.yaml`, so "passes on my machine" and "passes in CI" can't diverge.
- **Secrets can't leak.** `.gitignore` makes secret files physically un-committable,
  `detect-private-key` blocks key material, and `check-no-tracked-secrets.sh` catches one
  that slipped in *before* it was ignored.
- **Scannable, accountable history.** A conventional-commit prefix (`feat/fix/…`) plus a
  required provenance trailer make each commit a decision record. `git commit -s` satisfies
  the trailer *and* the [DCO](https://developercertificate.org/) in one step.
- **Hardened CI.** Least-privilege `permissions: contents: read`, Actions pinned to full
  commit SHAs (a moved tag can't change what runs), `timeout-minutes`, `concurrency` cancel,
  and Dependabot to keep the pins fresh — with bot commits skipped in the commit-msg gate so
  Dependabot PRs aren't blocked by the trailer rule.
- **Cross-OS safe.** `.gitattributes` + `.editorconfig` keep line endings LF everywhere.

## Make it yours

- **Add your own invariants.** The real value is checks no linter can write:
  `check-no-tracked-secrets.sh` is a worked template — copy it and assert a contract
  specific to your repo ("every `src/` route has a test", "the config example matches the
  schema", "no `console.log` in `src/`"). Register it under `repo: local` in the config.
  Keep them **fail-closed**: exit non-zero when the target is missing, so a green check
  never means "ran against nothing."
- **Team workflow?** Uncomment `no-commit-to-branch` in the config, and on GitHub enable
  branch protection on `main` with `checks` as a **required status check**.
- **Optional additions** (keep heavy scanners in CI, not on a fresh clone):
  `markdownlint-cli2` for docs, `gitleaks` for deep secret scanning, `shellcheck` for shell.

## One-time GitHub setup when you publish

Add a `LICENSE` **before** going public (no license = all-rights-reserved), a `SECURITY.md`
+ private vulnerability reporting, a `CONTRIBUTING.md` documenting the commit gate, and tag
releases with semver so consumers can pin a version.
