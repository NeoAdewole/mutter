# Roadmap

The one place to find "what next". Move an item to **Done** with its commit when it ships, and add anything new that a feature turns up. Items are small enough to be one session each; the first in each group is the suggested next step.

Sizes: S (an hour or less), M (a session), L (needs a design conversation first).

## Next up

- [ ] **Register the sign-in apps and try each for real** (S, needs the owner). GitHub, Twitter, Google (also YouTube) and Discord have no credentials yet; Twitch does. Follow `docs/AUTH_SETUP.md`, then run `bin/rails auth:status`. Until then each service's flow is verified only up to its login page and against realistic mock responses, never a real sign-in.

- [ ] **Image upload and media library** (L). Replace "image web address" on slides, cards and Markdown with ActiveStorage uploads and a picker. Needs decisions: storage (local, S3), size and type limits, alt text.
- [ ] **Draft state and preview for blocks** (M). Edit a published page's blocks privately, then publish. Today blocks are live as soon as they are saved.
- [ ] **Roles beyond admin** (M). An "editor" who can manage pages but not users or settings.
- [ ] **Redirects when a slug changes** (S). Old addresses should still work.

## Page builder

- [ ] More block kinds: single call-to-action banner, video, list of a section's pages, gallery (S each).
- [ ] A slide that features a page, like a card (S).
- [ ] A card that links to a built-in feature such as Live chat (S).
- [ ] Per-block visibility (members only) (M).
- [ ] Duplicate a block or a page (S).
- [ ] Drag-and-drop ordering (M); revision history and undo for page content (L); scheduled publishing (M).
- [ ] Live Markdown preview in the editor (S).
- [ ] Better excerpt when a page starts with a list (S).
- [ ] Editable section intro text (S).

## Admin

- [ ] Re-ask for the admin's password before granting admin or deleting a user (S).
- [ ] Two-factor sign-in for admins (L).
- [ ] "Sign out everywhere" and a per-user session list (M).
- [ ] Bulk actions and CSV export on the user list (S).
- [ ] Audit-log retention and export (S).
- [ ] Email notices to people who are suspended or whose email an admin changed (S).

## Accounts and streaming

- [ ] Database unique index on `lower(users.username)` (S). Today uniqueness is a validation only, so two sign-ups at the same instant could collide. Check existing data for case-only duplicates first.
- [ ] More chat platforms (YouTube live chat) using the `app/javascript/chat/` pattern (M).
- [ ] YouTube handle for older channels that have none (S).
- [ ] Usernames made from a full name (Google, Discord) can contain spaces, for example "Ada Lovelace". Decide on a format (letters, digits, `_`, `-`) and apply it to new and existing accounts (S).
- [ ] Remove the unused `app/views/profile/index.html.erb` (S).
- [ ] Another way into a passwordless account: sign in by emailed link (M).

## Quality and operations

- [ ] Content-Security-Policy header as defence in depth (M).
- [ ] Site search (M).
- [ ] Keyboard and screen-reader pass over the admin screens and the page builder (M). Never done.
- [ ] Look at 5 and 6 column card rows in a browser; check live Twitch slides with a real live channel (S).
- [ ] Two admins editing one page at once: last write wins today; add a lock version or a warning (S).
- [ ] CI: the deploy job has a placeholder Render service id (`.github/workflows/staging-deploy.yml`) (S).

## Done

- Sign-in providers made ready: one provider list, credentials from ENV or Rails credentials, only configured providers offered, GitHub email scope fixed, people can disconnect their own accounts, no repeated "add an email" nag, `bin/rails auth:status`, `docs/AUTH_SETUP.md` (`48393c1`).

- Page builder: editable Home, About and landing pages; carousel, card-row and text blocks; cards that feature a page (`c00da67`).
- Admin system: dashboard, users, audit log, site settings, system status (`e32734e`).
- CMS: admin-only page management, public pages, section navigation (`b976cce`, `f736259`).
- Live streams in the home carousel; one live chat for connected channels; per-service handles; YouTube connection.
- Sign up / log in with OAuth; RSpec, FactoryBot and WebMock setup.
