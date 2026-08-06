# Tips: comments, notes, and writing a paper in git

Practical advice for the part that is not `docker run` — how to give an agent
something to write from, how to leave comments when Overleaf's comments do not
reach you, how to keep the source diffable, and the small habits that make a
co-authored paper in git behave.

## Give the agent your context

If you take one tip from this page, take this one. What an agent produces is
bounded by what it can read, far more than by how you phrase the request. An
agent with only `main.tex` in front of it can reword your sentences. An agent
that can also read the script that made Figure 3, the CSV behind Table 2 and
last week's lab notes can tell you that the number in your abstract is not the
number the script printed — and that is a different tool.

So put the material where it can reach it, next to the paper rather than inside
it, and start the agent one level up:

```
project/
  paper/      <- the Overleaf clone; the only thing that gets pushed
  analysis/   <- the code that produced the numbers, and its outputs
  notes/      <- lab notes, meeting minutes, reviewer emails, the grant text
  refs/       <- the journal's author guidelines, papers you are answering to
```

Start the agent in `project/`. It reads all four directories and still only ever
commits inside `paper/`.

Worth having there, roughly in order of how often it earns its place:

- **Results as data, not as prose** — the CSV, the JSON, the summary table the
  script writes. "Every number must come from `results/summary.csv`" is an
  instruction an agent can actually follow, and one you can check.
- **The analysis code itself.** It answers *what does this column mean*, *was
  this the corrected run*, *what n does this reflect* without you in the loop.
- **Reviewer comments and your previous responses**, so a revision round starts
  from the record rather than from your memory of it.
- **The journal's guidelines** — word limits, section structure, reference
  style. An agent that has read them stops proposing a discussion twice the
  allowed length.
- **Notes and meeting minutes**, including the messy ones. This is where the
  reasons live, and reasons are what prose needs.

**Why beside the repo and not in it.** Everything committed inside `paper/`
syncs to Overleaf and appears in every co-author's browser — draft notes,
unpublished data, the paragraph about the reviewer you found unhelpful. Keeping
them next door means the agent sees them and Overleaf never does. If you really
want them in one tree, `.gitignore` them and know what you are relying on: one
stale ignore rule plus a `git add -A` puts your lab notebook in front of the
whole author list.

[working-with-agents.md](working-with-agents.md) has the prompts that use this
layout, and the rest of the agent-specific advice.

## Comments and notes do not survive the git bridge

The bridge moves **files**. Two of the things people rely on in Overleaf are not
files:

- **Comment threads** and **track changes** live in Overleaf's database. Clone
  the project and they are not in it. An agent working in the clone cannot read
  a reviewer's comment, and nothing it commits can answer one.
- **Overleaf's own history** is not the git history either. The two run
  alongside each other and neither summarises the other.

So decide once where review happens. If the answer is "in the browser, in
comment threads", that is a legitimate choice — and this workflow is the wrong
tool for that paper.

### Put comments in the source instead

| Form | What it gets you |
|---|---|
| `% an ordinary TeX comment` | Invisible in the PDF. Fine for a note to whoever edits the source next, useless to a co-author who only reads the PDF. |
| `\todo{is this the Aug run?}` (`todonotes`) | Renders in the margin of the compiled PDF, so a browser-only co-author sees it on Overleaf without doing anything. |
| `\added{}`, `\deleted{}`, `\replaced{}` (`changes`) | Marks up who changed what, in the PDF, and `\listofchanges` collects them. The closest thing to track changes that is made of text. |

Both packages are in the image, and neither has to be stripped before
submission — the markup switches off where the package is loaded, without
deleting any of it.

Two traps, both found the hard way:

- **The options do not match.** `changes` hides on `[final]`, but `todonotes`
  needs **`[final,obeyFinal]`**. `[final]` alone is silently a no-op there,
  which is a tidy way to submit a manuscript with your own margin notes still
  in it.
- **`tcolorbox` and `changes` both define `\comment`**, so loading both is an
  error. `\usepackage[commandnameprefix=ifneeded]{changes}` renames only the
  commands that actually clash and leaves `\added` and `\deleted` alone.

Give your notes a prefix you can grep: `\todo{R2.3: reviewer wants the CI here}`,
`\todo{TV: check against the July run}`. `grep -n '\\todo' *.tex` before
submission is then the checklist, and an agent asked to "resolve the open todos"
has something unambiguous to work from.

### Tag co-authors in the margin, not in email

`\todo[inline]{@Jana: is Fig. 3 the corrected version?}` renders in the body
where it cannot be missed, and it stays with the sentence it is about. Ask
co-authors to answer by editing the note rather than deleting it — the thread is
then in the file, and the whole exchange arrives with the next pull.

### One thing to ask of co-authors

If they edit in the browser with track changes on, have them **accept or reject
before you pull**. What the bridge hands you is the document text; "this part is
a pending tracked change" is not something a git commit can carry.

## Show what changed

`git log`, `git show` and `git diff` are the change record, and in the ways that
matter they beat Overleaf's history: they have messages, they are per-change
rather than per-keystroke, and an agent can read them. Ask *what changed in
section 4 since Monday* and it answers from `git log`.

For co-authors who want to *see* the changes, hand them a marked-up PDF.
`latexdiff` is in the image:

```bash
git show HEAD~5:main.tex > old.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025 latexdiff old.tex main.tex > diff.tex
docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
  ghcr.io/tomasvicar/latex-overleaf:TL2025 diff.tex
```

`diff.pdf` comes out with additions underlined and deletions struck through. Any
two revisions work. Attaching that to "I revised the discussion" is a better
review round than a comment thread, and an agent can produce it on request.
Delete `old.tex`, `diff.tex` and `diff.pdf` afterwards; they are not part of the
manuscript.

**Tag what you send out**: `git tag submitted-2026-08` before every submission
or circulated draft. Then the diff a co-author actually wants is
`git show submitted-2026-08:main.tex` — "since the version you read", rather
than an arbitrary number of commits back.

Two more tools in the image for the same reason: `texcount -1 -sum main.tex`
when the journal has a word limit, and `chktex` for linting.

## Write the source so git can read it

**One sentence per line.** This is the single highest-value habit in the list.
A paragraph on one long line makes every diff a wall of red and green, and every
concurrent edit a conflict on the whole paragraph. Break after each sentence —
LaTeX ignores single newlines, so the PDF is identical:

```latex
The membrane depolarised within \SI{40}{\milli\second}.
Amplitude scaled with stimulus intensity (\cref{fig:amp}).
We did not observe adaptation over the recording window.
```

Now `git diff` shows the one sentence that changed, a merge with an Overleaf
edit resolves per sentence instead of per paragraph, and an agent asked to
proofread produces a diff you can actually read. Breaking at clause boundaries
inside a very long sentence is fine too.

**`echo '*.tex diff=tex' >> .gitattributes`.** Git then labels each diff hunk
with the section it is in, which improves both `git diff` and the agent's
reading of it.

**Make generated tables genuinely generated.** Have the analysis script write
`tables/results.tex` and `\input{}` it, so a rerun updates the manuscript
instead of starting an argument about which number is current. Same for numbers
in the text: `\newcommand{\nSubjects}{42}` in one place beats forty-two written
out in six.

**Split long manuscripts** into `sections/*.tex` and `\input{}` them. Conflicts
then land in one section rather than in `main.tex`, and you can hand an agent
"rewrite `sections/discussion.tex`" without it having the whole paper in scope.
`subfiles` is in the image if you want each part to compile on its own.

## Git habits that fit Overleaf

- **`git config pull.rebase false`** in the paper repo. Overleaf's commits must
  never be rebased, and this makes the safe behaviour the default for everything
  working in that clone, agents included.
- **Pull before you start**, not just when a push is rejected. Someone typing in
  the browser for ten minutes is ten minutes of conflict you avoid by spending
  one second on `git pull overleaf main --no-rebase`.
- **A `pre-push` hook that compiles first.** Two lines in
  `.git/hooks/pre-push`, and it removes the only really embarrassing failure
  mode — a broken build visible to every co-author:

  ```bash
  #!/bin/sh
  docker run --rm -v "$PWD:/work" -u "$(id -u):$(id -g)" \
    ghcr.io/tomasvicar/latex-overleaf:TL2025 || exit 1
  ```

  `chmod +x` it. Hooks are per-clone and not committed, so tell co-authors
  rather than assuming they have it.
- **Commit messages in the imperative, one change each.** They are the change
  log you will be reading back to co-authors, and the thing an agent summarises
  when you ask what happened last week.
- **Never commit `main.pdf`.** Overleaf builds its own, so a committed PDF is a
  binary conflict on every build. `/main.pdf` in `.gitignore`, not `*.pdf` —
  figures are often PDFs.
- **Keep the repo private if the paper is unpublished**, and remember that
  `AGENTS.md` carries your Overleaf project ID once you substitute it in. Not
  access on its own, but not something to publish without meaning to.

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

## Things that will bite you once

- **Never edit `*.cls` or `*.bst`.** They are the journal's, and the journal
  uses its own copies anyway. A fix that lives in the class file is a fix that
  vanishes at submission.
- **Match the TeX Live year.** The image tag should match **Menu → Settings →
  TeX Live version** in the project. That parity is the entire reason a local
  compile means anything.
- **A compile that times out on Overleaf still builds locally**, with no time
  limit — which makes the container the way out of "the project no longer
  compiles in the browser", not just a convenience.
- **Line endings and symlinks on Windows** — see [windows.md](windows.md#four-traps).
  The symlink one bites people who are not on Windows themselves.
