# overleaf_agents

A prebuilt container that compiles an Overleaf manuscript locally, and the
handful of git commands that keep the local clone, GitHub and Overleaf in sync.

There is nothing to install and nothing to configure in your paper repository —
no devcontainer, no `.env`, no wrapper script, no VS Code extension. You need
`git` and `docker` (or `podman`), and the command below. On Windows that means
Docker Desktop with the WSL2 backend; see [Windows](#windows).

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

That compiles `main.tex` and writes `main.pdf` next to it. Aux files land in
`build/`.

---

## Quick start with an agent

Open a coding agent — Claude Code, Codex, Gemini CLI — in the directory you
want the paper in, and give it one line:

> Set this directory up as an Overleaf-linked paper repository following
> <https://github.com/tomasvicar/overleaf_agents>, and tell me how to pair it
> with my Overleaf project.

It reads the rest of this README for the details: which files to copy in, which
image to pull, what the git remote should be called.

Then pair the project yourself with the commands in [Setup](#setup-once-per-paper),
rather than handing your Overleaf token to the agent. After that it is all one
conversation — *fix the overfull boxes in section 3, rebuild, push to Overleaf*.

---

## Why this works without a full TeX Live install

Overleaf runs a specific TeX Live release, which you can see in **Menu →
Settings → TeX Live version**. The image is pinned to the same release through
TeX Live's frozen *historic* repository, so "it compiles locally" is a
meaningful statement about whether it will compile on Overleaf.

The image is deliberately small — `scheme-basic` plus the package list in
[`packages.txt`](packages.txt) — which puts it at 647 MB unpacked, about 300 MB
over the wire, against roughly 2.6 GB for a full TeX Live image. It is also
built for `arm64` as well as `amd64`, which `texlive/texlive` is not.
That is the one place where it differs from Overleaf, which ships TeX Live
*full*. If your paper needs a package that is not in the list, see
[Missing packages](#missing-packages) below; it is a two-minute fix and it only
has to be done once per package, for everyone.

---

## Setup, once per paper

The two values below are yours to fetch — an agent cannot get them for you,
and there is no reason to give it either one.

### 1. Get an Overleaf git token

**Account Settings → Git integration → Generate token**, at
<https://www.overleaf.com/user/settings>. Copy it now — Overleaf will not show
it again. The token is the only thing accepted as the password on the git
remote; your Overleaf account password is not.

> Overleaf's git integration is a **paid-plan feature** (Overleaf Cloud
> Standard/Professional, or Server Pro). Without it there is no git remote to
> clone and this workflow does not apply.

### 2. Find the project ID

It is the hex string in the project URL, `overleaf.com/project/<PROJECT_ID>`.

Overleaf will also spell out the whole clone command for you: open the project
and choose **Git** under the **Integrations** button in the left sidebar (in
the older interface, **Menu → Git**). The dialog shows the clone URL with the
ID already in it.

### 3. Clone the Overleaf project

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

That writes the token to `.git/config` in the clear. It is a token scoped to
your Overleaf account, not a password, and it can be revoked from the same
settings page — but if you would rather it not sit on disk, leave the URL
without it and let git prompt, or use a credential helper.

Renaming the remote to `overleaf` right away is worth the extra line: it keeps
one name for the Overleaf side whether or not you ever add GitHub, so every
instruction below — and every instruction the agent gets — reads the same in
both setups.

**If the directory is not empty** — you already put an `AGENTS.md` or a
`.gitignore` there — `git clone` refuses. Attach the remote to what is already
there instead:

```bash
git init -b main
git remote add overleaf https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID>
git fetch overleaf
git branch -f main overleaf/main
git symbolic-ref HEAD refs/heads/main
git reset --hard main                        # see the warning below
git branch --set-upstream-to=overleaf/main main
```

`git reset --hard` leaves your untracked files alone *unless* the Overleaf
project has a file of the same name, which it silently overwrites — copy
anything you care about aside first. Older Overleaf projects use `master`
rather than `main`; `git branch -r` after the fetch tells you which.

### 4. Optional: add GitHub as a second remote

Overleaf alone is a complete setup. If that is what you want, skip this step;
`overleaf` is your only remote and everything still works.

GitHub buys you history browsing, branches, pull requests and CI, which the
Overleaf git bridge does not have. The cost is one extra push per change.

```bash
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

### 5. Keep aux files out of git

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
/main.pdf
```

The last line is the PDF this image writes to the repo root. Overleaf compiles
its own copy, so committing yours only produces a binary conflict on every
build. Keep it out unless you specifically want the PDF browsable on GitHub —
and note that `*.pdf` would be wrong here, since figures are often PDFs.

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
| `\write18` / gnuplot / shell-escape | add `-e SHELL_ESCAPE=1` |
| Aux files somewhere else | add `-e OUTDIR=.aux` |
| A shell inside the image | `... latex-overleaf:latest bash` |
| A specific TeX Live year | use tag `:TL2024` instead of `:latest` |

`minted` is the one common package deliberately left out: it shells out to
Pygments, so it needs a Python installation in the image as well as the
package, and that is a bigger thing to carry than one syntax highlighter is
worth. `listings` is installed and needs no shell escape. If you must have
`minted`, the [upstream TeX Live image](#or-have-no-missing-packages-at-all-the-upstream-tex-live-image)
does not solve it either — layer `python3` and `pygments` on top of whichever
image you use.

### Windows

**Docker Desktop with the WSL2 backend** — its default — is the whole
requirement. Install it and let it turn WSL2 on. Hyper-V mode and "Windows
containers" are not it: this is a Linux image.

Then **do the work inside WSL2**. Open the Ubuntu shell, keep the paper under
`~/`, and every command in this README works exactly as written, `$(id -u)`
included. A paper under `/mnt/c/...` also compiles, but bind mounts across the
Windows filesystem boundary are several times slower — on a manuscript with a
bibliography that is the difference between a two-second and a twenty-second
rebuild.

If you would rather stay in PowerShell, drop `-u`; there are no Linux uids to
give it, and Docker Desktop maps ownership for you:

```powershell
docker run --rm -v "${PWD}:/work" ghcr.io/tomasvicar/latex-overleaf:latest
```

In `cmd.exe` the mount is `-v "%cd%:/work"` instead.

Three traps, all of them Windows-specific:

- **Git Bash rewrites container paths.** MSYS turns `/work` into
  `C:/Program Files/Git/work` before Docker sees it, and the compile stops with
  *no main.tex ... is the project directory mounted at /work?*. Prefix the
  command with `MSYS_NO_PATHCONV=1`, or write the container side as `//work`.
- **Symlinks need Developer Mode.** `ln -s AGENTS.md CLAUDE.md` fails without
  it. Copy the file twice instead, and remember edits have to go into both.
- **Line endings.** Overleaf stores LF. Set `git config core.autocrlf input` in
  the paper repo so nothing ever commits CRLF into it — otherwise a co-author
  sees a diff touching every line of a file you changed one word in.

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

## Reviewing, comments and change tracking

The git bridge moves files. That is worth saying out loud, because two of the
things people rely on in Overleaf are not files:

- **Comment threads** and **track changes** live in Overleaf's database. Clone
  the project and they are not in it. An agent working in the clone cannot read
  a reviewer's comment, and nothing it commits can answer one.
- **Overleaf's own history** is not the git history either. The two run
  alongside each other and neither summarises the other.

So decide once where review happens. If the answer is "in the browser, in
comment threads", that is a legitimate choice — and this workflow is then the
wrong tool for that paper.

### Comments that survive the round trip

Put them in the source, where both sides can see them:

| Form | What it gets you |
|---|---|
| `% an ordinary TeX comment` | Invisible in the PDF. Fine for a note to whoever edits the source next, useless to a co-author who only ever reads the PDF. |
| `\todo{is this the Aug run?}` (`todonotes`) | Renders in the margin of the compiled PDF, so a browser-only co-author sees it on Overleaf without doing anything. |
| `\added{}`, `\deleted{}`, `\replaced{}` (`changes`) | Marks up who changed what, in the PDF, and `\listofchanges` collects them. The closest thing to track changes that is made of text. |

Both packages are in the image. Neither has to be stripped before submission:
`\usepackage[final]{todonotes}` and `\usepackage[final]{changes}` make the
markup vanish without deleting any of it.

One thing to ask of co-authors: if they are editing in the browser with track
changes on, have them accept or reject before you pull. What the bridge hands
you is the document text — "this part is a pending tracked change" is not
something a git commit can carry.

### The git history *is* the change tracking

`git log`, `git show` and `git diff` are the record, and in the ways that
matter they beat Overleaf's history: they have messages, they are per-change
rather than per-keystroke, and an agent can read them. Ask *what changed in
section 4 since Monday* and it answers from `git log`.

For co-authors who want to *see* the changes, hand them a marked-up PDF.
`latexdiff` is in the image:

```bash
git show HEAD~5:main.tex > old.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest latexdiff old.tex main.tex > diff.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest diff.tex
```

`diff.pdf` comes out with additions underlined and deletions struck through.
Any two revisions work — five commits back, a tag, the commit you last sent
someone. Attaching that to "I revised the discussion" is a better review round
than a comment thread, and the agent can produce it on request.

Two more things in the image, for the same reason: `texcount` (`texcount -1
-sum main.tex`) when the journal has a word limit, and `chktex` for linting.

### Does GitHub issues make sense?

If you added the GitHub remote: yes, with one condition.

Issues and pull requests are a real review surface — threaded, assignable, and
readable by an agent (`gh issue list`, `gh pr view`), which is exactly what
Overleaf's comments are not. Branch per revision round, open a PR, review the
diff, merge, then one push to Overleaf: that holds together, and it gives the
agent somewhere to write down what it did.

The condition is that your co-authors will actually open GitHub. For a paper
with three clinicians on it they will not, and pushing it costs more than it
buys. Then `\todo{}` in the PDF is the honest answer, and GitHub stays what it
is anyway — your history and your backup.

---

## Missing packages

A missing `.sty` is not a problem with your manuscript — do not rewrite the
LaTeX to avoid the package. To get unstuck immediately, extend the image with a
two-line Dockerfile:

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

**[docs/adding-packages.md](docs/adding-packages.md)** has the rest: how to find
which package provides a given `.sty`, and how to fork this repo so CI builds
and publishes an image with your package in it — a real tag your co-authors can
pull, rather than something that exists only on your machine.

### Or have no missing packages at all: the upstream TeX Live image

The TeX Live project publishes its own images, pinned to the same frozen
historic releases this one builds from — and they are TeX Live **full**, which
is what Overleaf runs. Every package Overleaf has, they have. No `packages.txt`
to maintain, no fork, no missing `.sty` ever again:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  -u "$(id -u):$(id -g)" -e HOME=/tmp \
  texlive/texlive:TL2025-historic \
  latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error \
          -outdir=build main.tex
```

Match the year to **Menu → Settings → TeX Live version** in your project;
`TL2021-historic` through `TL2025-historic` exist. Using `latest` throws away
the parity that makes a local compile mean anything.

What it costs is 2.6 GB over the wire against 300 MB, and **no `arm64` build**:
on an Apple Silicon Mac it runs under emulation, several times slower, which is
the main reason this project's image exists at all. On Linux and Windows/WSL2
it is a perfectly reasonable choice — arguably the better one if image size
does not bother you. You also lose the `compile-paper` entrypoint, and with it
the main-file autodetection, the error summary and the ownership fix.

**[docs/using-upstream-texlive.md](docs/using-upstream-texlive.md)** has the
rest: layering the entrypoint back on with a two-line Dockerfile, and the flags
above explained.

Whichever image you settle on, the `docker run` line in your paper's
`AGENTS.md` has to match it — an agent following the default instructions will
otherwise pull the small image and hit the exact package you were avoiding.

---

## Telling an AI agent about this

Agents do not need an MCP server or a custom tool for any of the above — it is
`docker run` and `git`, both of which any coding agent can run through its shell.
What they need is for the commands to be written down in the repository they are
working in.

Copy [`AGENTS.snippet.md`](AGENTS.snippet.md) into your paper repo under **both**
names — `AGENTS.md` for Codex, Gemini CLI and most other agents, `CLAUDE.md` for
Claude Code:

```bash
cp AGENTS.snippet.md /path/to/paper/AGENTS.md
ln -s AGENTS.md /path/to/paper/CLAUDE.md      # or just copy it twice
```

A symlink keeps the two from drifting apart. On Windows without developer mode,
copy the file instead and remember to edit both. That is the whole integration.

If you want a `/paper` slash command in Claude Code on top of that, copy
[`skills/overleaf-paper/SKILL.md`](skills/overleaf-paper/SKILL.md) into
`~/.claude/skills/overleaf-paper/` — it is a convenience layer over the same
commands, not a separate mechanism.

### Keep the link back to here

The snippet's first line links to this repository. Leave it in the copy that
ends up in your paper. Months later, when the image is missing a package or the
TeX Live year has moved on, that line is what tells whoever is looking — a
co-author, a fresh agent, you — where these instructions came from and where a
fix belongs. A paper repo with a bare `docker run ghcr.io/...` in it and no
explanation is a small mystery you will have to solve twice.

### Give it the rest of the project

The paper repository has to stay exactly what Overleaf sees, so your analysis
code does not belong in it. Put it next door and start the agent one level up:

```
project/
  paper/      <- the Overleaf clone; the only thing that gets pushed
  analysis/   <- the code that produced the numbers, and its outputs
  notes/      <- lab notes, meeting minutes, reviewer emails
```

From `project/` the agent can read all three and still only ever commit inside
`paper/`. That is the difference between an agent that rewords your sentences
and one that can tell you the number in the abstract is not the number the
script printed.

What it buys, concretely:

> Read `analysis/results/summary.csv` and `notes/2026-07-lab-meeting.md`, then
> draft the Results section. Every number must come from the CSV — put the
> column you took it from in a `%` comment beside it. Invent nothing; if a
> number you need is missing, list it at the end instead.

and later, when the numbers move:

> `analysis/` reran overnight. Compare `results/summary.csv` against the values
> currently in section 4, list every one that changed, update the text, rebuild,
> and show me a latexdiff against HEAD before anything is pushed.

Where you can, make generated tables genuinely generated: have the analysis
script write `paper/tables/results.tex` and `\input{}` it, so a rerun updates
the manuscript instead of starting an argument about which number is current.

### Examples worth stealing

Proofreading, the thing most worth handing over:

> Proofread `main.tex`: typos, agreement, tense consistency, and any notation
> used two different ways. Do not change the meaning, the structure, or the
> references. Show me the list of edits first; then compile in the container,
> and if it builds, commit and push to Overleaf.

Note the order. The edits are shown before they are pushed, and the compile
happens before the push rather than after it. `AGENTS.md` already says as much,
but repeating it in the prompt costs nothing.

A round of reviewer comments:

> Reviewer 2's comments are in `notes/review-r2.md`. For each one either make
> the change or write one sentence saying why not, keeping
> `notes/response-to-reviewers.md` as you go. Mark every paragraph you touched
> with `\todo{R2.3}` so I can find them. Rebuild, then stop — do not push.

And the one that lets it clean up after itself:

> Compile. If it fails, read `build/main.log`, fix the first error only, and
> compile again. Do not edit the .cls file. Stop after three attempts and show
> me the log.

### Small things that pay off

- `git config pull.rebase false` in the paper repo. Overleaf's commits must
  never be rebased, and this makes the safe behaviour the default for everyone
  and everything working in that clone, agents included.
- A `pre-push` hook that compiles first. Two lines, and it removes the only
  really embarrassing failure mode — a broken build visible to every co-author.
- `echo '*.tex diff=tex' >> .gitattributes`. Git then labels diff hunks with the
  section they are in, which makes both `git diff` and the agent's reading of it
  markedly better.
- Commit messages in the imperative, one change each. They are the change log
  you will be reading back to co-authors, and the thing the agent summarises
  when you ask what happened last week.

---

## Repository layout

```
Dockerfile                     minimal TeX Live image, pinned to one TL release
packages.txt                   the package list — edit this to add a package
texlive.profile                install-tl profile (scheme-basic, no docs/sources)
compile-paper                  image entrypoint: latexmk wrapper + error summary
test/smoke.tex                 representative manuscript compiled by CI
test/class-*.tex               journal classes that need more than themselves
.github/workflows/image.yml    build, smoke test, push multi-arch to GHCR
AGENTS.snippet.md              paste-into-your-paper-repo instructions for agents
skills/overleaf-paper/         optional Claude Code slash command
docs/adding-packages.md        adding a package, and forking to publish your own image
docs/using-upstream-texlive.md the upstream full TeX Live image as an alternative
docs/prehled.html              illustrated overview of the whole design (Czech)
```

## Bumping the TeX Live version

When Overleaf moves to a new TeX Live release: change `DEFAULT_TL_YEAR` and the
matrix entry in `.github/workflows/image.yml`, and `TL_YEAR` in the `Dockerfile`.
Add the old year to the matrix to keep publishing its tag. Old tags keep working
either way — that is the point of pinning to the historic repositories.
