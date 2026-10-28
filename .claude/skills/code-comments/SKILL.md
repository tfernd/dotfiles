---
name: code-comments
description: Decide whether a code comment is worth keeping. Use whenever you write, edit or review code that adds, changes or keeps a comment in this repo (zsh, bash, config, tests). A comment stays only if the next Claude would otherwise spend several tool calls working out the same fact.
---

# Code comments

## The test

After every code comment you write, ask yourself: "Is this information the next Claude would spend multiple tool calls trying to understand?" If the answer isn't clearly yes, the comment is noise. Delete it.

Run the test on each comment right after you write it, and again on every comment you touch or meet in a diff you review.

## Keep (clearly yes)

A comment keeps a fact the code cannot show and a reader cannot find by reading the next few lines:

- Why a non-obvious choice was made, when the obvious one was tried and broke (`(( n += 1 ))`: `n++` returns status 1 while `n` is 0).
- A hidden constraint or order: what must load first, or which file must stay in sync with this one.
- A trap in the platform or tool: a zsh, bash, git or Homebrew quirk, with the symptom.
- A limit of the design that a reader would otherwise "fix".

## Delete

- It restates the code (`# loop over the files`, `# set the flag`).
- It repeats what the function or variable name already says.
- It narrates the change (`# fixed`, `# new`, `# now uses X`, `# added after review`): that belongs in the commit message.
- It points at a task, ticket, agent or session: it will rot.
- The reader finds the fact with one grep or one file read.
- It is commented-out code.
- It repeats a rule already written in AGENTS.md.

## Repo conventions that stay

- Section banners (`# ====` plus `# --- Name ---`) are the existing style (AGENTS.md §5). Keep them; add no narration under them.
- Match the comment density of the surrounding file. In a file with few comments, a new one has to pass the test clearly.

## How to apply

- Write the code first. Add a comment only when you can name the fact it protects.
- Prefer a clearer name or a smaller function to a comment.
- Keep a comment that stays to one or two lines about why, not what.
- In a review, list each comment that fails the test with `path:line`. Delete it; do not reword it.
- When unsure, delete. A reader can rediscover a fact; noise costs every reader.
