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
.pre-commit-hooks.yaml       hook manifest, so other repos can consume the checks REMOTELY at a pinned rev
examples/consumer.pre-commit-config.yaml  ready-made config for remote consumers (curl it, done)
.github/workflows/checks.yml hardened CI: re-runs the SAME config + SAST (shellcheck/Semgrep), deep secret scan, dependency-review
.github/workflows/security-scan.yml  weekly deep secret + SAST re-scan (osv-scanner/Trivy drop-ins for when you add deps)
.github/workflows/release.yml  on a v* tag: SBOM + keyless SLSA provenance, published as a GitHub Release
.github/workflows/pre-commit-autoupdate.yml  weekly PR bumping the pinned hook revs (Dependabot can't watch pre-commit)
.github/dependabot.yml       weekly grouped bumps for the SHA-pinned Actions
.gitignore                   secret globs (structurally un-committable) + OS cruft
.gitattributes               force LF so line endings don't corrupt across OSes
.editorconfig                editors satisfy the hygiene hooks before you commit
bootstrap.sh                 one-command setup: prek, or pre-commit, or a local .venv
scripts/checks/
  check-no-tracked-secrets.sh  fail if a secret-looking file is tracked (also an example invariant)
  check-one-pin-per-action.sh  every Action SHA-pinned, one pin per action repo-wide
  check-no-private-identifiers.sh  your hostname / private infra names can't enter the repo
  check-pin-comments-match.sh  CI-stage: a pin's `# vX.Y.Z` comment must still match its SHA
  check-commit-trailer.sh      require a provenance trailer, so each commit is a decision record
  check-evidence-trailer.sh    opt-in: live-surface commits must carry an Evidence: trailer
  check-diagrams-rendered.sh   post-docs-build: every mermaid fence produced a rendered node
```

## Three ways in

### 1. Consume remotely — recommended

pre-commit's native distribution: your repo references this one at a **pinned tag** and
vendors nothing, so there is no copy to drift. Grab the ready-made config and the
support files (these live in your repo — they can't be "consumed"):

Prerequisite: `pre-commit` on your PATH (`pipx install pre-commit` or
`brew install pre-commit`) — or grab `bootstrap.sh` from modes 2–3, which falls back
gracefully. Fetch from a **tag**, never `main`, so a re-run next month gets the same
files (resolve the newest tag directly with `git ls-remote`, below — it works whether or
not the tag was also published as a GitHub Release):

```bash
TAG=$(git ls-remote --tags --sort=-v:refname \
  https://github.com/pedro-angel/git-controls-starter 'v*' \
  | grep -v '\^{}' | head -1 | sed 's|.*refs/tags/||')
BASE=https://raw.githubusercontent.com/pedro-angel/git-controls-starter/$TAG
curl -fsSL "$BASE/examples/consumer.pre-commit-config.yaml" -o .pre-commit-config.yaml
for f in .gitignore .gitattributes .editorconfig .github/dependabot.yml \
         .github/workflows/checks.yml .github/workflows/security-scan.yml \
         .github/workflows/release.yml .github/workflows/pre-commit-autoupdate.yml; do
  mkdir -p "$(dirname "$f")"
  if [ -e "$f" ]; then   # never clobber a file you already have — fetch beside it, merge by hand
    curl -fsSL "$BASE/$f" -o "$f.upstream" && echo "wrote $f.upstream — merge into your $f"
  else
    curl -fsSL "$BASE/$f" -o "$f"
  fi
done
pre-commit install --install-hooks && pre-commit run --all-files
```

Append your own linters at the bottom of the config, add your package ecosystem to
`dependabot.yml`, done. **Staying current is automatic:** the autoupdate workflow bumps
the pinned `rev` in a weekly PR — every gate change arrives as a reviewable diff with
provenance, never as silent drift.

### 2. New repo from the template

Self-contained (everything vendored, works offline, easy to fork-and-diverge). On
GitHub: **Use this template → Create a new repository**, or:

```bash
gh repo create my-project --template pedro-angel/git-controls-starter --private --clone
cd my-project && ./bootstrap.sh
```

### 3. Copy into an existing repo (vendored)

```bash
cp -R /path/to/git-controls-starter/. .        # into your repo root
git checkout -- README.md LICENSE 2>/dev/null  # restore YOUR versions (the cp clobbered them)
./bootstrap.sh
```

If your repo hadn't committed a `README.md`/`LICENSE` yet, delete the starter's copies
instead of adopting them by accident.

`bootstrap.sh` (modes 2–3) uses whatever's available, in order: **prek** (a single static
binary, zero Python — `brew install prek`); an existing **pre-commit** on PATH; else a
project-local gitignored **`.venv`**. It installs both hook stages and runs the file
checks once. Re-run everything exactly as CI does with `pre-commit run --all-files`.

## Staying current & switching modes

| You are on | Updates arrive by |
| --- | --- |
| Remote (mode 1) | `rev` bumps arrive as the weekly autoupdate PR. New **hook ids** don't — adopt them by hand (below). |
| Template / copy-in (modes 2–3) | Manually adopt from upstream (below), or migrate to remote (also below). |

**Autoupdate bumps `rev`, never your hook list.** When a tag ships a new hook, add its
`id` to your config yourself — the tag's commit log announces it. And if the hook is
`stages: [manual]` (the network-dependent ones are), a rev bump alone will never execute
it: also add an explicit CI step after your default-stage run, e.g.
`pre-commit run check-pin-comments-match --hook-stage manual --all-files`.

### Vendored repo: adopt template updates

A repo created from the template shares **no git history** with it, so you can't merge —
but you can fetch it as a remote and adopt selectively. Two kinds of files:
**wholesale-safe** (upstream-owned; you rarely edit them) and **hand-merge** (you've
customized them — never blind-overwrite):

One warning first: the wholesale checkout overwrites same-named files. Invariants you
wrote yourself are safe **if** they have their own names (`check-my-thing.sh`); if you
edited an upstream script in place, treat it as hand-merge instead.

```bash
git remote add controls https://github.com/pedro-angel/git-controls-starter 2>/dev/null || true
git fetch controls --tags
TAG=$(git tag --sort=-v:refname -l 'v*' | head -1)   # newest upstream tag — use it for BOTH steps

# wholesale-safe: scripts + CI + automation + support files
git checkout "$TAG" -- scripts/checks bootstrap.sh .pre-commit-hooks.yaml examples \
  .github/workflows/checks.yml .github/workflows/security-scan.yml \
  .github/workflows/release.yml .github/workflows/pre-commit-autoupdate.yml \
  .github/dependabot.yml .gitattributes .editorconfig

# hand-merge: review what upstream changed in the files you own, and port by hand
git diff HEAD "$TAG" -- .pre-commit-config.yaml .gitignore

pre-commit run --all-files                # prove the adopted gate is green
git add -A && git commit                  # one reviewable adoption commit
```

### Migrate vendored → remote

The durable fix for update pain. In `.pre-commit-config.yaml`, replace the
`repo: local` invariant entries with the remote block (see
[examples/consumer.pre-commit-config.yaml](examples/consumer.pre-commit-config.yaml)),
then `git rm scripts/checks/<the vendored copies>` — **keep any invariants you wrote
yourself** under `repo: local`. Everything else (CI, autoupdate, dependabot, hygiene
files) stays as-is; the autoupdate workflow now also bumps the starter `rev`. Finish
with `pre-commit run --all-files` — the hooks must fetch from the tag and come up green.

### Migrate remote → vendored

For air-gapped repos, or to fork the checks' behavior: copy the scripts from the tag
you were pinned to and swap the remote block back to `repo: local` entries:

```bash
git remote add controls https://github.com/pedro-angel/git-controls-starter 2>/dev/null || true
git fetch controls --tags && git checkout v1.0.0 -- scripts/checks
# swap the remote block back to `repo: local` entries, then prove it:
pre-commit run --all-files
```

Installing the [agent-methodology](https://github.com/pedro-angel/agent-methodology)
pack too? The two don't overlap — this repo owns the git controls
(`.pre-commit-config.yaml`, `scripts/checks/`, CI), the pack owns the prose
(`AGENTS.md`, `skills/`, agent adapters). Any order works; see the pack's
[INSTALL.md](https://github.com/pedro-angel/agent-methodology/blob/main/INSTALL.md).

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
  reviewable PR instead of a pile that goes stale and conflicting, and with a **7-day cooldown**
  so a freshly published (possibly compromised) version isn't proposed on day one. A weekly
  [`pre-commit-autoupdate.yml`](.github/workflows/pre-commit-autoupdate.yml) does the same
  for the pinned hook revs — the one dependency surface Dependabot cannot watch. And
  `check-one-pin-per-action.sh` fails the build if an action is un-pinned or pinned to two
  different SHAs across workflows, so piecemeal bumps can't drift — while the CI-stage
  `check-pin-comments-match.sh` verifies each pin's `# vX.Y.Z` comment still dereferences
  to its SHA (an update bot once bumped a pin while the comment kept lying). Bot commits are skipped
  in the commit-msg gate so these automated PRs aren't blocked by the trailer rule.
- **Vulnerabilities fail the build, at three gates.** Every PR runs SAST (`shellcheck` on the
  shell scripts, `Semgrep` on the workflow YAML — Action script-injection, unpinned refs,
  over-broad permissions), a full-history `gitleaks` secret scan, and `dependency-review` (a PR
  that *adds* a vulnerable dependency — a GitHub Action counts — is blocked). A weekly
  [`security-scan.yml`](.github/workflows/security-scan.yml) re-runs the deep secret + SAST scan
  so a newly-published rule catches an old commit. And a `v*` tag
  ([`release.yml`](.github/workflows/release.yml)) generates an SBOM and a keyless SLSA
  build-provenance attestation, published as a GitHub Release — so a consumer can
  `gh attestation verify` the exact bytes they pin. The scanners that would scan *nothing* on
  this dependency-free repo (`osv-scanner`, `Trivy`, `CodeQL`) ship as commented drop-ins, not
  green-against-nothing theater — they activate the moment you add real dependencies or app code.
- **Identity stays out of the repo.** `check-no-private-identifiers.sh` blocks commits
  that would add your machine's own hostname (derived at runtime — zero config) (generic names like `mac` or `laptop` are skipped — they identify nothing) or any
  name from a per-user registry at `~/.config/git-controls/private-identifiers` (one
  identifier per line: other hosts, internal domains). The registry lives *outside* the
  repo because the list itself is the secret. A hostname is identity, not evidence —
  record a machine's properties or a role name instead. For the rare file where a name
  legitimately belongs, add `<identifier> <path-glob>` to a tracked
  `.private-identifiers-allow` — explicit and reviewable, so the guard fails toward
  asking rather than silently.
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
- **Security scanning is already wired in** — all at the manual/CI stage, never on a
  fresh-clone commit (see the three-gate summary above): `shellcheck` + `Semgrep` for SAST,
  `gitleaks` for deep secret scanning, `dependency-review` on PRs, and SBOM + provenance on
  release. Still-optional add-ons: `markdownlint-cli2` for docs, and `actionlint`/`zizmor` for
  dedicated GitHub-Actions workflow linting. `osv-scanner`, `Trivy`, and `CodeQL` ship as
  commented drop-ins — uncomment them once you have dependencies or compiled/interpreted app
  code for them to analyze (otherwise they scan nothing and pass, which this repo treats as a bug).

## One-time GitHub setup when you publish

This starter ships an MIT `LICENSE` — **update the copyright holder to your own**, or swap in
a different license (no license = all-rights-reserved). Also add a `SECURITY.md` + private
vulnerability reporting and a `CONTRIBUTING.md` documenting the commit gate.

Some controls live in **repo settings, not files** — no YAML can turn them on. Enable them once,
in order (each unlocks the next), under *Settings → Code security*:

1. **Dependency graph** — `dependency-review` fails closed without it. Usually on for public repos but **verify/enable** it here (private repos also need GitHub Advanced Security). Everything below needs it.
2. **Dependabot alerts** — notifies you when a dependency has a known advisory.
3. **Dependabot security updates** — auto-opens a PR to patch an alerting dependency. This is *distinct* from
   [`dependabot.yml`](.github/dependabot.yml): security updates are alert-driven (patch a CVE now), whereas the
   committed `dependabot.yml` drives *scheduled* version bumps. Run either, both, or neither.
4. **Code scanning** — turns on the *Security → Code scanning* tab that receives SARIF (free on public repos;
   requires GitHub Advanced Security on private ones). The commented `osv-scanner`/`Trivy` drop-ins in
   [`security-scan.yml`](.github/workflows/security-scan.yml) upload there once you enable it and grant the job
   `security-events: write`.
5. *(optional)* **Secret scanning + push protection** — a server-side complement to the `gitleaks` gate.

Then **tag releases with semver** so consumers can pin a version. A `v*` tag runs
[`release.yml`](.github/workflows/release.yml), which publishes a **GitHub Release** (so a repo using this
workflow *does* get `gh release list` entries) carrying the SBOM, and records a keyless SLSA provenance
attestation. Consumers verify a downloaded asset with `gh attestation verify <file> --repo <owner>/<repo>`.
