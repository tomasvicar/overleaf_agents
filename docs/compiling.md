# Compiling

The one command, from the paper directory:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest
```

It finds the main file, runs `latexmk`, writes `main.pdf` to the repo root and
aux files to `build/`. Worth an alias in `~/.bashrc`:

```bash
alias paper='docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" ghcr.io/tomasvicar/latex-overleaf:latest'
```

## Variants

| What | How |
|---|---|
| A differently named main file | `... latex-overleaf:latest manuscript.tex` |
| XeLaTeX / LuaLaTeX | add `-e ENGINE=xelatex` (or `lualatex`) |
| `\write18` / gnuplot / shell-escape | add `-e SHELL_ESCAPE=1` |
| Aux files somewhere else | add `-e OUTDIR=.aux` |
| A shell inside the image | `... latex-overleaf:latest bash` |
| A specific TeX Live year | use tag `:TL2024` instead of `:latest` |

## podman, and Fedora/RHEL

Rootless podman already maps the container's root to your user, so **omit
`-u`** — passing it breaks file ownership rather than fixing it. On any
SELinux-enforcing distro add `:Z` to the mount:

```bash
podman run --rm -v "$PWD:/work:Z" ghcr.io/tomasvicar/latex-overleaf:latest
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
