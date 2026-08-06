# overleaf_agents

Compile an Overleaf manuscript locally in a pinned container, and keep the local
clone, GitHub and Overleaf in sync with a handful of git commands. So that you —
or a coding agent — can write the paper in your editor, build the real PDF, and
push it to Overleaf where your co-authors see it.

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

- Compiles `main.tex` into `main.pdf`; aux files land in `build/`.
- Nothing to install into your paper repo — no devcontainer, no `.env`, no
  wrapper script, no extension. Just `git`, `docker`, and the line above.
- Pinned to the TeX Live release Overleaf runs (**Menu → Settings → TeX Live
  version**) via TeX Live's frozen *historic* repository, so a clean local
  compile means something about whether it compiles on Overleaf.
- `scheme-basic` + [`packages.txt`](packages.txt): 647 MB unpacked, ~300 MB over
  the wire, against 2.6 GB for full TeX Live — and built for `arm64` too.

---

## Quick start

Set-up is a one-off: install Docker (**0**), let an agent lay the directory out
(**1**), connect it to your Overleaf project (**2**). Step **3** is optional.
Fifteen minutes, most of it downloads. After that you are in
[Everyday commands](#everyday-commands).

### 0) Prerequisites

You need `git`, `docker`, and an Overleaf **paid plan** — the git integration
this builds on is a paid-plan feature. You do *not* need TeX Live on your
machine, an Overleaf extension, or anything installed into the paper itself.

- **Linux** — Docker Engine, <https://docs.docker.com/engine/install/>. Rootless
  podman also works: drop `-u`, and add `:Z` to the mount on SELinux systems.
- **macOS** — Docker Desktop,
  <https://docs.docker.com/desktop/setup/install/mac-install/>. Apple Silicon
  runs the native `arm64` image.
- **Windows** — Docker Desktop with the **WSL2 backend**,
  <https://docs.docker.com/desktop/setup/install/windows-install/>. New to WSL?
  <https://learn.microsoft.com/windows/wsl/install>. Then work in one of two
  shells:

  1. **Ubuntu (WSL2)** — recommended. Every command in this repo runs exactly as
     written, `$(id -u)` included. Needs *Docker Desktop → Settings → Resources
     → WSL integration* switched on for the distribution, and the paper kept
     under `~/` rather than `/mnt/c` — across that boundary compiles are ~2.5×
     slower.
  2. **PowerShell** — drop `-u`, and write the mount as `"${PWD}:/work"`.
     Nothing to install beyond Git for Windows.

  Not Git Bash: it rewrites the container path and the compile fails to find
  your `.tex`.

Check both are there before going on; the second line should print a hello
message and exit:

```bash
git --version
docker run --rm hello-world
```

Detail: **[docs/windows.md](docs/windows.md)** — install steps and four
Windows-specific traps.

### 1) Let an agent set the directory up

Make an **empty** directory for the paper, open a coding agent — Claude Code,
Codex, Gemini CLI — in it, and give it one line:

```bash
mkdir my-paper && cd my-paper
```

> Set this directory up as an Overleaf-linked paper repository following
> <https://github.com/tomasvicar/overleaf_agents>, and tell me how to pair it
> with my Overleaf project.

- It reads this repo for the rest: which files to copy in, which image to pull,
  what the remote should be called.
- What it should end up doing: pull `ghcr.io/tomasvicar/latex-overleaf:latest`,
  copy [`AGENTS.snippet.md`](AGENTS.snippet.md) in as `AGENTS.md` **and**
  `CLAUDE.md`, and write a `.gitignore` with `build/`, the aux patterns and
  `/main.pdf`.
- Do not give it your Overleaf token — step 2 is yours.

No agent? Do those three things by hand; nothing here needs one.

### 2) Connect the directory to your Overleaf project

Two values, both from Overleaf, both collected by you:

- **Token** — <https://www.overleaf.com/user/settings> → **Git integration** →
  **Generate token**. Copy it at once; Overleaf will not show it again. It is
  the password on the git remote — your account password is not.
- **Project ID** — the hex string in the project URL,
  `overleaf.com/project/<PROJECT_ID>`. The project's **Integrations → Git**
  dialog also shows the whole clone command with the ID in it.

If the directory is still empty, one clone does it:

```bash
git clone https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID> my-paper
cd my-paper
git remote rename origin overleaf
```

If step 1 already put files there, `git clone` refuses — attach the remote to
what is there instead:

```bash
git init -b main
git remote add overleaf https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID>
git fetch overleaf
git branch -f main overleaf/main
git symbolic-ref HEAD refs/heads/main
git reset --hard main       # overwrites same-named local files — copy them aside first
git branch --set-upstream-to=overleaf/main main
```

Either way the Overleaf side is now the remote called `overleaf`. Check it
worked — the manuscript is here and it builds:

```bash
ls main.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

Detail: **[docs/pairing.md](docs/pairing.md)** — keeping the token off disk,
older projects on `master`, the full `.gitignore`.

### 3) Optional: add GitHub as a second remote

Overleaf alone is a complete setup — skip this and everything below still works.
GitHub buys you history browsing, branches, pull requests and CI, which the
Overleaf git bridge has none of. The cost is one extra push per change.

```bash
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

Keep the repo **private** if the paper is unpublished — and note `AGENTS.md`
carries your project ID once it is substituted in.

Detail: **[docs/pairing.md#adding-github-as-a-second-remote](docs/pairing.md)**.

## Everyday commands

Set-up is done; from here it is one conversation with the agent — *fix the
overfull boxes in section 3, rebuild, push to Overleaf* — and these five lines
underneath it.

```bash
git pull overleaf main --no-rebase        # before starting, and after a rejected push
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
git add -A && git commit -m "..."
git push overleaf main
git push origin main                      # only if you added a GitHub remote
```

- **Never force-push.** Overleaf rejects it, and it would destroy browser edits.
- **Always compile before pushing** — a broken build there is visible to every
  co-author immediately.
- **A rejected push means someone edited in the browser.** Pull with
  `--no-rebase`, fix the conflict in the `.tex`, push again. Never rebase over
  Overleaf's commits.

Detail: **[docs/compiling.md](docs/compiling.md)** — XeLaTeX, a differently
named main file, shell-escape, podman, reading a failed build.

## Telling an agent about it

- Copy [`AGENTS.snippet.md`](AGENTS.snippet.md) into the paper repo as **both**
  `AGENTS.md` (Codex, Gemini CLI, most others) and `CLAUDE.md` (Claude Code).
  That is the entire integration — the commands, where the agent looks.
- Optionally copy [`skills/overleaf-paper/`](skills/overleaf-paper/SKILL.md) to
  `~/.claude/skills/overleaf-paper/`: a Claude Code skill with the same compile,
  sync and latexdiff commands, so a fresh session has them without an
  `AGENTS.md` in front of it. Convenience, not a separate mechanism.
- Start the agent one level **above** the paper, with `analysis/` and `notes/`
  beside it, and it can write from your real numbers instead of rewording your
  sentences.

Detail: **[docs/working-with-agents.md](docs/working-with-agents.md)** — the
directory layout, and prompts worth stealing.

## Comments, notes and other tips

- Overleaf's **comment threads and track changes are not files**. They live in
  Overleaf's database, do not arrive with a clone, and a commit cannot answer
  one.
- Use `\todo{}` (`todonotes`) for comments that render in the PDF where a
  browser-only co-author sees them, and `changes` for marked-up rewrites.
- Use `latexdiff` (in the image) to show a co-author what changed between two
  revisions. That is what replaces track changes.
- Write **one sentence per line** — the PDF is identical, but diffs and merges
  become per-sentence instead of per-paragraph.

Detail: **[docs/tips.md](docs/tips.md)** — those recipes, the
`[final,obeyFinal]` trap, tagging what you send out, a `pre-push` hook that
compiles, whether GitHub issues are worth it, and the things that bite once.

## Missing packages

- A missing `.sty` is not a problem with your manuscript. **Do not rewrite the
  LaTeX to avoid the package.**
- To get unstuck now, extend the image:

  ```bash
  docker build -t latex-overleaf:local - <<'EOF'
  FROM ghcr.io/tomasvicar/latex-overleaf:latest
  RUN tlmgr install datetime2 && kpsewhich datetime2.sty
  EOF
  ```

  then compile with `latex-overleaf:local`. Keep the `kpsewhich`: **`tlmgr
  install` exits 0 even when the download failed**, so it is the only thing that
  turns a silent failure into a failed build.
- For a permanent fix, add the package to [`packages.txt`](packages.txt) and
  open a PR — CI rebuilds and publishes the image, once per package, for
  everyone.

Detail: **[docs/adding-packages.md](docs/adding-packages.md)** — finding which
package provides a given `.sty`, and forking to publish your own image. Or skip
the question entirely with the upstream TeX Live **full** image (2.6 GB, no
`arm64`): **[docs/using-upstream-texlive.md](docs/using-upstream-texlive.md)**.

---

## Documentation

| | |
|---|---|
| [docs/tips.md](docs/tips.md) | Comments and notes, diffable source, git habits, review rounds |
| [docs/pairing.md](docs/pairing.md) | Token, project ID, remotes, `.gitignore` |
| [docs/compiling.md](docs/compiling.md) | Compile options, podman, reading a failed build |
| [docs/windows.md](docs/windows.md) | WSL2 + Docker Desktop, and the Windows traps |
| [docs/working-with-agents.md](docs/working-with-agents.md) | Giving an agent context, and prompts that work |
| [docs/adding-packages.md](docs/adding-packages.md) | Adding a package, forking to publish your own image |
| [docs/using-upstream-texlive.md](docs/using-upstream-texlive.md) | The upstream full TeX Live image as an alternative |
| [docs/prehled.html](docs/prehled.html) | Illustrated overview of the whole design (Czech) |

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
docs/                          everything in the table above
```

## Bumping the TeX Live version

When Overleaf moves to a new TeX Live release: change `DEFAULT_TL_YEAR` and the
matrix entry in `.github/workflows/image.yml`, and `TL_YEAR` in the `Dockerfile`.
Add the old year to the matrix to keep publishing its tag. Old tags keep working
either way — that is the point of pinning to the historic repositories.
