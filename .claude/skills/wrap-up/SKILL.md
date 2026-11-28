---
name: wrap-up
description: Finish a Mutter feature. Runs the full checks, looks at the result in the browser, updates the repo docs and the running docs, and prepares (or makes, if asked) the commit. Use when a feature is built, or when the user says to wrap up, document, or commit.
---

# Wrap up a feature

Do these in order. Report honestly at each step; a failure is reported with its output, never glossed over.

1. **Checks.** `wsl.exe -e bash -lc 'cd ~/apps/mutter && bin/check'`. Fix failures. If you added Tailwind classes, run `bin/rails tailwindcss:build` first. If you added a migration, confirm `db/schema.rb` was rubocop-normalised.
2. **Look at it.** For anything with a screen: start a throwaway server on :3001 (see `CLAUDE.md`), sign in with a temporary admin if needed, check desktop, tablet (768) and phone (375) widths, and the unhappy paths (bad input, empty states, a visitor who is not allowed). Use `get_page_text` / `read_page` rather than screenshots when you only need text. Then **delete everything you created** in the dev DB and stop the server.
3. **Repo docs.**
   - `docs/ARCHITECTURE.md`: edit the paragraph for each area the feature touched (rules, files, how to extend).
   - `docs/ROADMAP.md`: tick or move the item to **Done** with the commit hash once known; add follow-ups the feature turned up.
   - `CLAUDE.md`: add a convention only if you learned something that cost time and will recur.
4. **Running docs** in `C:\Users\matta\OneDrive\Documents\Claude\Projects\Mutter project\`. Append a dated section to each, at the bottom; read only the last ~15 lines first to match the style.
   - `Task Tracking.md`: what was asked, what was done, what was not.
   - `Log.md`: test results (example count, failures), bugs found and how they were fixed, and **Not verified** items.
   - `Feature documentation.md`: what the feature is, how to use it, limits, how to extend it, location of the code.
   Keep each entry to what is not already obvious from the code and from `docs/ARCHITECTURE.md`.
5. **Refresh the mirror.** `wsl.exe -e bash -lc 'cd ~/apps/mutter && bin/mirror-docs'` copies `CLAUDE.md`, `docs/` and the skills to the OneDrive folder shared with the other computer. Do this after the repo docs are final, and again after any later doc change. Never edit files in the mirror.
6. **Summarise for the user:** what now works, how it was verified, what was not verified, and any decision that was theirs.
7. **Commit only if asked.** On `dev`. Imperative subject, body with what and why. **No `Co-Authored-By` line and no "Generated with Claude" line.** Do not push. Check `git status --short` is clean afterwards, and that no `.env*`, `master.key` or `settings.local.json` was staged.
