# overleaf_agents

Compile an Overleaf manuscript locally in a pinned container, and keep the local
clone, GitHub and Overleaf in sync with a handful of git commands. So that you —
or a coding agent — can write the paper in your editor, build the real PDF, and
push it to Overleaf where your co-authors see it.

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025
```

- Compiles `main.tex` into `main.pdf`; aux files land in `build/`.
- Nothing to install into your paper repo — no devcontainer, no `.env`, no
  wrapper script, no extension. Just `git`, `docker`, and the line above.
- Pinned to the TeX Live release Overleaf runs (**Menu → Settings → TeX Live
  version**) via TeX Live's frozen *historic* repository, so a clean local
  compile means something about whether it compiles on Overleaf. Pin it in your
  own repo with the year tag — `:TL2025` — not `:latest`.
- `scheme-basic` + [`packages.txt`](packages.txt): 647 MB unpacked, ~300 MB over
  the wire, against 2.6 GB for full TeX Live — and built for `arm64` too.

---

## Quick start

Set-up is a one-off: install Docker (**0**), clone your Overleaf project (**1**),
let an agent fill in the rest (**2**). Step **3** is optional. Fifteen minutes,
most of it downloads. After that you are in
[Everyday commands](#everyday-commands) — and if a step does not go as written,
[When something fails](#when-something-fails).

### 0) Prerequisites

You need `git`, `docker`, and an Overleaf **paid plan** — the git integration
this builds on is a paid-plan feature. You do *not* need TeX Live on your
machine, an Overleaf extension, or anything installed into the paper itself.

- **Linux** — Docker Engine, <https://docs.docker.com/engine/install/>. Rootless
  podman also works: drop `-u`, and add `:Z` to the mount on SELinux systems.
- **macOS** — Docker Desktop,
  <https://docs.docker.com/desktop/setup/install/mac-install/>. Apple Silicon
  runs the native `arm64` image.
- **Windows** — **WSL2 first, then Docker Desktop**: Docker treats WSL2 as a
  prerequisite and does not turn it on for you. In an *administrator*
  PowerShell:

  ```powershell
  wsl --install                                  # WSL2 + Ubuntu; reboot when it asks
  winget install -e --id Docker.DockerDesktop    # or the installer from the link below
  ```

  Start Docker Desktop from the Start menu once and leave it running — the whale
  in the tray. Then pick the shell you will do the work in:

  **A. Ubuntu (WSL2)** — recommended. Every command in this repo runs exactly as
  written, `$(id -u)` included. Tick *Docker Desktop → Settings → Resources → WSL
  integration* for Ubuntu, open the Ubuntu shell (Start → Ubuntu, or `wsl` in any
  terminal), install git there with `sudo apt update && sudo apt install -y git`,
  and keep the paper under `~/` rather than `/mnt/c` — across that boundary
  compiles are ~2.5× slower.

  **B. PowerShell** — no Ubuntu needed (Docker runs in its own `docker-desktop`
  distribution, so `wsl --install --no-distribution` is enough) and no
  integration toggle. Install git with `winget install -e --id Git.Git`. Every
  compile line in this repo then needs `-u` dropped and the mount written
  `"${PWD}:/work"`, like this — later, once you have a paper to compile:

  ```powershell
  docker run --rm -v "${PWD}:/work" ghcr.io/tomasvicar/latex-overleaf:TL2025
  ```

  Docker's own install page:
  <https://docs.docker.com/desktop/setup/install/windows-install/>; Microsoft on
  WSL: <https://learn.microsoft.com/windows/wsl/install>.

Then, in whichever shell you settled on, check both tools answer. The second
line prints a hello message and exits:

```bash
git --version
docker run --rm hello-world
```

Detail: **[docs/windows.md](docs/windows.md)** — install steps and four
Windows-specific traps.

### 1) Clone your Overleaf project

Two values, both from Overleaf, both collected by you — an agent can fetch
neither, and there is nothing it could do with them faster than you can:

- **Token** — <https://www.overleaf.com/user/settings> → **Git integration** →
  **Generate token**. Copy it at once; Overleaf will not show it again. It is
  the password on the git remote — your account password is not.
- **Project ID** — the hex string in the project URL,
  `overleaf.com/project/<PROJECT_ID>`. The project's **Integrations → Git**
  dialog also shows the whole clone command with the ID in it.

```bash
git clone https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID> <my-paper>
cd <my-paper>
git remote rename origin overleaf
```

The Overleaf side is now the remote called `overleaf` — that name is what every
instruction in this repo, and every instruction an agent gets, is written
against. `ls` should show your manuscript; the main file is usually `main.tex`,
and if yours is called something else, note the name — the compile takes it as
an argument.

Putting the token in the URL writes it to `.git/config` in the clear. It is a
revocable token rather than a password, but you can leave it out and let git
prompt instead.

Detail: **[docs/pairing.md](docs/pairing.md)** — keeping the token off disk,
older projects on `master`, attaching to a directory that already has files.

### 2) Let an agent set the rest up

Open a coding agent — Claude Code, Codex, Gemini CLI — **in that directory**,
and give it one line:

> Set this directory up as an Overleaf-linked paper repository following
> <https://github.com/tomasvicar/overleaf_agents>, then compile the paper.

- It reads this repo for the rest: which files to copy in, which image to pull.
- What it should end up doing: pull the image, copy
  [`AGENTS.snippet.md`](AGENTS.snippet.md) in as `AGENTS.md` **and** `CLAUDE.md`
  with your project ID and image tag substituted, write a `.gitignore` covering
  `build/`, the aux patterns and `/main.pdf`, and leave you a `main.pdf`.
- Your token stays out of it — the remote from step 1 already carries it.

No agent? Do those three things by hand, then compile:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025
```

**Which tag.** Open **Menu → Settings → TeX Live version** in your Overleaf
project and use the tag for that year — `:TL2025` today. Pinning is the whole
point of the image, and only the `TL<year>` tag holds it: `:latest` follows
whatever year this repo builds now, so it will move under you when Overleaf
moves. Published tags are `TL2025` and `latest`; if your project sits on an
older release, build that year yourself with
`docker build --build-arg TL_YEAR=2024 .` — CI does not build old years, and you
may have to drop `packages.txt` entries that did not exist yet.

### 3) Optional: add GitHub as a second remote

Overleaf alone is a complete setup — skip this and everything below still works.
GitHub buys you history browsing, branches, pull requests and CI, which the
Overleaf git bridge has none of. The cost is one extra push per change.

With the GitHub CLI, one line creates the repository and pushes to it:

```bash
gh repo create <repo> --private --source=. --push
```

Without it, create an **empty** repository in the browser first — `git push` to
one that does not exist fails with *Repository not found* — then:

```bash
git remote add origin git@github.com:<you>/<repo>.git      # or https://github.com/<you>/<repo>.git
git push -u origin main
```

The SSH form needs a key on your account; the HTTPS form asks for a personal
access token. Keep the repo **private** if the paper is unpublished — and note
`AGENTS.md` carries your project ID once it is substituted in.

Detail: **[docs/pairing.md](docs/pairing.md#adding-github-as-a-second-remote)**
— what GitHub buys you, and what it costs.

## Everyday commands

Set-up is done; from here it is one conversation with the agent — *fix the
overfull boxes in section 3, rebuild, push to Overleaf* — and these five lines
underneath it.

```bash
git pull overleaf main --no-rebase        # before starting, and after a rejected push
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025
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
- **In PowerShell** every `docker run` above loses `-u "$(id -u):$(id -g)"` and
  writes the mount as `-v "${PWD}:/work"`. The `git` lines are unchanged.

Detail: **[docs/compiling.md](docs/compiling.md)** — XeLaTeX, a differently
named main file, shell-escape, podman, reading a failed build.

## When something fails

| What you see | What it is |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop is not running; on Linux, your user is not in the `docker` group — `sudo usermod -aG docker $USER`, then log out and back in. |
| `Authentication failed` on clone or push | The password on an Overleaf remote is the **git token**, never your account password. Tokens can be regenerated at <https://www.overleaf.com/user/settings>. |
| `fatal: destination path '<my-paper>' already exists` | The directory is not empty, so `git clone` refuses it. Attach the remote to what is there: [docs/pairing.md](docs/pairing.md#attaching-to-a-directory-that-already-has-files). |
| `compile-paper: no main.tex and no .tex file with \documentclass` | You are not in the paper directory, or the mount is wrong. In Git Bash `/work` is rewritten before Docker sees it — [docs/windows.md](docs/windows.md). |
| `compile-paper: several candidate main files` | More than one `.tex` has a `\documentclass`. Name the right one: `... latex-overleaf:TL2025 manuscript.tex`. |
| `LaTeX Error: File 'x.sty' not found` | The image lacks that package — see [Missing packages](#missing-packages). Do not rewrite the manuscript around it. |
| `Updates were rejected` on `git push overleaf` | Someone edited the project in the browser. `git pull overleaf main --no-rebase`, resolve in the `.tex`, push again. Never force. |
| `wsl --install` fails with `0x80370102` | Virtualization is off in the BIOS/UEFI — [docs/windows.md](docs/windows.md). |

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
  FROM ghcr.io/tomasvicar/latex-overleaf:TL2025
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

The two things you copy into the paper itself:

| | |
|---|---|
| [AGENTS.snippet.md](AGENTS.snippet.md) | Goes in as `AGENTS.md` and `CLAUDE.md` — the whole agent integration |
| [skills/overleaf-paper/](skills/overleaf-paper/SKILL.md) | Optional Claude Code skill with the same commands |

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
Then sweep the year tag through the prose, which names it rather than `:latest`
on purpose — `grep -rl TL2025 . --exclude-dir=.git`. Papers already set up keep
compiling against the old year until someone edits their `AGENTS.md`, which is
the point.
Add the old year to the matrix to keep publishing its tag. Old tags keep working
either way — that is the point of pinning to the historic repositories.
