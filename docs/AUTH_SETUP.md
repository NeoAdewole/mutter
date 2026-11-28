# Setting up sign-in providers

Mutter can sign people in with **GitHub, Twitter, Google, Twitch and Discord**, and can connect **YouTube** to an existing account. The code for all six is finished and tested. What each one needs from you is an *app registration* on the service's own developer site, which gives you a **Client ID** and a **Client secret**. A provider with no credentials is simply not offered: no button on the sign-in, sign-up or profile pages, and `/auth/<name>` explains that it is unavailable.

Check where you are at any time:

```
bin/rails auth:status                                 # which are set up, plus the callback address each needs
BASE_URL=https://your-site.example bin/rails auth:status   # the same, for another address
```

The admin **System** page shows the same Configured / Missing list (never the values).

## 1. Where to put the credentials

First match wins, so a host's environment variables override the credentials file.

**a. Environment variables** (best for Render and other hosts). One pair per service:

| Service | Variables |
|---|---|
| GitHub | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| Twitter | `TWITTER_CLIENT_ID`, `TWITTER_CLIENT_SECRET` |
| Google (also used by YouTube) | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| Twitch (also used for live streams) | `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET` |
| Discord | `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET` |

**b. Rails encrypted credentials** (best for your own machine; the file is committed, the key `config/master.key` never is):

```
EDITOR=nano bin/rails credentials:edit
```

```yaml
github:
  client_id: ...
  client_secret: ...
twitter:
  client_id: ...
  client_secret: ...
google:
  client_id: ...
  client_secret: ...
discord:
  client_id: ...
  client_secret: ...
# Twitch is stored flat (this also works for the others):
twitch_client_id: ...
twitch_client_secret: ...
```

Restart the server after changing either; OmniAuth reads them at boot.

**Never paste a client secret into chat, an issue or a commit.** If one leaks, reset it on the service's site.

## 2. Register each app

The callback address (also called redirect URI or redirect URL) must match **exactly**, including `http` / `https`, host and port. For development use `http://localhost:3000` (use `localhost`, not `127.0.0.1`, and browse the site the same way). For production use your real `https://` address; register both if you use both.

Site layouts change from time to time. If a label below no longer matches, the intent is the same.

### GitHub
1. GitHub → **Settings → Developer settings → OAuth Apps → New OAuth App** (<https://github.com/settings/developers>).
2. Homepage URL: your site. Authorization callback URL: `<site>/auth/github/callback`.
3. Register, then **Generate a new client secret**. Copy the Client ID and the secret.
4. Mutter asks for the `user:email` scope so it receives the person's verified primary email even when it is not public.

### Twitter (X)
1. <https://developer.x.com/en/portal/dashboard>: create a Project and an App.
2. App → **User authentication settings → Set up**: turn on **OAuth 2.0**; type **Web App, Automated App or Bot** (a confidential client); callback URI `<site>/auth/twitter2/callback`; website URL: your site.
3. **Keys and tokens → OAuth 2.0 Client ID and Client Secret.** (Not the "API key" or the bearer token.)
4. Scopes requested: `tweet.read users.read bookmark.read offline.access`. Signing in only needs `users.read`; the rest are for the Tweets features and need an X API access level that allows them.
5. **Twitter never gives an email address.** A person who signs up this way is taken to their profile to add one, once.

### Google
1. <https://console.cloud.google.com/apis/credentials>, in a project of your own.
2. **OAuth consent screen**: set it up (External is usual). While it is in *Testing*, only the test users you list can sign in; add yourself. Scopes: `email`, `profile`, and for YouTube `youtube.readonly`. Moving beyond testing means Google reviews the app, and `youtube.readonly` is a sensitive scope.
3. **Create credentials → OAuth client ID → Web application.** Add **two** authorized redirect URIs: `<site>/auth/google_oauth2/callback` and `<site>/auth/youtube/callback`.
4. **APIs & Services → Library → YouTube Data API v3 → Enable.** (Without it, connecting YouTube works but no channel name is found.)
5. One client serves both Sign in with Google and Connect YouTube, so there is one pair of credentials.

### Twitch
1. <https://dev.twitch.tv/console/apps> → **Register Your Application.**
2. OAuth Redirect URL: `<site>/auth/twitch/callback`; Client Type **Confidential**.
3. **Manage →** Client ID and **New Secret.**
4. The same app is used for the live-streams lookup on the home carousel and for live chat, so Twitch is already configured on the development machine.

### Discord
1. <https://discord.com/developers/applications> → **New Application.**
2. **OAuth2 → Redirects → Add Redirect:** `<site>/auth/discord/callback`.
3. Client ID and Client Secret are on the same page (**Reset Secret** shows a new one).
4. Scopes requested: `identify email`. Discord only passes on an email it has verified.

### YouTube
Nothing separate: it uses the Google credentials. Signed-in people connect it from **Profile → Connect another provider**; it can never be used to sign in.

## 3. Check it worked

1. `bin/rails auth:status` shows the service as `configured`, and the System page shows Configured.
2. Restart the server. The service's button appears on the sign-in, sign-up and profile pages.
3. Sign in with a spare account from that service. You should land on the About page with "Welcome! Your account was created using …". Sign out and in again: "Welcome back". From a normal account, **Profile → Connect** the service, then **Disconnect** it again.

## 4. When something goes wrong

| What you see | Likely cause |
|---|---|
| No button for a service | No credentials, or the server was not restarted. Run `bin/rails auth:status`. |
| "That sign-in method isn't available" | The same, reached through an old link. |
| `redirect_uri_mismatch` (or "Redirect URI is not valid") on the service's page | The callback address registered with the service differs from the one the app sent: host, port, `http` vs `https`, a trailing slash. The one sent is in the address bar of the failed page. |
| "Authentication failed: Invalid credentials" back on the site | Wrong or reset secret. Check which of env vars or credentials is winning (env vars win). |
| Google: "Access blocked: app has not completed verification" | The consent screen is in Testing and the account is not on the test users list. |
| Redirect uses `http://` on the live site | The proxy is not passing `X-Forwarded-Proto`; check `config.force_ssl` and the host's settings. |
| "Sign in could not be completed" | The callback address was opened without having started at the button, or a link was replayed. Press the button again. |

## 5. Adding another service later

Add the strategy gem, then one entry to `AuthProviders::ALL` in `config/auth_providers.rb` (key, strategy, credential group, scopes, console URL) and a display name in `Identity::PROVIDER_LABELS`. Registration with OmniAuth, the buttons, the System page, `auth:status` and the "not available" fallback all follow from that entry. Add the service's response shape to `spec/requests/auth_providers_flow_spec.rb`.
