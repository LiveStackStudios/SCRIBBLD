# SCRIBBLD legal + support pages

Four self-contained HTML files. No build step, no assets, no external requests —
all CSS is inline, so they render anywhere you drop them.

| File | Purpose |
|---|---|
| `index.html` | Landing page linking the other three (so the site root isn't a 404) |
| `privacy-policy.html` | **Privacy Policy URL** → App Store Connect → App Information |
| `support.html` | **Support URL** → App Store Connect → 1.0 → App Store tab |
| `terms-of-use.html` | Terms of Use / EULA — needed once Ink Pro subscriptions ship |

Filenames match **Pop-Crush-Worlds/docs/** so every LiveStack app is consistent.
All cross-links are relative, so the set works under any repo name.

Contact address used throughout: **JA@livestackstudios.com**

---

## Setup — one time, ~3 minutes

### 1. Create the repo

github.com → **New repository**

- Owner: **LiveStackStudios**
- Name: **`SCRIBBLD`**
- **Public** ← required; GitHub Pages needs a public repo on a free plan
- Do **not** tick "Add a README"

### 2. Push these files

```bash
cd /Users/juanayala/SCRIBBLD/docs
git init
git add .
git commit -m "SCRIBBLD privacy policy, support and terms pages"
git branch -M main
git remote add origin https://github.com/LiveStackStudios/SCRIBBLD.git
git push -u origin main
```

Sign in when prompted. GitHub wants a **personal access token**, not your account
password — github.com → Settings → Developer settings → Personal access tokens →
Tokens (classic) → Generate new token, tick **repo**, paste it as the password.

> **Why only `docs/` and not the whole SCRIBBLD project:** the repo has to be
> public for Pages to work, and pushing the app would publish
> `GoogleService-Info.plist` and `ExportOptions.plist` along with all the source.
> The APN key *is* safely covered by `.gitignore`, but those two are not.
> Publishing just these four pages avoids the question entirely.

### 3. Turn on Pages

Repo → **Settings** → **Pages**

- Source: **Deploy from a branch**
- Branch: **`main`**, folder: **`/ (root)`**
- Save

Give it a minute or two, then the pages are live.

### 4. The URLs

```
https://livestackstudios.github.io/SCRIBBLD/privacy-policy.html
https://livestackstudios.github.io/SCRIBBLD/support.html
https://livestackstudios.github.io/SCRIBBLD/terms-of-use.html
```

Same shape as the Pop Crush pages, already live at
`https://livestackstudios.github.io/Pop-Crush-Worlds/privacy-policy.html`.

### 5. Paste into App Store Connect

| URL | Where |
|---|---|
| `…/privacy-policy.html` | App Information → **Privacy Policy URL** |
| `…/support.html` | 1.0 → App Store tab → **Support URL** |
| `…/terms-of-use.html` | Only once subscriptions exist — App Information → License Agreement, or linked from the paywall |

---

## Updating later

```bash
cd /Users/juanayala/SCRIBBLD/docs
# edit the file
git add . && git commit -m "Update privacy policy" && git push
```

Pages redeploys in under a minute. Bump the "Last updated" date at the top of
whichever page you changed.

---

## Why these aren't in `public/`

`public/` is the Firebase Hosting root (it serves the invite landing page at
`/i/<gameId>`). Keeping the legal pages out of it means `firebase deploy` can't
publish a second copy that silently drifts from whatever is on GitHub — a stale
privacy policy at a forgotten URL is a genuine compliance problem, not just
untidy.

## Keeping them honest

The privacy policy describes what the app *actually* does, verified against the
code — not a template. If any of this changes, update the page **and** the App
Privacy nutrition labels in App Store Connect (see `../APP_STORE_SUBMISSION.md` §7):

- what Sign in with Apple requests (currently name + email)
- what Firestore stores and for how long (game docs self-delete via TTL)
- whether Firebase Analytics / AdMob are still linked
- the account-deletion route described under "Deleting your account"
  (implemented — Settings → Delete Account, backed by the `deleteAccount`
  Cloud Function)

The terms page carries a **zero-tolerance clause for objectionable content**.
That isn't boilerplate: App Store Guideline 1.2 expects it for any app where
users can see each other's text, which SCRIBBLD is (Stop! answers, Hangman
words, display names).

No governing-law / jurisdiction clause — Apple doesn't require one. Add your
state or country under "Contact" if you want it.
