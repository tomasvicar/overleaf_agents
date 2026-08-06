<!--
Copy the section below into your paper repository under BOTH names, so it works
whichever agent someone reaches for:

    cp AGENTS.snippet.md /path/to/paper/AGENTS.md   # Codex, Gemini CLI, others
    ln -s AGENTS.md /path/to/paper/CLAUDE.md        # Claude Code

The symlink keeps the two from drifting apart -- but only where symlinks
survive. If anyone on the paper works on Windows, commit two real files: Git
for Windows defaults to core.symlinks=false and checks a committed symlink out
as a text file containing the string "AGENTS.md". In Git Bash, `ln -s` does not
even warn you: it exits 0 and silently makes a copy.

Replace <PROJECT_ID> and delete anything that does not apply.
-->

These instructions come from <https://github.com/tomasvicar/overleaf_agents>.
Keep that link here: it is where the compile image, the TeX Live package list,
and any fix to either of them live.

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

## Comments and review

Overleaf's comment threads and track changes live in Overleaf's database, not
in the files. They do not arrive with a clone, and a commit cannot answer one.
Leave anything that needs saying in the source instead:

- `\todo{...}` (`todonotes`) renders in the PDF margin, which is the only place
  a co-author working in the browser will see it. A plain `%` comment reaches
  whoever edits the source next, and nobody else.
- Mark substantive rewrites with `changes`: `\added{}`, `\deleted{}`,
  `\replaced{}`.

Both hide their markup for submission without deleting it, but the options
differ: `\usepackage[final]{changes}` and `\usepackage[final,obeyFinal]{todonotes}`.
`[final]` on its own does nothing in `todonotes`.

To show what changed between two revisions, build the marked-up PDF rather than
describing it in prose:

```bash
git show <rev>:main.tex > old.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest latexdiff old.tex main.tex > diff.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest diff.tex
```

Delete `old.tex`, `diff.tex` and `diff.pdf` afterwards — they are not part of
the manuscript and must not be committed. For a journal word limit, run
`texcount -1 -sum main.tex` through the container the same way.

More on all of this — comment conventions, review rounds, git habits:
<https://github.com/tomasvicar/overleaf_agents/blob/main/docs/tips.md>.

## Conventions

- Never edit `*.cls` or `*.bst` files — they are the journal's, and the journal
  will use its own copies anyway.
- One sentence per line. LaTeX ignores single newlines, so the PDF is unchanged,
  but a diff then shows the sentence that changed rather than a repainted
  paragraph, and a merge with an Overleaf edit resolves per sentence. Keep the
  existing line structure of a paragraph you are editing; do not reflow one you
  are not.
- Bibliography entries go in the `.bib` file, never inline in the `.tex`.
- Figures are referenced by `\label`/`\ref`, never by hardcoded numbers.
- Everything committed here syncs into the Overleaf project and appears in every
  co-author's browser. Scratch files, analysis scripts and notes belong outside
  this repository.
- Numbers in the text come from the analysis outputs, never from memory. If you
  cannot find the source for one, say so rather than carrying it forward.
