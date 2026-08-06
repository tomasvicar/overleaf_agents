# Comments, review and change tracking

The git bridge moves **files**. That is worth saying out loud, because two of
the things people rely on in Overleaf are not files:

- **Comment threads** and **track changes** live in Overleaf's database. Clone
  the project and they are not in it. An agent working in the clone cannot read
  a reviewer's comment, and nothing it commits can answer one.
- **Overleaf's own history** is not the git history either. The two run
  alongside each other and neither summarises the other.

So decide once where review happens. If the answer is "in the browser, in
comment threads", that is a legitimate choice — and this workflow is the wrong
tool for that paper.

## Comments that survive the round trip

Put them in the source, where both sides can see them:

| Form | What it gets you |
|---|---|
| `% an ordinary TeX comment` | Invisible in the PDF. Fine for a note to whoever edits the source next, useless to a co-author who only reads the PDF. |
| `\todo{is this the Aug run?}` (`todonotes`) | Renders in the margin of the compiled PDF, so a browser-only co-author sees it on Overleaf without doing anything. |
| `\added{}`, `\deleted{}`, `\replaced{}` (`changes`) | Marks up who changed what, in the PDF, and `\listofchanges` collects them. The closest thing to track changes that is made of text. |

Both packages are in the image, and neither has to be stripped before
submission — the markup switches off where the package is loaded, without
deleting any of it. Watch the options, because they do not match: `changes`
hides on `[final]`, but `todonotes` needs **`[final,obeyFinal]`**. `[final]`
alone is silently a no-op there, which is a tidy way to submit a manuscript with
your own margin notes still in it.

One collision, since both packages are in the image: `tcolorbox` defines
`\comment` and so does `changes`, so loading both is an error.
`\usepackage[commandnameprefix=ifneeded]{changes}` renames only the commands
that actually clash and leaves `\added` and `\deleted` alone.

One thing to ask of co-authors: if they edit in the browser with track changes
on, have them accept or reject before you pull. What the bridge hands you is the
document text — "this part is a pending tracked change" is not something a git
commit can carry.

## The git history *is* the change tracking

`git log`, `git show` and `git diff` are the record, and in the ways that matter
they beat Overleaf's history: they have messages, they are per-change rather
than per-keystroke, and an agent can read them. Ask *what changed in section 4
since Monday* and it answers from `git log`.

For co-authors who want to *see* the changes, hand them a marked-up PDF.
`latexdiff` is in the image:

```bash
git show HEAD~5:main.tex > old.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest latexdiff old.tex main.tex > diff.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:latest diff.tex
```

`diff.pdf` comes out with additions underlined and deletions struck through. Any
two revisions work — five commits back, a tag, the commit you last sent someone.
Attaching that to "I revised the discussion" is a better review round than a
comment thread, and an agent can produce it on request. Delete `old.tex`,
`diff.tex` and `diff.pdf` afterwards; they are not part of the manuscript.

Two more tools in the image for the same reason: `texcount -1 -sum main.tex`
when the journal has a word limit, and `chktex` for linting.

## Does GitHub issues make sense?

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
