# Diary Entry Skill

The user wants to add a diary entry to their Astro website. Follow this procedure exactly.

## Step 1 — Detect the date

- Today's date is always available in the system context (`# currentDate`). Use it.
- If the user mentions a past date explicitly (e.g. "這是昨天的" / "補寫4月10日"), use that date instead.
- Filename format: `YYYYMMDD` → file path: `src/content/blog/YYYYMMDD.md`

## Step 2 — Check if the file already exists

- If `src/content/blog/YYYYMMDD.md` exists → **append** a new `###` section at the end.
- If it doesn't exist → **create** a new file with full frontmatter.

## Step 3 — Infer all metadata from the content

Never ask the user to fill in metadata. Infer everything:

| Field | Rule |
|-------|------|
| `title` | Short summary of the entry (≤15 characters), in Chinese |
| `pubDate` | Today's date (YYYY-MM-DD) |
| `mood` | Infer from tone and content (free text, e.g. '開心', 'Quite Good', '疲憊') |
| `category` | `旅行` / `日常` / `省思` — pick the best fit |
| `tags` | Extract 3–5 keywords from the content as a list |
| `quote` | Pick the most memorable or resonant sentence from the entry |
| `techStack` | `[]` unless the user mentions tech they worked on |
| `status` | Always `Stable` unless the user says otherwise |
| `location` | **Omit entirely** unless the user explicitly mentions a location |

## Step 4 — Format the body

**CRITICAL: Never change a single character of the user's diary text. No rewording, no fixing typos, no rephrasing — not even one word. The user's writing must be preserved exactly as written.**

You may only:
- Add `###` section headers above paragraphs
- Add `<br/>` for line breaks within paragraphs (matches site style)
- Add `---` horizontal rule between sections if there are multiple parts

## Step 5 — Handle photos

If the user sends a photo:
- Decide where it fits best in the entry
- Choose a filename: `YYYYMMDD-short-description.jpg`
- Write the image tag: `![caption](/images/filename.jpg)` followed by `*caption*` on the next line
- Caption should be one evocative sentence related to the photo and surrounding text
- Remind the user once at the end to place the file at `public/images/filename.jpg`

## Step 6 — Show the formatted entry to the user

Display the full formatted markdown so the user can review it before anything is committed.

## Step 7 — Write the file

- Write or update `src/content/blog/YYYYMMDD.md`
- Commit with message: `Add/Update diary entry YYYY-MM-DD: <title>`
- Push to the current branch
- If the user approves and asks for a PR, create one — otherwise do not

## Frontmatter template (new file)

```markdown
---
title: <title>
pubDate: YYYY-MM-DD
mood: '<mood>'
category: '<category>'
tags: [<tags>]
quote: '<quote>'
techStack: []
status: 'Stable'
---
```

## Trigger keywords

This skill should activate when the user:
- Uses `/diary`
- Pastes a block of personal narrative text (diary-like content)
- Says things like: 寫日記、日記、今天、今天發生、補寫
