# Alternative: skip this image and use upstream TeX Live

**This is a side road, not the recommended path.** Read it only if missing
packages are bothering you more than image size does. If you are unsure, ignore
this page — the main [README](../README.md) describes the normal setup, and
[adding-packages.md](adding-packages.md) covers the one case where it needs
extending.

---

## The idea

The TeX Live project publishes its own Docker images, pinned to the same frozen
historic releases this project builds from:

```
texlive/texlive:TL2025-historic
```

That is TeX Live **full**. Every package Overleaf has, it has. The entire
"missing `.sty`" problem disappears, and so does any reason to maintain
`packages.txt`, a fork, or a registry of your own.

## What it costs

**Size.** 2.6 GB over the wire, roughly 6 GB unpacked, against 300 MB / 647 MB
for this project's image. A one-time download, but a slow one.

**No Apple Silicon.** This is the part that decides it for most people:

```console
$ docker manifest inspect texlive/texlive:TL2025-historic
single manifest — linux/amd64
```

There is no `arm64` build. On an M-series Mac it runs under emulation — several
times slower, and one more thing that can go wrong. This project's image
publishes native `amd64` and `arm64`, which is the main reason it exists at all.

**So: fine on Linux and on Windows/WSL2. Not a good idea on a Mac.**

You also lose the `compile-paper` entrypoint — the main-file autodetection, the
PDF copied to the repo root, the error summary and the ownership fix. The
[last section](#keeping-the-entrypoint) gets those back.

---

## Using it directly

Everything the entrypoint did has to go on the command line:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  -u "$(id -u):$(id -g)" -e HOME=/tmp \
  texlive/texlive:TL2025-historic \
  latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error \
          -outdir=build main.tex
```

Notes on the flags that are not obvious:

- `-e HOME=/tmp` — with `-u` the container user has no home directory, and TeX
  needs somewhere writable for its caches. Without this you get font cache
  errors that look unrelated to the real problem.
- `-w /work` — the upstream image has no working directory set.
- The PDF stays at `build/main.pdf`; nothing copies it to the repo root.

Rootless podman: drop `-u`, and on SELinux systems mount as `-v "$PWD:/work:Z"`.

Worth an alias:

```bash
alias paper='docker run --rm -v "$PWD:/work" -w /work -u "$(id -u):$(id -g)" -e HOME=/tmp texlive/texlive:TL2025-historic latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error -outdir=build main.tex'
```

## Match the year to Overleaf

The whole point of the `-historic` tags is that they are frozen, so pick the one
matching **Menu → Settings → TeX Live version** in your Overleaf project.
`TL2021-historic` through `TL2025-historic` exist. Using `latest` throws away
the parity that makes a local compile mean anything.

## Keeping the entrypoint

If you want upstream's package coverage *and* the short command, layer this
project's entrypoint on top. Two lines:

```bash
docker build -t latex-full:local - <<'EOF'
FROM texlive/texlive:TL2025-historic
ADD https://raw.githubusercontent.com/tomasvicar/overleaf_agents/main/compile-paper /usr/local/bin/compile-paper
RUN chmod +x /usr/local/bin/compile-paper
ENV HOME=/tmp TEXMFVAR=/tmp/texmf-var TEXMFCONFIG=/tmp/texmf-config
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/compile-paper"]
EOF
```

Then the command is short again:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" latex-full:local
```

---

## Telling your agent

Whichever variant you pick, the `docker run` line in your paper repo's
`AGENTS.md` and `CLAUDE.md` has to match it. An agent following the default
instructions will otherwise pull the small image and hit exactly the missing
package you were trying to avoid.
