---
name: feature
description: Start a new Mutter feature or improvement. Loads only the context needed, turns the request into a short plan with specs first, and picks work from the roadmap. Use when the user describes something to build or says "next feature".
---

# Start a feature

1. **Orient (cheaply).** `CLAUDE.md` is already loaded. Read the section of `docs/ARCHITECTURE.md` for the area you will touch, and the matching items in `docs/ROADMAP.md`. If the user gave no feature, offer the top two or three roadmap items with a one-line recommendation. Do not read the large running docs in the OneDrive folder; grep their headings if you need history.
2. **Check the tree.** `git status --short` and `git log --oneline -3` (via `wsl.exe -e bash -lc 'cd ~/apps/mutter && …'`). Work on `dev`. If there are uncommitted changes you did not make, say so before touching anything.
3. **Restate the goal** in two or three lines: what the user will be able to do, and what is out of scope. Ask a question only when the answer changes what you build and cannot be decided from the codebase or a sensible default; otherwise pick the default and say so.
4. **Find the seams.** Search for the nearest existing feature that works the same way (for example a new admin screen follows `Admin::SettingsController`; a new block kind follows `PageBlock`) and copy its shape, its specs and its authorization row.
5. **Specs first.** Write the failing model and request specs, run them, and watch them fail for the right reason. Then build until they pass.
6. **Keep it small.** One feature per commit-sized change. If a second, independent idea turns up, add it to `docs/ROADMAP.md` instead of building it.
7. When the work passes `bin/check`, run `/wrap-up`.
