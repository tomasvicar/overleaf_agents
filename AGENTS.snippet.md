<!--
Copy the section below into your paper repository's AGENTS.md.
Replace <PROJECT_ID> and delete anything that does not apply.

Claude Code reads CLAUDE.md; Codex and Gemini CLI read AGENTS.md. Keep one file
and symlink the other:  ln -s AGENTS.md CLAUDE.md
-->

## Building the paper

Compile in the pinned container — do not install TeX Live and do not try to run
`pdflatex` directly on the host:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

- Produces `main.pdf` in the repo root; aux files go to `build/` (gitignored).
- The image is pinned to the same TeX Live release as the Overleaf project, so a
  successful local compile means it compiles on Overleaf too.
- On failure the container prints the relevant error lines; the full log is
  `build/main.log`. Read the **first** error — later ones are usually fallout.
- Never commit `main.pdf` fixes by hand. Fix the `.tex` and rebuild.

If the build fails on a missing `.sty`, the image lacks that package. Do not
work around it by rewriting the manuscript — report it, so it can be added to
`packages.txt` in the `overleaf_agents` repo. For an immediate local unblock,
extend the image:

```bash
docker build -t latex-overleaf:local - <<'EOF'
FROM ghcr.io/tomasvicar/latex-overleaf:latest
RUN tlmgr install PACKAGE && kpsewhich PACKAGE.sty
EOF
```

and compile with `latex-overleaf:local`. Keep the `kpsewhich`: `tlmgr install`
exits 0 even when the download failed, so it is the only thing that turns a
silent failure into a failed build.

## Syncing with Overleaf

The `overleaf` remote (`https://git.overleaf.com/<PROJECT_ID>`, branch `main`)
is always present. A GitHub remote named `origin` is optional — check with
`git remote` and push to it only if it exists.

```bash
git pull overleaf main --no-rebase   # before starting work, and after a rejected push
git add -A && git commit -m "..."
git push overleaf main
git remote | grep -q '^origin$' && git push origin main
```

Rules that matter:

- **Never force-push.** Overleaf rejects it outright, and it would destroy edits
  made in the browser.
- If `git push overleaf main` is rejected, someone edited the project in the
  Overleaf UI. Pull with `--no-rebase`, resolve conflicts in the `.tex` source,
  then push again. Do not rebase over Overleaf's commits.
- Always compile successfully before pushing to Overleaf. A broken build there
  is visible to every co-author immediately.
- If an `origin` remote exists, push there too, or the two drift apart. Do not
  add one on your own initiative — Overleaf-only is a valid setup.

## Conventions

- Never edit `*.cls` or `*.bst` files — they are the journal's, and the journal
  will use its own copies anyway.
- Bibliography entries go in the `.bib` file, never inline in the `.tex`.
- Figures are referenced by `\label`/`\ref`, never by hardcoded numbers.
