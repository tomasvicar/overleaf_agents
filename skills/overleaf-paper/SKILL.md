---
name: overleaf-paper
description: Compile a LaTeX manuscript in the pinned TeX Live container and sync it with Overleaf and GitHub. Use when asked to build the paper, produce the PDF, check that the paper compiles, pull from Overleaf, or push changes to Overleaf.
---

# Overleaf paper: compile and sync

Install: copy this directory to `~/.claude/skills/overleaf-paper/`.

## Compile

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

Rootless podman instead: drop `-u`, and on SELinux systems mount as
`-v "$PWD:/work:Z"`.

Writes `main.pdf` in the repo root, aux files to `build/`. Options, as
`-e KEY=value` before the image name: `ENGINE=xelatex|lualatex`,
`SHELL_ESCAPE=1`, `OUTDIR=...`. A different main file is passed as an argument
after the image name.

The image is pinned to the TeX Live release the Overleaf project uses, so a
clean local compile is good evidence the project compiles on Overleaf.

## Read a failure

The container prints the error lines and exits non-zero; the full log is
`build/main.log`. Address the **first** error only, then rebuild — later errors
are usually consequences of it.

A missing `.sty` means the image lacks that package, not that the manuscript is
wrong. Never work around it by rewriting the LaTeX. Unblock locally by
extending the image:

```bash
docker build -t latex-overleaf:local - <<'EOF'
FROM ghcr.io/tomasvicar/latex-overleaf:latest
RUN tlmgr install PACKAGE && kpsewhich PACKAGE.sty
EOF
```

then compile with `latex-overleaf:local`, and tell the user the package should
be added to `packages.txt` in the `overleaf_agents` repo so the fix is
permanent. Keep the `kpsewhich`: `tlmgr install` exits 0 even when the download
failed, so it is the only thing that turns a silent failure into a failed build.

## Sync

The `overleaf` remote is always there; a GitHub `origin` is optional. Check with
`git remote` and push to `origin` only if it exists — Overleaf-only is a valid
setup, so never add a GitHub remote unprompted.

```bash
git pull overleaf main --no-rebase
git add -A && git commit -m "MESSAGE"
git push overleaf main
git remote | grep -q '^origin$' && git push origin main
```

- Compile successfully **before** pushing to Overleaf.
- Never force-push: Overleaf rejects it, and it would discard browser edits.
- A rejected push means someone edited in the Overleaf UI — pull with
  `--no-rebase`, resolve in the `.tex` source, push again. Never rebase over
  Overleaf commits.
- If the repo has no `overleaf` remote, add it with the project ID from the
  Overleaf URL and the user's git token:
  `git remote add overleaf https://git:TOKEN@git.overleaf.com/PROJECT_ID`

## Show what changed

Overleaf's comments and track changes are not in git and cannot be read or
answered from here. Leave questions as `\todo{...}` (`todonotes`), which renders
in the PDF where a browser-only co-author sees it, and mark rewrites with
`changes` (`\added`, `\deleted`, `\replaced`).

For a marked-up PDF between two revisions, which is what replaces track changes:

```bash
git show <rev>:main.tex > old.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest latexdiff old.tex main.tex > diff.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest diff.tex
```

Remove `old.tex`, `diff.tex` and `diff.pdf` when done; never commit them.
`texcount -1 -sum main.tex`, run the same way, answers word-limit questions.
