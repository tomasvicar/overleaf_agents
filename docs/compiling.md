# Compiling

The one command, from the paper directory:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025
```

It finds the main file, runs `latexmk`, writes the PDF to the repo root and aux
files to `build/`. Worth an alias in `~/.bashrc`:

```bash
alias paper='docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" ghcr.io/tomasvicar/latex-overleaf:TL2025'
```

## When the main file is not `main.tex`

Usually nothing to do — the entrypoint picks it up. In order:

1. A filename you pass as an argument wins.
2. Otherwise `main.tex`, if it is there.
3. Otherwise the `.tex` files in the top of the directory are searched for
   `\documentclass`, and if **exactly one** has it, that is the manuscript.
   `sections/*.tex` and other `\input{}` fragments are not candidates — the
   search is not recursive and they carry no `\documentclass`.

So `manuscript.tex` alone compiles with the plain command and writes
`manuscript.pdf`. Two files with a `\documentclass` — a manuscript and a
`supplement.tex`, say — are ambiguous, and the container says so rather than
guessing:

```
compile-paper: several candidate main files; name one explicitly:
  ./manuscript.tex
  ./supplement.tex
```

Then name it: `... latex-overleaf:TL2025 manuscript.tex`.

**The PDF takes the name of the source**, which is the one thing to remember
elsewhere: `manuscript.tex` produces `manuscript.pdf`, so the `.gitignore` line
is `/manuscript.pdf`. The stock `/main.pdf` would not match it, and an unignored
PDF syncs to Overleaf and conflicts on every build.

## Variants

| What | How |
|---|---|
| A differently named main file | `... latex-overleaf:TL2025 manuscript.tex` |
| XeLaTeX / LuaLaTeX | add `-e ENGINE=xelatex` (or `lualatex`) |
| `\write18` / gnuplot / shell-escape | add `-e SHELL_ESCAPE=1` |
| Aux files somewhere else | add `-e OUTDIR=.aux` |
| A shell inside the image | `... latex-overleaf:TL2025 bash` |
| A specific TeX Live year | use the year tag, `:TL2025` — see below |

## Which tag

Two tags are published: **`TL2025`** and **`latest`**, and today they are the
same image. They will not stay that way — `latest` follows whichever TeX Live
year this repo builds now, so it moves when Overleaf moves, while `TL2025` keeps
pointing at TeX Live 2025 for good.

Check **Menu → Settings → TeX Live version** in the Overleaf project and use the
matching year tag. That is the difference between a local compile that predicts
the Overleaf one and a local compile that merely resembles it. `latest` is fine
for a throwaway build; anything written into an `AGENTS.md` should name the year.

Older years are not published. The `Dockerfile` takes the year as a build
argument, so you can make one:

```bash
docker build --build-arg TL_YEAR=2024 -t latex-overleaf:TL2024 .
```

CI does not test that path — it builds 2025 only — and the build fails if
`packages.txt` names a package that did not exist in that release, which is then
the thing to trim.

## podman, and Fedora/RHEL

Rootless podman already maps the container's root to your user, so **omit
`-u`** — passing it breaks file ownership rather than fixing it. On any
SELinux-enforcing distro add `:Z` to the mount:

```bash
podman run --rm -v "$PWD:/work:Z" ghcr.io/tomasvicar/latex-overleaf:TL2025
```

## Windows

See [windows.md](windows.md). Short version: Docker Desktop with the WSL2
backend, work inside the Ubuntu shell, and every command above is unchanged.

## When a compile fails

The container prints the error lines from the log and exits non-zero. The full
log is `build/main.log`. `-halt-on-error` is on, so **the first error is the one
to read** — the rest are usually fallout from it.

A missing `.sty` is not a problem with your manuscript. Do not rewrite the LaTeX
to avoid the package; see [adding-packages.md](adding-packages.md).

## minted

Deliberately left out. It shells out to Pygments, so it needs a Python
installation in the image as well as the package, and that is a bigger thing to
carry than one syntax highlighter is worth. `listings` is installed and needs no
shell escape.

The [upstream TeX Live image](using-upstream-texlive.md) does not solve this
either — layer `python3` and `pygments` on top of whichever image you use.
