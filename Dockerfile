# syntax=docker/dockerfile:1
#
# A minimal TeX Live image whose only job is compiling a manuscript.
#
# It is pinned to one TeX Live release (the "historic" frozen tlnet repository),
# so the same image tag produces the same PDF a year from now -- and, more to the
# point, matches the TeX Live version selected in the Overleaf project.

ARG TL_YEAR=2025

# ---------------------------------------------------------------------------
# Stage 1: install TeX Live from the frozen tlnet repository for TL_YEAR.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS installer

ARG TL_YEAR
ARG TL_REPO=https://ftp.math.utah.edu/pub/tex/historic/systems/texlive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates wget perl fontconfig xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Base installation. Kept in its own layer so that editing packages.txt does not
# re-download the whole of TeX Live.
COPY texlive.profile /tmp/texlive.profile
RUN set -eux; \
    repo="${TL_REPO}/${TL_YEAR}/tlnet-final"; \
    sed -i "s|@TL_YEAR@|${TL_YEAR}|g" /tmp/texlive.profile; \
    mkdir -p /tmp/install-tl; \
    wget -qO- "${repo}/install-tl-unx.tar.gz" \
      | tar -xz -C /tmp/install-tl --strip-components=1; \
    /tmp/install-tl/install-tl \
      --profile=/tmp/texlive.profile \
      --repository="${repo}"; \
    rm -rf /tmp/install-tl /tmp/texlive.profile

ENV PATH=/usr/local/texlive/bin:$PATH
RUN ln -s "$(echo /usr/local/texlive/${TL_YEAR}/bin/*)" /usr/local/texlive/bin

# The packages the manuscripts actually need. tlmgr keeps going after an unknown
# package name, so verify afterwards and report every bad name at once rather
# than one per rebuild.
COPY packages.txt /tmp/packages.txt
RUN set -eu; \
    repo="${TL_REPO}/${TL_YEAR}/tlnet-final"; \
    pkgs="$(grep -vE '^\s*(#|$)' /tmp/packages.txt | tr '\n' ' ')"; \
    tlmgr --repository="${repo}" install ${pkgs} || true; \
    missing=""; \
    for p in ${pkgs}; do \
      tlmgr info --only-installed "$p" >/dev/null 2>&1 || missing="${missing} ${p}"; \
    done; \
    if [ -n "${missing}" ]; then \
      echo "ERROR: these packages.txt entries do not exist in TeX Live ${TL_YEAR}:" >&2; \
      for p in ${missing}; do echo "  - ${p}" >&2; done; \
      exit 1; \
    fi; \
    rm -f /tmp/packages.txt

# Drop everything that cannot affect a compile: docs, sources, unused binaries
# and the installer's own backup/log clutter.
RUN set -eux; \
    tldir="/usr/local/texlive/${TL_YEAR}"; \
    rm -rf "${tldir}/texmf-dist/doc" \
           "${tldir}/texmf-dist/source" \
           "${tldir}/texmf-var/web2c/tlmgr.log" \
           "${tldir}/tlpkg/backups" \
           "${tldir}/install-tl.log" \
           "${tldir}/texmf-dist/fonts/source"

# ---------------------------------------------------------------------------
# Stage 2: runtime.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim

ARG TL_YEAR
LABEL org.opencontainers.image.title="latex-overleaf" \
      org.opencontainers.image.description="Minimal TeX Live image for compiling Overleaf manuscripts locally" \
      org.opencontainers.image.source="https://github.com/tomasvicar/overleaf_agents"

# curl and ca-certificates are what tlmgr uses to fetch packages. Without them
# `tlmgr install` silently downloads nothing -- and still exits 0 -- so anyone
# extending this image would get a broken result that looks like a success.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      perl fontconfig libfontconfig1 ghostscript curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=installer /usr/local/texlive /usr/local/texlive

# /usr/local/texlive/bin is a symlink to the architecture-specific bin directory,
# created in the installer stage and carried over by the COPY above.
ENV PATH=/usr/local/texlive/bin:$PATH

# These must live somewhere world-writable: the container is normally run with
# --user $(id -u), which has no home directory inside the image.
ENV HOME=/tmp \
    TEXMFVAR=/tmp/texmf-var \
    TEXMFCONFIG=/tmp/texmf-config \
    TEXMFHOME=/texmf \
    TL_YEAR=${TL_YEAR}

# Optional persistent volume for runtime `tlmgr --usermode install`.
RUN mkdir -p /texmf && chmod 777 /texmf /tmp

COPY compile-paper /usr/local/bin/compile-paper
RUN chmod +x /usr/local/bin/compile-paper

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/compile-paper"]
