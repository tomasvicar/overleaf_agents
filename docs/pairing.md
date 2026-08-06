# Pairing a repository with Overleaf

The [README](../README.md) has the three-command version. This file has the
cases it leaves out.

## The token and the project ID

**Token:** <https://www.overleaf.com/user/settings> → **Git integration** →
**Generate token**. Copy it immediately; Overleaf will not show it again. It is
the only thing accepted as the password on the git remote — your Overleaf
account password is not. It can be revoked from the same page at any time.

**Project ID:** the hex string in the project URL,
`overleaf.com/project/<PROJECT_ID>`. Overleaf will also spell out the whole
clone command: open the project and choose **Git** under the **Integrations**
button in the left sidebar (older interface: **Menu → Git**).

> Overleaf's git integration is a **paid-plan feature** (Overleaf Cloud
> Standard/Professional, or Server Pro). Without it there is no git remote and
> this workflow does not apply. Overleaf's own page on it:
> <https://www.overleaf.com/learn/how-to/Git_integration>

Neither value should go to an agent. Pairing is four commands you run once; an
agent cannot fetch either value for you, and there is nothing it can do with
them that you cannot do faster yourself.

## Cloning into an empty directory

```bash
git clone https://git@git.overleaf.com/<PROJECT_ID> my-paper
cd my-paper
git remote rename origin overleaf
```

Git asks for a password — paste the token.

Renaming the remote to `overleaf` immediately is worth the extra line: it keeps
one name for the Overleaf side whether or not you ever add GitHub, so every
instruction in this repo — and every instruction an agent gets — reads the same
in both setups.

To avoid retyping the token, put it in the remote URL:

```bash
git remote set-url overleaf https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID>
```

That writes the token to `.git/config` in the clear. It is a revocable token
scoped to your Overleaf account, not a password — but if you would rather it not
sit on disk, leave the URL without it and let git prompt, or use a credential
helper.

## Attaching to a directory that already has files

`git clone` refuses a non-empty directory, which is what you hit if you put an
`AGENTS.md` or a `.gitignore` there first. Attach the remote to what is already
there:

```bash
git init -b main
git remote add overleaf https://git:<TOKEN>@git.overleaf.com/<PROJECT_ID>
git fetch overleaf
git branch -f main overleaf/main
git symbolic-ref HEAD refs/heads/main
git reset --hard main                        # see the warning below
git branch --set-upstream-to=overleaf/main main
```

`git reset --hard` leaves untracked files alone **unless** the Overleaf project
has a file of the same name, which it silently overwrites. Copy anything you
care about aside first.

Older Overleaf projects use `master` rather than `main`. `git branch -r` after
the fetch tells you which, and every `main` above becomes `master`.

## Adding GitHub as a second remote

Overleaf alone is a complete setup. Skip this if that is what you want —
`overleaf` as the only remote works everywhere in this repo.

GitHub buys you history browsing, branches, pull requests and CI, none of which
the Overleaf git bridge has. The cost is one extra push per change.

```bash
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

Keep the paper repo **private** if it carries anything unpublished. Note also
that `AGENTS.md` contains your project ID once you substitute it in. That is not
access on its own — without the token it opens nothing — but it is a reason not
to make the repo public without thinking about it.

## Keeping aux files out of git

Overleaf will happily sync `.aux` and `.fls` files into the project, and they
cause pointless merge conflicts. In `.gitignore`:

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

The last line is the PDF the image writes to the repo root. Overleaf compiles
its own copy, so committing yours produces a binary conflict on every build.
Keep it out unless you specifically want the PDF browsable on GitHub — and note
that `*.pdf` would be wrong, since figures are often PDFs.

## Pushing

Overleaf **forbids force pushes**. Treat local `main` as the source of truth and
push fast-forwards only.

```bash
git add -A
git commit -m "..."
git pull overleaf main --no-rebase   # only if the push below is rejected
git push overleaf main
git push origin main                 # only if you added the GitHub remote
```

A rejected push means someone edited the project in the browser. Pull with
`--no-rebase`, resolve the conflict in the `.tex` source, push again. Never
rebase over Overleaf's commits.

`git config pull.rebase false` in the paper repo makes the safe behaviour the
default for everyone and everything working in that clone, agents included.
