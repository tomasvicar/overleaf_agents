# Windows

Everything in this repo works on Windows. What it needs is **Docker Desktop
with the WSL2 backend** — the default — and the discipline to do the work
inside WSL2 rather than beside it.

Tested on Windows 11 (build 26200) with Git for Windows 2.55, WSL 2.7.11 and
Docker Desktop 29.6.2.

## Installing, if you have not used WSL or Docker before

1. **WSL2 and a Linux distribution.** This comes first: Docker Desktop lists
   WSL2 as a prerequisite and does not enable it for you. In an *administrator*
   PowerShell:

   ```powershell
   wsl --install
   ```

   Reboot when it asks. That installs WSL2 and Ubuntu, and on first launch
   Ubuntu asks you to pick a username and password — unrelated to your Windows
   account. Microsoft's page, if anything goes sideways:
   <https://learn.microsoft.com/windows/wsl/install>

   If you intend to stay in PowerShell, `wsl --install --no-distribution` is
   enough — Docker Desktop brings its own `docker-desktop` distribution and does
   not need Ubuntu. Installing Ubuntu anyway costs a few hundred MB and keeps
   the better option open.

   You do not need to hunt for Windows features to tick beforehand: on Windows
   11 or Windows 10 2004+ (build 19041+) this one command *"will enable the
   features necessary to run WSL and install the Ubuntu distribution"*. Below
   that build, WSL needs the manual route instead:
   <https://learn.microsoft.com/windows/wsl/install-manual>.

   What the command cannot switch on is **virtualization in the BIOS/UEFI**. If
   it fails with `0x80370102` or `0x80070003`, that is the cause — turn
   virtualization on in the firmware setup (the wording differs per vendor;
   Microsoft's walkthrough:
   <https://support.microsoft.com/windows/c5578302-6e43-4b4b-a449-8ced115f58e1>)
   and reboot. Inside a VM it is nested virtualization that has to be exposed by
   the host, and a CPU older than roughly Intel Nehalem cannot run WSL2 at all —
   it lacks SLAT.

2. **Docker Desktop.** Either

   ```powershell
   winget install -e --id Docker.DockerDesktop
   ```

   or download the installer from
   <https://docs.docker.com/desktop/setup/install/windows-install/>. Accept the
   WSL2 backend when offered, and start it from the Start menu afterwards. It
   has to be *running* — the whale in the tray — before any `docker` command
   works.

   Then **Settings → Resources → WSL integration** and enable your Ubuntu
   distribution. Without that, `docker` exists in PowerShell but not in the
   Ubuntu shell, which is where you want it. Docker's page on the backend:
   <https://docs.docker.com/desktop/features/wsl/>

3. **Git.** Inside Ubuntu, for shell 1:

   ```bash
   sudo apt update && sudo apt install -y git
   ```

   For shell 2 it is Git for Windows instead — `winget install -e --id Git.Git`
   in PowerShell. You only need both if you intend to use git from both sides.

Then check Docker answers in whichever shell you picked:

```bash
docker run --rm hello-world
```

Hyper-V mode and "Windows containers" are not what this needs — the image is a
Linux one.

## The two shells, and what each needs

Docker is the same single install either way — Docker Desktop on the WSL2
backend, as in the steps above, WSL2 turned on first because Docker will not do
it for you. What differs is the compile line, and where the files sit.

**A. Ubuntu (WSL2)** — recommended, and the only shell where the commands in
this repo need no adjusting at all, `$(id -u)` included:

```bash
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025
```

Open it with Start → Ubuntu, or `wsl` in any terminal. Needs *Docker Desktop →
Settings → Resources → WSL integration* enabled for the distribution, and the
paper kept under `~/`. Nothing else on this page applies once you are there.

A paper under `/mnt/c/...` also compiles, but bind mounts across the Windows
filesystem boundary cost real time. Measured on one Windows 11 VM, same
manuscript, three clean compiles each: **11 s from the WSL2 filesystem against
29 s from `/mnt/c`** — roughly 2.5×. The absolute numbers are that machine's;
the ratio travels, and it grows with the number of files a compile touches,
which is exactly what a bibliography and a directory of figures do. Microsoft
says the same thing at greater length:
<https://learn.microsoft.com/windows/wsl/filesystems>

Access your Linux files from Explorer with `\\wsl$\Ubuntu\home\<you>`, or type
`explorer.exe .` in the Ubuntu shell.

**B. PowerShell** — drop `-u`: there is no `id` command to expand, and Docker
Desktop maps ownership for you.

```powershell
docker run --rm -v "${PWD}:/work" ghcr.io/tomasvicar/latex-overleaf:TL2025
```

Verified: it writes `main.pdf` beside the source, byte-identical to the one the
Linux command produces, readable and writable from Windows afterwards.

This route needs *less* than A, not more: no Ubuntu (Docker runs its own
`docker-desktop` distribution) and no WSL integration toggle, because Docker
Desktop puts `docker` on the Windows PATH by itself. The containers still run on
WSL2 underneath — there is just no Linux shell in front of them. What you do
need is **Git for Windows**, since the `git` half of the workflow has no Ubuntu
to live in. And the paper sits on the Windows filesystem, bind-mounted across
the same boundary `/mnt/c` crosses, so expect the penalty measured above — that
figure came from inside WSL2, not from PowerShell in turn, but it is the price
of keeping the files on `C:`, not a property of the shell.

**Not Git Bash**, and not `cmd.exe`. Git Bash rewrites the container path out
from under Docker (first trap below) and lies to you about symlinks (second),
and `cmd.exe` needs its own mount syntax to buy you nothing PowerShell does not
already do. Neither is worth carrying as a supported path.

## Four traps

All four checked on a real machine, not inferred.

**Git Bash rewrites container paths.** MSYS turns `/work` into
`C:/Program Files/Git/work` before Docker ever sees it — verbatim, that is what
`cmd //c echo /work` prints — and the compile stops with *no main.tex ... is the
project directory mounted at /work?*. That is the error to recognise if you end
up there; `MSYS_NO_PATHCONV=1` in front of the command, or `//work` as the
container side, gets you out of it once.

**`ln -s` does not fail — it silently copies.** In Git Bash,
`ln -s AGENTS.md CLAUDE.md` exits 0 and leaves you a *second regular file*.
Editing `AGENTS.md` afterwards changes nothing in `CLAUDE.md`, which is the
drift the symlink existed to prevent, arriving quietly. Either accept two files
and edit both, or ask for a real symlink with
`MSYS=winsymlinks:nativestrict ln -s AGENTS.md CLAUDE.md`, which needs Developer
Mode or an elevated shell.

**A committed symlink checks out as a text file.** Git for Windows defaults to
`core.symlinks=false`, so `CLAUDE.md` stored in the repository as a symlink
arrives as a 9-byte file containing the string `AGENTS.md` — and an agent
reading it finds that instead of your instructions. This is the one trap that
hits people who are not on Windows themselves: **if anyone on the paper uses
Windows, commit two real files.** `core.symlinks=true` can be set per clone, but
it is not something you can impose on a co-author from inside the repo, and
`.gitattributes` cannot override it either.

**Line endings.** Git for Windows ships `core.autocrlf=true` in its system
config, and Overleaf stores LF. Set `git config core.autocrlf input` in the
paper repo, or a co-author gets a diff touching every line of a file you changed
one word in.

## Two things that are not about papers

Both cost time on the test VM and are worth knowing if you automate any of this:

- A Tailscale client on Windows does not reconnect after a reboot until someone
  logs in. `tailscale up --unattended` fixes it.
- `docker-credential-desktop` does not work in a non-interactive SSH session, so
  `docker pull` from one fails on credential lookup. Run it from a logged-in
  session, or remove `credsStore` from `%USERPROFILE%\.docker\config.json`.
