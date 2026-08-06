# Working with an agent

Agents do not need an MCP server or a custom tool for any of this — it is
`docker run` and `git`, both of which any coding agent runs through its shell.
What they need is for the commands to be written down in the repository they are
working in. That is what [`AGENTS.snippet.md`](../AGENTS.snippet.md) is:

```bash
cp AGENTS.snippet.md /path/to/paper/AGENTS.md      # Codex, Gemini CLI, most others
ln -s AGENTS.md /path/to/paper/CLAUDE.md           # Claude Code — or copy it twice
```

Substitute `<PROJECT_ID>` in the copy and delete whatever does not apply.

A symlink keeps the two from drifting apart, and is the right answer when
everyone on the paper is on Linux or macOS. **If anyone is on Windows, commit
two real files instead** — see [windows.md](windows.md#four-traps).

## Keep the link back to here

The snippet's first line links to this repository. Leave it in the copy that
ends up in your paper. Months later, when the image is missing a package or the
TeX Live year has moved on, that line is what tells whoever is looking — a
co-author, a fresh agent, you — where these instructions came from and where a
fix belongs. A paper repo with a bare `docker run ghcr.io/...` in it and no
explanation is a small mystery you will have to solve twice.

## Give it the rest of the project

The single highest-value thing on this page, and
[tips.md](tips.md#give-the-agent-your-context) argues the case at length. The paper repository has to stay exactly what
Overleaf sees, so your analysis code does not belong in it. Put it next door and
start the agent one level up:

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

## Prompts worth stealing

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

## The Claude Code skill

[`skills/overleaf-paper/`](../skills/overleaf-paper/SKILL.md) is an optional
convenience layer over the same commands — copy the directory to
`~/.claude/skills/overleaf-paper/` and Claude Code loads it whenever you ask it
to build the paper, pull from Overleaf or push. It carries the compile command,
how to read a failure, the sync rules and the latexdiff recipe, so you get them
in a fresh session without an `AGENTS.md` in front of it. It is not a separate
mechanism and it does not replace `AGENTS.md` in the paper repo.

## Two habits that make an agent much more useful

One sentence per line in the `.tex`, and `*.tex diff=tex` in `.gitattributes`.
Both are about the diff: the first makes an agent's edits reviewable one
sentence at a time instead of as a repainted paragraph, the second tells git to
label each hunk with the section it is in. [tips.md](tips.md) has these and the
rest of the practical advice — comments, notes, review rounds, git habits.
