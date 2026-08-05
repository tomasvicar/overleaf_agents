# Adding a package the image does not have

The image ships `scheme-basic` plus the curated list in
[`packages.txt`](../packages.txt) — not all of TeX Live. Overleaf runs TeX Live
*full*, so there is one failure mode this design cannot rule out: a paper that
compiles on Overleaf but stops locally on

```
! LaTeX Error: File `foo.sty' not found.
```

That is not a problem with your manuscript. **Do not rewrite the LaTeX to avoid
the package** — add the package. This page is the whole procedure.

---

## Step 1: find out which package provides the file

TeX Live package names rarely match the `.sty` name, so look it up rather than
guess. The image can answer this itself:

```bash
docker run --rm ghcr.io/tomasvicar/latex-overleaf:latest \
  tlmgr search --global --file foo.sty
```

The output lists the containing package, e.g. `datetime2: texmf-dist/tex/latex/datetime2/datetime2.sty`
means the package name is `datetime2`. <https://ctan.org/pkg/foo> works too.

---

## Step 2, quick version: extend the image on your machine

One minute, no GitHub involved. Good for getting unstuck right now.

```bash
docker build -t latex-overleaf:local - <<'EOF'
FROM ghcr.io/tomasvicar/latex-overleaf:latest
RUN tlmgr install datetime2 && kpsewhich datetime2.sty
EOF
```

Then compile with your tag instead of the published one:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" latex-overleaf:local
```

**Keep the `&& kpsewhich`.** `tlmgr install` prints `install: datetime2 [9k]`
and exits 0 *even when the download failed* — without the check, a broken image
builds successfully and you find out later, mid-compile. `kpsewhich` fails the
build if the file is not actually there.

The limitation: the tag exists only on your machine. Co-authors and CI do not
have it. For anything longer-lived, do step 3.

---

## Step 3, durable version: fork and publish your own image

This gives you a real tag on your own registry that anyone can pull, built and
smoke-tested the same way the original is.

### 1. Fork and clone

```bash
gh repo fork tomasvicar/overleaf_agents --clone
cd overleaf_agents
```

### 2. Add the package

Put the name in [`packages.txt`](../packages.txt), in the section it belongs to.
Comments and blank lines are ignored, one package per line:

```diff
  # --- cross-referencing ---
  cleveref
  orcidlink
+ datetime2
```

### 3. Add it to the smoke test

This is the step people skip, and it is the one that keeps the package from
silently disappearing in a later rebuild. Add a line to
[`test/smoke.tex`](../test/smoke.tex) that actually uses it:

```latex
\usepackage{datetime2}
```

Now CI fails if the package ever stops being installed, instead of the failure
surfacing in someone's manuscript months later.

### 4. Push

```bash
git add packages.txt test/smoke.tex
git commit -m "Add datetime2"
git push
```

On your fork, GitHub Actions has to be enabled once — open the **Actions** tab
and confirm. The workflow then builds amd64, compiles `test/smoke.tex` with it,
and only if that passes builds and pushes `amd64` + `arm64` to
`ghcr.io/<your-user>/latex-overleaf`.

Expect **roughly 20 minutes**. Almost all of it is the arm64 build running under
QEMU emulation; the amd64 half finishes in under ten.

### 5. Make your package pullable

A package published from a public repo is public. If your fork is private, open
**Packages → latex-overleaf → Package settings → Change visibility**, or the
image will need a token to pull.

### 6. Use it

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/<your-user>/latex-overleaf:latest
```

Update the `docker run` line in your paper repo's `AGENTS.md` and `CLAUDE.md` to
match, so agents use your image too.

### 7. Consider sending it back

If the package is something most manuscripts might want, open a pull request
against `tomasvicar/overleaf_agents`. Then nobody else has to fork for it.

---

## Checking a package name before you push

The image build verifies every entry in `packages.txt` after installing, and
fails with the full list of names that do not exist in that TeX Live release —
so a typo costs you a CI round trip. To catch it in six minutes locally instead:

```bash
docker build --build-arg TL_YEAR=2025 -t latex-overleaf:mine .
```

A bad name produces:

```
ERROR: these packages.txt entries do not exist in TeX Live 2025:
  - datetime-2
```

---

## If you would rather never think about this again

There is a way to sidestep missing packages entirely, at the cost of a much
bigger image and no Apple Silicon support: see
[using-upstream-texlive.md](using-upstream-texlive.md).
