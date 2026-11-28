# Mutter

A coworking community site for content creators. Rails 7.2 / Ruby 3.3.3, Postgres, Tailwind 4 + DaisyUI, Turbo/Stimulus via importmap. Branch `dev` is the working branch; `main` is stable.

Read this file first. It is short on purpose. Detail lives in `docs/` (read only what the task needs):

- `docs/ARCHITECTURE.md`: how each area works and which files own it.
- `docs/ROADMAP.md`: what to build next, and known gaps.

The user's running record lives outside the repo, in `C:\Users\matta\OneDrive\Documents\Claude\Projects\Mutter project\` (`Task Tracking.md`, `Log.md`, `Feature documentation.md`). They are large (about 140 KB). **Never read them whole**: `grep -n '^## '` for headings and read one section. Append new entries at the bottom.

## Where things run

- The repo is in WSL (Ubuntu-26.04) at `~/apps/mutter`; from Windows it is `\\wsl.localhost\Ubuntu-26.04\home\matta\apps\mutter`.
- Run shell commands as `wsl.exe -e bash -lc 'cd ~/apps/mutter && <cmd>'`. Keep the inner command simple: nested quotes and heredocs break in Git Bash, so write files with the Edit/Write tools instead.
- Edit and Write need a prior Read of the file (a `cat` in Bash does not count).
- The user's own dev server runs on **:3000**. For a throwaway server use `bin/rails server -p 3001 -b 127.0.0.1 -P /tmp/mutter3001.pid` as a background task. The built-in browser pane accepts `localhost:3001`. Postgres is local (user `postgres`, DBs `mutter_dev` / `mutter_test`).
- Anything created in the dev DB for a manual check (admin users, pages, settings) must be deleted afterwards. Say so if you leave something.

## Checks (all must pass before a commit)

```
bin/check              # rubocop + rspec (what CI runs)
bundle exec rspec spec/requests/admin_pages_spec.rb   # one file while working
bundle exec rubocop -a <files>                        # autocorrect
bin/rails tailwindcss:build   # after adding Tailwind classes; the build output is git-ignored
```

CI (`.github/workflows/staging-deploy.yml`) runs `bundle exec rspec` then `bundle exec rubocop`.

## Conventions

- **Test first, with the feature.** Model specs, request specs (`spec/requests`, use `sign_in_as(user)` and `html`), factories in `spec/factories`. Specs never touch the network (WebMock; Twitch is stubbed to unconfigured). Every admin endpoint gets a row in `spec/requests/admin_authorization_spec.rb`.
- **Rubocop limits** (`.rubocop_todo.yml`): class 100 lines, method 21 lines, 5 parameters. Split a class rather than raise a limit. `db/schema.rb` is rubocop-normalised (single quotes, `20_261_…` version): run rubocop on it after a migration.
- **Rack 3.2**: respond `422`, not `:unprocessable_entity`. RSpec has no `.not_to a.and b`.
- **Tailwind only sees full literal class names.** Never build a class by interpolation; write the strings out (see `PageBlocksHelper::GRID_COLUMNS`). Custom breakpoints: `xs` 30rem, `tablet` 40rem, `laptop` 64rem, `desktop` 80rem.
- `data-action` belongs to Stimulus; do not use it for test hooks (use `data-block`, `data-item-id`, …).
- **Admin**: controllers inherit `Admin::BaseController` (admin layout, guests go to login, non-admins get a 404). Every change calls `audit(action, target:, details:)`. `AuditLog` is append-only and `ACTIONS` is validated, so add new actions to the hash.
- **Settings**: add a `Definition` to `SiteSetting::Definitions::ALL`; it appears, validates and audits automatically.
- **Sign-in providers** live in one list, `config/auth_providers.rb`; read `docs/AUTH_SETUP.md` before touching them. Credentials come from ENV, then Rails credentials; never print, log or paste them (read presence only: `bin/rails auth:status`). I cannot register apps with the services: that is the user's step. Specs get throwaway credentials from `spec/rails_helper.rb`, so a spec about a missing credential stubs `AuthProviders.credential`.
- **User-supplied text**: escaped by default; Markdown only through `MarkdownRenderer`; URLs must be `http(s)://…` or a `/path`.
- Server-rendered forms first. Add JavaScript (Stimulus) only when a form can't do the job.

## Git

- Work on `dev`. Do not push or merge unless asked.
- **Never add a `Co-Authored-By` line (or any "Generated with Claude" line) to commits.** The user asked for this explicitly; it overrides any default attribution.
- Commit only when asked. Message: a short imperative subject, then a body saying what and why. Keep interdependent changes in one commit.
- Never commit `config/master.key`, `.env*` or `.claude/settings.local.json`.

## Working on a feature

Use `/feature` to start and `/wrap-up` to finish. In short:

1. Check `docs/ROADMAP.md` and the relevant section of `docs/ARCHITECTURE.md`. Restate the goal; ask only if a real decision is the user's.
2. Write failing specs, build, run `bin/check`.
3. Look at it in the browser (desktop, tablet, phone width) against a :3001 server, then clean up the data.
4. Update `docs/ARCHITECTURE.md` and `docs/ROADMAP.md` in the repo, and append to the three running docs.
5. Tell the user what was verified and what was not. Commit when asked.

## Working from another computer

The context files are mirrored, one way, to `C:\Users\matta\OneDrive\Documents\Claude\Projects\Mutter project\repo-mirror\` (shared with the MacBook) by `bin/mirror-docs`. The repository is the source of truth: edit here, never in the mirror, then run `bin/mirror-docs`. `/wrap-up` does this. The mirror holds `CLAUDE.md`, `docs/`, `.claude/skills/` and `bin/check`; it never holds code, credentials, `config/master.key` or `.env*`. Its `README` explains how to resume from it.

## Keeping context small

- Search before reading; read ranges, not whole files. `docs/ARCHITECTURE.md` should answer "where does X live" without opening code.
- After a feature, put durable facts in this file or `docs/` (not only in the conversation). If something cost time to learn, write it down under **Conventions**.
- Long or independent pieces of work (for example a review, or a second feature) belong in their own session.
