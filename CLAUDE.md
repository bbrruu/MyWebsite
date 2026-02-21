# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev       # Start dev server at localhost:4321
npm run build     # Build production site to ./dist/
npm run preview   # Preview production build locally
```

## Architecture

This is an **Astro 5 static site** — a personal portfolio for Bruce Tseng (曾冠瑜), a computational linguistics graduate student at NTU. No React/Vue/Svelte — only `.astro` components.

### Routing

File-based routing under `src/pages/`. Four main content sections, each with a list index and dynamic `[id].astro` detail page:


- `/` → `src/pages/index.astro` — homepage grid showing latest from all collections
- `/about` → bilingual (CN/EN) profile page with a language toggle button
- `/blog/[id]`, `/research/[id]`, `/reading/[id]`, `/music/[id]` — dynamic routes using `getStaticPaths()`

### Content Collections

All content lives in `src/content/` as Markdown files with YAML frontmatter. Schemas are defined in `src/content/config.ts` using Zod. Fetch with `getCollection('blog')` etc. from `astro:content`.

Each collection has its own frontmatter schema:
- **blog**: mood, category, location, tech stack
- **research**: status, field, abstract, PDF links
- **reading**: book ratings
- **music**: artist, song name, YouTube links, lyrics

### Layout & Styling

- `src/layouts/Layout.astro` — global wrapper with `<ClientRouter />` for page transitions, navbar, and CSS variables
- `src/components/navbar.astro` — nav with live clock and language toggle (visible only on `/about`)
- Styles use scoped `<style>` blocks in each `.astro` file; global styles use `is:global`
- CSS variables for theming: `--ink`, `--paper`, `--accent`, `--muted`, `--border`
- Paper/ink warm aesthetic; breakpoints at 768px and 850px

### Interactivity Pattern

Since there is no JS framework, client-side logic is handled by inline `<script>` tags. Scripts that need to re-run after page transitions (Astro View Transitions) must listen for the `astro:page-load` event rather than `DOMContentLoaded`.

### Language Support

The `/about` page supports bilingual (Traditional Chinese / English) content via `data-lang` attributes on elements. The language toggle in the navbar switches a `data-lang` attribute on `<body>`, and CSS hides/shows the corresponding content.
