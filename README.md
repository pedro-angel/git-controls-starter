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
.github/workflows/pre-commit-autoupdate.yml  weekly PR bumping the pinned hook revs (Dependabot can't watch pre-commit)
.github/dependabot.yml       weekly grouped bumps for the SHA-pinned Actions
.gitignore                   secret globs (structurally un-committable) + OS cruft
.gitattributes               force LF so line endings don't corrupt across OSes
.editorconfig                editors satisfy the hygiene hooks before you commit
bootstrap.sh                 one-command setup: prek, or pre-commit, or a local .venv
scripts/checks/
  check-no-tracked-secrets.sh  fail if a secret-looking file is tracked (also an example invariant)
  check-one-pin-per-action.sh  every Action SHA-pinned, one pin per action repo-wide
  check-commit-trailer.sh      require a provenance trailer, so each commit is a decision record
  check-evidence-trailer.sh    opt-in: live-surface commits must carry an Evidence: trailer
```

## Install

This repo is a **GitHub template**, so there are two ways in.

**Starting a new project?** Use the template — it gives you a fresh repo with these
files already committed. On GitHub, click **Use this template → Create a new repository**,
or from the CLI:

```bash
gh repo create my-project --template pedro-angel/git-controls-starter --private --clone
cd my-project
./bootstrap.sh    # one command sets up the hooks — no global install required
```

**Adding to a repo you already have?** The template button only makes *new* repos, so
copy the files in instead:

```bash
cp -R /path/to/git-controls-starter/. .   # into your existing repo root
# (add `git init` first if it isn't a git repo yet)
# heads-up: this also copies README.md and LICENSE — keep your own, don't clobber them
./bootstrap.sh
```

`bootstrap.sh` uses whatever's available, in this order, so it works on almost any machine:

1. **prek** — a single static binary, **zero Python** (`brew install prek`), else
2. an existing **pre-commit** on your PATH (`pipx install pre-commit` / `brew install pre-commit`), else
3. a project-local **`.venv`** with a pinned pre-commit — needs only `python3` (the venv is gitignored).

It installs both hook stages (pre-commit + commit-msg) and runs the file-hygiene checks once;
the commit-msg hooks (conventional prefix + provenance trailer) fire on your next commit. To
re-run all file checks later, exactly as CI does:

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
  the trailer *and* the [DCO](https://developercertificate.org/) in one step. When a commit's
  correctness rests on a run — a live integration suite, a deploy, a benchmark — add an
  `Evidence:` trailer pointing at the captured artifact (a results file, a log, a CI-run URL),
  so the proof travels with the commit instead of living in a reviewer's memory. That turns
  "trust me, it's tested" into a link the next reader can open.
- **Hardened CI.** Least-privilege `permissions: contents: read`, Actions pinned to full
  commit SHAs (a moved tag can't change what runs), `timeout-minutes`, `concurrency` cancel,
  and Dependabot to keep the pins fresh — **grouped**, so the weekly sweep lands as one
  reviewable PR instead of a pile that goes stale and conflicting. A weekly
  [`pre-commit-autoupdate.yml`](.github/workflows/pre-commit-autoupdate.yml) does the same
  for the pinned hook revs — the one dependency surface Dependabot cannot watch. And
  `check-one-pin-per-action.sh` fails the build if an action is un-pinned or pinned to two
  different SHAs across workflows, so piecemeal bumps can't drift. Bot commits are skipped
  in the commit-msg gate so these automated PRs aren't blocked by the trailer rule.
- **Cross-OS safe.** `.gitattributes` + `.editorconfig` keep line endings LF everywhere.

## Make it yours

- **Add your own invariants.** The real value is checks no linter can write:
  `check-no-tracked-secrets.sh` is a worked template — copy it and assert a contract
  specific to your repo ("every `src/` route has a test", "the config example matches the
  schema", "no `console.log` in `src/`"). Register it under `repo: local` in the config.
  Keep them **fail-closed**: exit non-zero when the target is missing, so a green check
  never means "ran against nothing."
- **Make claims carry proof.** Enable the opt-in `check-evidence-trailer.sh`: pick the
  paths whose correctness rests on a live run (integration clients, deploy config), and
  commits touching them must carry an `Evidence:` trailer. The failure it prevents is
  real: a commit claiming "complete API coverage" once shipped nine integration tests
  that had never run green against a live server — nothing required proof to travel
  with the claim.
- **Preflight your entry points.** A setup script that assumes its prerequisites fails
  late and cryptically (a venv built on the wrong interpreter dies minutes later, deep
  in dependency resolution). Make `make setup` / `bootstrap.sh`-style entry points
  validate prerequisites **against the authoritative source** (e.g. read the version
  floor from `pyproject.toml` / `package.json`, don't restate it) and fail in the first
  second with the remedy: `needs Python >=3.14, found 3.13 — run: make setup PYTHON=python3.14`.
- **Team workflow?** Uncomment `no-commit-to-branch` in the config, and on GitHub enable
  branch protection on `main` with `checks` as a **required status check**.
- **Optional additions** (keep heavy scanners in CI, not on a fresh clone):
  `markdownlint-cli2` for docs, `gitleaks` for deep secret scanning, `shellcheck` for shell.

## One-time GitHub setup when you publish

This starter ships an MIT `LICENSE` — **update the copyright holder to your own**, or swap in
a different license (no license = all-rights-reserved). Also add a `SECURITY.md` + private
vulnerability reporting, a `CONTRIBUTING.md` documenting the commit gate, and tag releases with
semver so consumers can pin a version.
