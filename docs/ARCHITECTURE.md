# Mutter architecture

One screen per area: what it does, the rules that are easy to break, and where the code is. For the history of why, grep the running docs (see `CLAUDE.md`). Keep this file current: when a feature changes an area, edit that area's paragraph here.

## Site map

| URL | Handled by | Content comes from |
|---|---|---|
| `/` | `MainController#index` | `SitePages.page('home')` |
| `/about` | `AboutController#index` | `SitePages.page('about')` |
| `/streaming`, `/content`, `/gaming`, `/community` | `SectionsController#show` | the section's landing `Page` (`SitePages`) plus the section's top-level pages and built-in features |
| `/<section>/<path>` | `PagesController#show` | `Page` rows (CMS) |
| `/streaming/live-chat` | `StreamingController#show` | built-in, login required |
| `/twitter_accounts`, `/tweets` | their controllers | built-in, login required |
| `/admin/...` | `Admin::*Controller` | see Admin |

The CMS routes are last in `config/routes.rb` because they claim everything beneath the four section names. Put new fixed routes above them.

`Section` (`app/models/section.rb`) is the four fixed top-level areas, kept in code, not the database. It also lists `BUILT_INS` (features that are not pages, such as Live chat) that appear first in a section's menu.

## Accounts and sign-in

- `User` with `has_secure_password`, a unique Mutter `username`, an `admin` flag and `suspended_at` (see `Moderatable`). A suspended user is never "signed in", even with a live session (`ApplicationController#set_current_user`).
- **Providers**: GitHub, Twitter (`twitter2`), Google, Twitch and Discord sign people in; YouTube can only be connected (`Identity::CONNECT_ONLY_PROVIDERS`). `config/auth_providers.rb` (`AuthProviders`) is the one list: strategy, scopes, credential lookup (ENV, nested credentials, flat credentials), console URL. `config/initializers/omniauth.rb` registers only providers that have credentials; the buttons (`ApplicationHelper#identity_providers`), the admin System page and `bin/rails auth:status` read the same list. `/auth/<anything not registered>` lands on `OmniauthCallbacksController#unavailable`. Registering the apps with each service is manual: `docs/AUTH_SETUP.md`.
- `Identity` is one connected provider account. One person can have different names on different services, so handles are per identity (`ProviderHandle`). Sign-in goes through OmniAuth (`SessionsController#create`, `OmniauthCallbacksController#failure`); people disconnect their own accounts with `IdentitiesController#destroy` (refused if it is their last way in; YouTube is always allowed). An account made without an email (Twitter) has a placeholder address and is sent to the profile page until a real one is added. Specs use OmniAuth test mode (`spec/support/omniauth.rb`) and throwaway credentials set in `spec/rails_helper.rb`; `spec/requests/auth_providers_flow_spec.rb` runs every provider's sign-up, sign-in, connect, disconnect and failure paths.
- Password reset: `PasswordResetsController`, `PasswordMailer`. Sign-ups can be switched off with the `signups_enabled` setting.

## Streaming

- `Twitch::Client`, `Twitch::LiveStreams` (who is live among members), `Youtube::Client`/`Channel` in `app/services`. Credentials are read from Rails credentials; specs run with Twitch unconfigured and opt in with stubs (`spec/support/twitch.rb`).
- Live chat page: one merged chat for the member's connected channels. The browser side is `app/javascript/chat/twitch.js` with `chat_controller.js`; to add a platform, add a module in `app/javascript/chat/`, a provider entry in the controller, and the provider to `Identity::CHAT_PROVIDERS`.
- Live streams on the home carousel are on a per-carousel switch and follow the `homepage_streams_*` settings; members can opt out. Looked up at most once per request (`PageBlocksHelper#carousel_streams`).

## CMS and page builder

- `Page` (`app/models/page.rb`, `page/hierarchy.rb`): title, slug, Markdown `body`, `section`, `parent`, `position`, `published`, `show_title`. Slug becomes the address, nested by parent. Drafts are visible to admins only. `public_path` is the address; navigation is built from `Page.in_sections.published`.
- **Site pages** are the Home, About and four landing pages: `Page` rows with a `system_key` and no `section`. Created on first use by `SitePages` (and `db/seeds.rb`), idempotent, never overwrite edits. Always published; address, parent and section cannot change; cannot be moved or deleted. A DB check constraint requires a section or a `system_key`.
- **Blocks** (`PageBlock`, kinds `carousel`, `cards`, `text`; max 20 a page) and their **items** (`BlockItem`: slides and cards, max 12 a block). Called "blocks" because "section" already means Streaming/Content/Gaming/Community.
  - A card can **feature a page**: blank fields fall back to the page's title, a 160-character excerpt and its `public_path`; what is filled in on the card wins. A draft featured page hides the card from visitors (admins see a badge). Deleting the page nullifies the link; a card with nothing of its own is then dropped.
  - Column classes live as literal strings in `PageBlocksHelper::GRID_COLUMNS` (Tailwind scanning).
  - `Orderable` (`move`, `append_to_siblings`) orders pages, blocks and items.
  - Everything renders through `pages/_content`, then `pages/_blocks` and `pages/blocks/_<kind>`.
  - **New block kind**: add to `PageBlock::KINDS` and `PERMITTED`; add `pages/blocks/_<kind>.html.erb` and `admin/blocks/_fields_<kind>.html.erb`. Adding, ordering, deleting and auditing then work.
  - Block changes are live immediately on a published page (no draft state for blocks).
- Images are web addresses only (no upload yet). `BlockItem` rejects URLs that are not `http(s)://` or `/path`.
- Markdown: `MarkdownRenderer.call` (sanitised HTML) and `.plain_text` (for excerpts and summaries).

## Admin

- `Admin::BaseController`: admin layout, guests redirected to login, non-admins get a 404, `Paginatable`, `audit(...)`.
- Screens: dashboard (`Admin::DashboardStats`), pages and blocks and items, users (grant/revoke admin, suspend, reset password, remove identities), audit log (append-only; `AuditLog::ACTIONS`), site settings (`SiteSetting`, `SiteSetting::Definitions::ALL`), system (`Admin::SystemStatus`, cache clear).
- Maintenance mode shows a maintenance page to everyone but admins (`enforce_maintenance_mode`); the sign-in screens opt out so an admin can still log in.
- Authorization is tested in one place: `spec/requests/admin_authorization_spec.rb` has a row for every endpoint. Add a row for each new one.

## Front end

- Layouts: `application`, `admin`, `bare` (maintenance). The navbar is built from `NavigationHelper`.
- Stimulus controllers in `app/javascript/controllers` (carousel, chat); importmap, no bundler. Tailwind input is `app/assets/tailwind/application.css` with `@source` lines for views, helpers and JS.
- Shared partials in `app/views/shared` (carousel takes `slides:`, flash, form errors, nav).

## Data

Postgres. Main tables: `users`, `identities`, `pages`, `page_blocks`, `block_items`, `site_settings`, `audit_logs`, `tweets`, `twitter_accounts`. Cascades: deleting a page deletes its blocks and items; deleting a featured page nullifies `block_items.featured_page_id`.

## Deploy

`staging` and `pipeline` branches run tests and linters in GitHub Actions and deploy to Render (`render.yaml`; also `fly.toml` and a `Dockerfile` exist). The Render service id in the workflow is still a placeholder.
