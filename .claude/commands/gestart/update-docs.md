---
description: Update project documentation and TODOs with relevant knowledge from the current session
---

# /gestart:update-docs

Update the project's persistent documentation using the relevant knowledge gathered during the current session.

## Scope

**Primary target:** `.claude/docs/` — its decision documents and `todo.md`.

**Also editable, for two reasons only:**

- `CLAUDE.md`, `README.md` and `.claude/skills/` **when the session made a claim in them false.** These sit outside `.claude/docs/` and carry live, frequently-read guidance, so a stale sentence there does more damage than one in a decision doc.
- `CLAUDE.md` and `.claude/docs/README.md` **when a new document needs indexing.** Both hold a table of the decision documents; a new file that neither points at is a file nobody will find.

**Never edited:** `.claude/docs/plans/`. See the rule under step 4.

Do not touch application code, specs, or configuration. This command documents what happened; it does not change what happens.

## Instructions

1. **Before performing any modification, read `.claude/docs/README.md`.**

   - This step is mandatory and must always be performed first.
   - Use the instructions, structure, conventions, and documentation rules defined in `.claude/docs/README.md` as the source of truth for how `.claude/docs/` should be maintained.
   - Do not modify any documentation or TODO file before reading and understanding this file.
   - If `.claude/docs/README.md` defines specific locations, naming conventions, formats, or workflows, follow them throughout the entire update process.

2. Analyze the current session and identify information that is genuinely useful to preserve for future sessions, including when relevant:

   - architectural decisions;
   - project conventions;
   - important technical choices;
   - agreed patterns and approaches;
   - relevant constraints or requirements;
   - solved problems and reusable solutions;
   - important changes to the project's current state.

3. Read the relevant existing files inside `.claude/docs/` before making changes to them.

4. Integrate the new information into the appropriate existing documentation files.

   - Follow the rules defined in `.claude/docs/README.md`.
   - Preserve the current structure and conventions.
   - Avoid duplicate information.
   - Prefer updating an existing section over creating redundant documentation.
   - Replace or remove outdated information when a previous decision has been superseded — **except in `plans/`, which is never edited.** A plan records what was intended going into a branch, not what came out of it, and editing one to match what happened turns a record into a fiction. When a plan and a decision document disagree, correct the decision document and leave the plan alone.
   - Keep documentation concise, factual, and easy to scan.
   - Do not store temporary implementation details unless they are important for future work.
   - Do not store verbatim conversation history.
   - **Verify every technical claim against the code before writing it**, and write only what you verified. "The spec rebuilds the bundle", "the component emits X", "two suites cover this" are all checkable in seconds and all have been wrong here. A sentence you cannot check is a sentence to cut, not to hedge.
   - **Before finishing, search for what the session made false, and fix it.** `grep` the names of everything renamed, moved or deleted across `.claude/`, `CLAUDE.md` and `README.md`, then read every hit and correct the ones that now describe behaviour that no longer exists. Leave historical records alone — a past-tense account of a fixed bug is not stale. This is the most common defect in this repo, and it is invisible from the diff you just wrote, which is why it needs its own pass.

5. Create a new file inside `.claude/docs/` only when the information does not logically belong in an existing document and when doing so is consistent with `.claude/docs/README.md`.

   - **Never create anything in `plans/`.** A plan is written before a branch, from a spec, by the planning workflow — not assembled afterwards from what happened.
   - **Index a new document in both places or it does not exist.** `.claude/docs/README.md` holds the table of documents and `CLAUDE.md` holds the Background list; a file in neither is a file the next session will not open. Follow the numbering and description style already in each.

6. Review the project's existing TODOs and update them when necessary.

   - Add actionable TODOs discovered during the session.
   - Update TODOs whose scope or requirements changed.
   - Mark completed TODOs as done or remove them according to the project's existing convention.
   - Remove obsolete TODOs when appropriate.
   - Avoid duplicate TODOs.
   - Do not create TODOs for work that has already been completed.

7. Make the required file changes directly. Do not only describe or suggest them.

8. Do not modify documentation or TODOs when there is no meaningful new information to persist.

## Final response

After completing the update, provide a concise summary containing:

- files created or updated;
- decisions recorded, revised, or superseded — and, where one supersedes another, which document now disagrees with which plan;
- claims corrected because the session made them false, and where they were found;
- TODO entries added, updated, closed, or removed;
- anything deliberately **not** recorded, and why — a judgement to leave something out is worth more to the next session than silence about it;
- whether no changes were necessary.

## Guiding principle

Always treat `.claude/docs/README.md` as the entry point and source of truth for maintaining project documentation.

Persist only information that will concretely help Claude understand the project, preserve important decisions, avoid repeating previous investigation, and make better decisions in future sessions.
