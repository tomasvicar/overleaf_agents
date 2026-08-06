# overleaf_agents

A prebuilt container that compiles an Overleaf manuscript locally, and the
handful of git commands that keep the local clone, GitHub and Overleaf in sync.
So that you — or a coding agent — can write the paper in your editor, build the
real PDF, and push it to Overleaf where your co-authors see it.

There is nothing to install into your paper repository: no devcontainer, no
`.env`, no wrapper script, no extension. You need `git`, `docker`, and this:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

That compiles `main.tex` into `main.pdf`. Aux files land in `build/`.

The image is pinned to the same TeX Live release Overleaf runs (**Menu →
Settings → TeX Live version**), through TeX Live's frozen *historic*
repository — so "it compiles locally" says something meaningful about whether it
will compile on Overleaf. It is `scheme-basic` plus
[`packages.txt`](packages.txt): 647 MB unpacked, ~300 MB over the wire, against
2.6 GB for full TeX Live, and it is built for `arm64` as well as `amd64`.

---

## Prerequisites

| | What you need |
|---|---|
| **Linux** | Docker Engine — <https://docs.docker.com/engine/install/>. Rootless podman works too: drop `-u`, and on SELinux systems mount `-v "$PWD:/work:Z"`. |
| **macOS** | Docker Desktop — <https://docs.docker.com/desktop/setup/install/mac-install/>. Apple Silicon runs the native `arm64` image. |
| **Windows** | Docker Desktop with the **WSL2 backend**, then work inside the Ubuntu shell. If WSL is new to you: <https://learn.microsoft.com/windows/wsl/install> and <https://docs.docker.com/desktop/setup/install/windows-install/>. Step-by-step, plus four Windows-specific traps: **[docs/windows.md](docs/windows.md)**. |

An Overleaf **paid plan**, too — the git integration this builds on is a
paid-plan feature.

---

## Quick start with an agent

Open a coding agent — Claude Code, Codex, Gemini CLI — in the directory you want
the paper in, and give it one line:

> Set this directory up as an Overleaf-linked paper repository following
> <https://github.com/tomasvicar/overleaf_agents>, and tell me how to pair it
> with my Overleaf project.

It reads this repo for the rest: which files to copy in, which image to pull,
what the remote should be called. Then you pair the project yourself with the
commands below, rather than handing your Overleaf token to an agent.

After that it is one conversation — *fix the overfull boxes in section 3,
rebuild, push to Overleaf*.

---

## Pairing with Overleaf

**The token:** <https://www.overleaf.com/user/settings> → **Git integration** →
**Generate token**. Copy it at once, Overleaf will not show it again. It is the
password on the git remote; your account password is not.

**The project ID:** the hex string in the project URL,
`overleaf.com/project/<PROJECT_ID>`. The project's **Integrations → Git** dialog
shows the whole clone command with the ID already in it.

```bash
git clone https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID> my-paper
cd my-paper
git remote rename origin overleaf
```

Then copy [`AGENTS.snippet.md`](AGENTS.snippet.md) in as `AGENTS.md` (and
`CLAUDE.md`), substitute the project ID, and add `build/`, the aux patterns and
`/main.pdf` to `.gitignore`.

**[docs/pairing.md](docs/pairing.md)** covers the rest: attaching to a directory
that already has files (`git clone` refuses those), projects on `master`, GitHub
as an optional second remote, and the full `.gitignore`.

## Everyday commands

```bash
git pull overleaf main --no-rebase        # before starting, and after a rejected push
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
git add -A && git commit -m "..."
git push overleaf main
git push origin main                      # only if you added a GitHub remote
```

Two rules that matter: **never force-push** — Overleaf rejects it and it would
destroy browser edits — and **always compile before pushing**, because a broken
build there is visible to every co-author immediately. A rejected push means
someone edited in the browser: pull with `--no-rebase`, fix the conflict in the
`.tex`, push again.

**[docs/compiling.md](docs/compiling.md)** has the compile options — XeLaTeX, a
differently named main file, shell-escape, podman, reading a failed build.

---

## Telling an agent about it

Copy [`AGENTS.snippet.md`](AGENTS.snippet.md) into the paper repo as **both**
`AGENTS.md` (Codex, Gemini CLI, most others) and `CLAUDE.md` (Claude Code). That
is the entire integration — the commands, written down where the agent looks.

Optionally, copy [`skills/overleaf-paper/`](skills/overleaf-paper/SKILL.md) to
`~/.claude/skills/overleaf-paper/`. It is a Claude Code skill carrying the same
compile, sync and latexdiff commands, so a fresh session knows them without an
`AGENTS.md` in front of it. Convenience, not a separate mechanism.

**[docs/working-with-agents.md](docs/working-with-agents.md)** has what makes
this actually work: giving the agent your `analysis/` and `notes/` alongside the
paper so it writes from your real numbers, and prompts worth stealing —
proofread-build-push, a round of reviewer comments, fix-the-first-error.

## Comments, notes and other tips

The git bridge moves files. Overleaf's **comment threads and track changes are
not files** — they live in Overleaf's database, they do not arrive with a clone,
and a commit cannot answer one. Use `\todo{}` (`todonotes`) for comments that
render in the PDF where a browser-only co-author sees them, `changes` for
marked-up rewrites, and `latexdiff` (in the image) to show a co-author what
changed between two revisions.

**[docs/tips.md](docs/tips.md)** is the advice collection: those recipes and the
`[final,obeyFinal]` trap, writing one sentence per line so diffs and merges stay
readable, tagging what you send out, a `pre-push` hook that compiles, whether
GitHub issues are worth it, and the things that bite you once.

## Missing packages

A missing `.sty` is not a problem with your manuscript — do not rewrite the
LaTeX to avoid the package. To get unstuck now:

```bash
docker build -t latex-overleaf:local - <<'EOF'
FROM ghcr.io/tomasvicar/latex-overleaf:latest
RUN tlmgr install datetime2 && kpsewhich datetime2.sty
EOF
```

Then compile with `latex-overleaf:local`. Keep the `kpsewhich`: **`tlmgr install`
exits 0 even when the download failed**, so it is the only thing that turns a
silent failure into a failed build.

For a permanent fix, add the package to [`packages.txt`](packages.txt) and open
a PR — CI rebuilds and publishes the image, for everyone, once per package.
**[docs/adding-packages.md](docs/adding-packages.md)** has how to find which
package provides a given `.sty`, and how to fork this repo to publish your own
image.

Or avoid the question entirely with the upstream TeX Live **full** image, which
has everything Overleaf has — at 2.6 GB and with no `arm64` build:
**[docs/using-upstream-texlive.md](docs/using-upstream-texlive.md)**.

---

## Repository layout

```
Dockerfile                     minimal TeX Live image, pinned to one TL release
packages.txt                   the package list — edit this to add a package
texlive.profile                install-tl profile (scheme-basic, no docs/sources)
compile-paper                  image entrypoint: latexmk wrapper + error summary
test/                          ten manuscripts CI compiles: smoke, journal
                               classes, extra packages, both bibliography stacks
.github/workflows/image.yml    build, smoke test, push multi-arch to GHCR
AGENTS.snippet.md              paste-into-your-paper-repo instructions for agents
skills/overleaf-paper/         optional Claude Code skill
docs/tips.md                   comments, notes, diffable source, git habits
docs/pairing.md                token, project ID, remotes, .gitignore
docs/compiling.md              compile options, podman, reading a failed build
docs/windows.md                WSL2 + Docker Desktop, and the Windows traps
docs/working-with-agents.md    giving an agent context, and prompts that work
docs/adding-packages.md        adding a package, forking to publish your own image
docs/using-upstream-texlive.md the upstream full TeX Live image as an alternative
docs/prehled.html              illustrated overview of the whole design (Czech)
```

## Bumping the TeX Live version

When Overleaf moves to a new TeX Live release: change `DEFAULT_TL_YEAR` and the
matrix entry in `.github/workflows/image.yml`, and `TL_YEAR` in the `Dockerfile`.
Add the old year to the matrix to keep publishing its tag. Old tags keep working
either way — that is the point of pinning to the historic repositories.
