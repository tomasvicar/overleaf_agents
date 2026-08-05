# overleaf_agents

A prebuilt container that compiles an Overleaf manuscript locally, and the
handful of git commands that keep the local clone, GitHub and Overleaf in sync.

There is nothing to install and nothing to configure in your paper repository —
no devcontainer, no `.env`, no wrapper script, no VS Code extension. You need
`git` and `docker` (or `podman`), and the command below.

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

That compiles `main.tex` and writes `main.pdf` next to it. Aux files land in
`build/`.

---

## Why this works without a full TeX Live install

Overleaf runs a specific TeX Live release, which you can see in **Menu →
Settings → TeX Live version**. The image is pinned to the same release through
TeX Live's frozen *historic* repository, so "it compiles locally" is a
meaningful statement about whether it will compile on Overleaf.

The image is deliberately small — `scheme-basic` plus the package list in
[`packages.txt`](packages.txt) — so it pulls in seconds rather than minutes.
That is the one place where it differs from Overleaf, which ships TeX Live
*full*. If your paper needs a package that is not in the list, see
[Missing packages](#missing-packages) below; it is a two-minute fix and it only
has to be done once per package, for everyone.

---

## Setup, once per paper

### 1. Get an Overleaf git token

Overleaf → **Account Settings → Git Integration → Generate token**. Copy it now;
Overleaf will not show it again.

> Overleaf's git integration is a **paid-plan feature**. Without it there is no
> git remote to clone and this workflow does not apply.

### 2. Clone the Overleaf project

The project ID is the hex string in the Overleaf URL
(`overleaf.com/project/<ID>`).

```bash
git clone https://git@git.overleaf.com/<PROJECT_ID> my-paper
cd my-paper
git remote rename origin overleaf
```

Git will ask for a password — paste the token. To avoid retyping it, put it in
the remote URL:

```bash
git remote set-url overleaf https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID>
```

Renaming the remote to `overleaf` right away is worth the extra line: it keeps
one name for the Overleaf side whether or not you ever add GitHub, so every
instruction below — and every instruction the agent gets — reads the same in
both setups.

### 3. Optional: add GitHub as a second remote

Overleaf alone is a complete setup. If that is what you want, skip this step;
`overleaf` is your only remote and everything still works.

GitHub buys you history browsing, branches, pull requests and CI, which the
Overleaf git bridge does not have. The cost is one extra push per change.

```bash
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

### 4. Keep aux files out of git

Overleaf will happily sync `.aux` and `.fls` files into the project and they
cause pointless merge conflicts. Add to `.gitignore`:

```gitignore
build/
*.aux
*.log
*.out
*.fls
*.fdb_latexmk
*.synctex.gz
*.bbl
*.blg
```

---

## Compiling

```bash
# the normal case: main.tex -> main.pdf
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

Worth defining once in `~/.bashrc`:

```bash
alias paper='docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" ghcr.io/tomasvicar/latex-overleaf:latest'
```

Then it is just `paper`.

### Variants

| What | How |
|---|---|
| A differently named main file | `... latex-overleaf:latest manuscript.tex` |
| XeLaTeX / LuaLaTeX | add `-e ENGINE=xelatex` (or `lualatex`) |
| `\write18` / minted / gnuplot | add `-e SHELL_ESCAPE=1` |
| Aux files somewhere else | add `-e OUTDIR=.aux` |
| A shell inside the image | `... latex-overleaf:latest bash` |
| A specific TeX Live year | use tag `:TL2024` instead of `:latest` |

### podman, and Fedora/RHEL

Rootless podman already maps the container's root to your user, so **omit
`-u`** — passing it breaks file ownership rather than fixing it. On any
SELinux-enforcing distro add `:Z` to the mount:

```bash
podman run --rm -v "$PWD:/work:Z" ghcr.io/tomasvicar/latex-overleaf:latest
```

### When a compile fails

The container prints the error lines from the log and exits non-zero. The full
log is at `build/main.log`. `-halt-on-error` is on, so the first real error is
the one to read.

---

## Pushing

Overleaf **forbids force pushes**. Treat local `main` as the source of truth and
push fast-forwards only; if a push is rejected, someone edited the project in
the browser, so pull first.

```bash
git add -A
git commit -m "..."
git pull overleaf main --no-rebase   # only if the push below is rejected
git push overleaf main               # Overleaf
git push origin main                 # GitHub — only if you added that remote
```

If `overleaf` is your only remote, drop the last line; nothing else changes.

---

## Missing packages

Two options, in order of preference.

**Add it to the image** (permanent, helps everyone): add the package name to
[`packages.txt`](packages.txt) and open a PR. CI rebuilds the image, runs the
smoke-test compile and pushes new `amd64` + `arm64` tags.

**Extend the image locally** (immediate, no waiting for CI): a two-line
Dockerfile on top of the published one.

```bash
docker build -t latex-overleaf:local - <<'EOF'
FROM ghcr.io/tomasvicar/latex-overleaf:latest
RUN tlmgr install datetime2 && kpsewhich datetime2.sty
EOF
```

Then compile with `latex-overleaf:local` instead of the published tag. The
`kpsewhich` is not decoration: **`tlmgr install` prints `install: foo [9k]` and
exits 0 even when the download failed**, so without it a broken build looks
like a successful one. The same trap is why the image build verifies every
entry in `packages.txt` afterwards instead of trusting `tlmgr`'s exit code.

To find out which package provides a missing `foo.sty`, search
<https://ctan.org/pkg/foo> or run `tlmgr search --global --file foo.sty` inside
the container.

---

## Telling an AI agent about this

Agents do not need an MCP server or a custom tool for any of the above — it is
`docker run` and `git`, both of which any coding agent can run through its shell.
What they need is for the commands to be written down in the repository they are
working in.

Copy [`AGENTS.snippet.md`](AGENTS.snippet.md) into your paper repo's
`AGENTS.md` (Claude Code, Codex and Gemini CLI all read it; Claude Code also
reads `CLAUDE.md`, which can simply be a symlink). That is the whole
integration.

If you want a `/paper` slash command in Claude Code on top of that, copy
[`skills/overleaf-paper/SKILL.md`](skills/overleaf-paper/SKILL.md) into
`~/.claude/skills/overleaf-paper/` — it is a convenience layer over the same
commands, not a separate mechanism.

---

## Repository layout

```
Dockerfile                     minimal TeX Live image, pinned to one TL release
packages.txt                   the package list — edit this to add a package
texlive.profile                install-tl profile (scheme-basic, no docs/sources)
compile-paper                  image entrypoint: latexmk wrapper + error summary
test/smoke.tex                 representative manuscript compiled by CI
.github/workflows/image.yml    build, smoke test, push multi-arch to GHCR
AGENTS.snippet.md              paste-into-your-paper-repo instructions for agents
skills/overleaf-paper/         optional Claude Code slash command
```

## Bumping the TeX Live version

When Overleaf moves to a new TeX Live release: change `DEFAULT_TL_YEAR` and the
matrix entry in `.github/workflows/image.yml`, and `TL_YEAR` in the `Dockerfile`.
Add the old year to the matrix to keep publishing its tag. Old tags keep working
either way — that is the point of pinning to the historic repositories.
