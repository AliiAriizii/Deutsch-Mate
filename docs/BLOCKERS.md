# Blocker resolutions

Solutions for the seven blockers and four spec conflicts raised in the Phase 1
gap report. Anything still needing your decision is marked **DECIDE**.

---

## 1. Apple Sign-In without a Mac — solved, mostly

The blocker splits into three parts, and only one of them actually needs macOS.

**Server side — no Mac needed.** Sign in with Apple is OpenID Connect. The
client sends an `identityToken`; FastAPI verifies it against Apple's published
keys:

- fetch and cache `https://appleid.apple.com/auth/keys` (JWKS, RS256)
- verify `iss == https://appleid.apple.com`, `aud == <client_id>`, `exp`, and
  the nonce
- `sub` is the stable Apple user id; store it as a federated identity row

A separate **client secret JWT** (ES256, signed with a `.p8` key, carrying
`kid` + team id, max 6 months validity) is needed only for Apple's token
endpoint and for **token revocation** — which the App Store requires you to call
when a user deletes their account. Both are pure Python.

**Testing — no Mac needed.** This is the part that unblocks development: the
`sign_in_with_apple` package falls back to Apple's **web flow** on Android and
web. Register a **Services ID** plus a return URL pointing at our backend, and
the entire flow — consent, token, verification, account linking — is testable on
Android and in Chrome. So Apple auth can be built and proven correct here.

**Building the iOS binary — needs macOS, but not a purchase.** Options:

| Route | Cost | Notes |
|---|---|---|
| **Codemagic** free tier | free, 500 min/month | macOS runners, Flutter-native, easiest start |
| GitHub Actions `macos-latest` | free for public repos; private minutes bill at 10× | fine once there is a remote |
| Cloud Mac rental (Scaleway M1, MacStadium) | ~€0.10–0.15/hr | full Xcode when you need to debug something iOS-specific |
| Mac mini | ~€600 once | only worth it if iOS becomes primary |

Recommendation: **Codemagic** for CI builds, with signing driven by an App Store
Connect API key rather than local certificates.

**Unavoidable cost:** Apple Developer Program, $99/year. Nothing routes around
that for App Store distribution.

**Net effect: Apple Sign-In moves out of Phase 3's critical path.** Build and
verify it on Android/web now; the iOS build is a release-time concern.

---

## 2. Google Sign-In keystore chain — **done**

Keystore generated, Gradle wired, fingerprints extracted. See
[SIGNING.md](SIGNING.md).

Remaining setup, which needs your Google account:

1. Google Cloud project → **OAuth consent screen**.
2. **Android** OAuth client: package `com.deutschmate.app` + **three** SHA-1s
   (debug, upload, and Play app-signing once it exists — see SIGNING.md for why
   missing the third is the classic failure).
3. **Web** OAuth client: its client id becomes `serverClientId` in the app and
   the expected `aud` when the backend verifies the ID token. This exists even
   though there is no web frontend — it is what makes the token verifiable
   server-side.
4. **iOS** OAuth client when iOS ships; `REVERSED_CLIENT_ID` goes in
   `Info.plist`.

Backend work: verify Google ID tokens against
`https://www.googleapis.com/oauth2/v3/certs`, checking `iss`
(`accounts.google.com` or `https://accounts.google.com`), `aud`, `exp`, and
`email_verified`.

`google_sign_in` v7 changed its API — `GoogleSignIn.instance`, `initialize()`,
`authenticate()`. Code written against v6 tutorials will not compile.

### Account linking — the part that is usually shipped broken

The rule: **one account per verified email address, regardless of how you got
in.** Implementation on our `users` collection:

- add `identities[]`: `{provider: password|google|apple, subject, email, linkedAt}`
- on federated sign-in, look up by `email_key` first:
  - no user → create, mark email verified if the provider asserts it
  - user exists, provider already linked → sign in
  - user exists, provider **not** linked → this is the fork everyone gets wrong.
    If the existing account has a password, require a password challenge *then*
    link. If it is another federated identity with a verified matching email,
    link directly. Never create a second account, and never link on an
    unverified email — that is an account-takeover path.
- Apple's **"Hide My Email"** relay addresses mean the email can differ between
  providers for the same human. Treat Apple's `sub` as the identity, never the
  relay address, and never try to match a relay address to a real one.

---

## 3. Vocabulary licensing — solved, and it is not Wiktionary

The share-alike trap is real: German Wiktionary and its derivatives
(Wiktextract/Kaikki) are **CC BY-SA**, so a database derived from them may have
to be released under the same terms. For a commercial app that is a live
constraint, not a footnote. There is also the EU **sui generis database right**,
which protects a substantial-investment database even where the individual facts
are not copyrightable — so "these are just facts" is not a safe defence in
Germany.

**The clean source is Wikidata Lexemes: CC0.** Public domain dedication, no
attribution obligation, no share-alike, commercially unrestricted. Wikidata
models German lexemes with their inflected forms and grammatical features —
exactly the morphology we need (`plural`, `genitive`, `partizipII`,
`präteritum`, gender).

Proposed three-tier pipeline:

| Layer | Source | Licence |
|---|---|---|
| **Scope** — which words belong at which level | Goethe A1/A2/B1 Wortlisten as a *reference* for level assignment | facts about curriculum scope, not copied as a list |
| **Morphology** — article, plural, genitive, verb forms | **Wikidata Lexemes** (SPARQL export) | **CC0** |
| **Examples + translations** | authored originally against the syllabus map | ours |

Wikidata's German coverage is thinner than Wiktionary's, so step one of Phase 7
is a **coverage probe**: run the SPARQL query for the ~650 A1 lemmas and measure
the hit rate before committing. Gaps get authored by hand — which we need to do
for examples anyway.

Fallback if coverage is too low: license a commercial lexicon, or author
morphology by hand using rules plus spot-checking. Both are slower, neither
contaminates the licence.

**DECIDE:** proceed with Wikidata-CC0 + a coverage probe? (My recommendation.)

---

## 4. Audio at ~2,400 words — solved with Piper

Runtime `flutter_tts` cannot be the whole answer: we already proved a device may
have **no German voice installed at all**, and prosody is mediocre where it does.
Cloud TTS means per-request cost, an online dependency against an offline-first
app, and usually a licence that forbids redistributing generated audio.

**Piper** resolves it: MIT-licensed neural TTS, runs locally, small models, good
German voices, and the MIT licence permits **redistributing the generated
audio**. So:

1. Generate audio **once**, server-side, per word and per example sentence.
2. Ship it as versioned content assets through the existing content-package
   mechanism, so audio updates ride the same channel as lesson updates.
3. Cache on device; keep `flutter_tts` as the live fallback for anything not yet
   generated, with the existing "no German voice" warning.
4. Recorded native speaker later for the highest-frequency few hundred items, if
   it ever proves worth it.

Storage estimate: ~2,400 words + ~2,400 examples at ~15 KB (Opus, 24 kHz mono)
≈ **70 MB**. Too much to bundle in the APK, correct to fetch per level — which
is what the content-package versioning already does.

---

## 5. Age gating — do it in Phase 3, not Phase B

Public profiles and follow already expose minors, so this cannot wait for chat.

- Collect **birth date** at signup (a date, not an "I am over 16" checkbox —
  the checkbox is unverifiable *and* gives you nothing to act on later).
- **GDPR Article 8** sets the digital-consent floor at 16 in Germany, with
  member states permitted to lower it to 13. Use **16** as the threshold for a
  German-learning app with German users.
- Derive `isMinor` **server-side**; never let the client assert it.
- Under-16 accounts: profile `visibility` forced to `private`, excluded from
  leaderboards, no follow, no DMs ever. The learning app works entirely
  normally — only the social surface is closed.
- Store the birth date, not the derived age, and treat it as sensitive data
  under the retention and export rules.

Retrofitting this after launch means asking existing users for a birth date and
disabling accounts that refuse. Cheap now, ugly later.

---

## 6. Reporting for Social Phase A — small, and required

Apple guideline 1.2 attaches to **any** user-generated content shown to other
users. Usernames, display names, bios and avatars all qualify, so Phase A needs
the same primitives as chat, minus the volume:

- `reports` collection: `reporterId`, `targetType` (user|avatar|username|bio),
  `targetId`, `reason` enum, `note`, `status`, `createdAt`, `resolvedAt`.
- `POST /moderation/reports`, rate-limited per reporter.
- `moderationState` on the user: `active | shadowed | suspended`. Suspended
  users vanish from search, leaderboards and follower lists.
- Server-side avatar takedown that replaces the image with the generated
  monogram fallback rather than leaving a broken URL.
- Admin endpoints behind the existing `X-Admin-Key`: list open reports, resolve,
  suspend, take down.
- UI: report reachable in ≤2 taps from any profile; block already specified.

Perhaps a day of work. It is the difference between Phase A being shippable and
being rejected.

---

## 7. Speaking exercises / STT — defer, and prefer the version with no STT

Two routes:

- **`speech_to_text`** wraps the platform recogniser (Android
  `SpeechRecognizer`, iOS `SFSpeechRecognizer`). Free, but on Android it
  typically ships audio to Google's servers, which needs disclosure in the
  privacy policy — and for minors that is a harder conversation.
- **Record and self-assess**: the learner records, hears their attempt played
  back against the reference audio, and marks themselves. No STT, no audio
  leaves the device, no privacy disclosure, and pedagogically it is not much
  worse — self-comparison against a model is how pronunciation practice works
  in a classroom.

Recommendation: ship **record-and-self-assess** as the `speaking` type. Revisit
real scoring only if users ask. Either way this is post-Phase-8.

---

# Spec conflicts — resolutions

## A. Gender colours collide with the ramp

`der = #4E86FF` is byte-identical to `blue400`, and `das = #35C48A` is
byte-identical to `success`. An article chip would be indistinguishable from a
focus state, and gender from "correct answer". `die = #FF6FA5` also fights §1's
"desaturated so they don't fight the blue".

Resolution: **keep your hue choices — blue, pink, green — and shift them off the
colliding values.**

| Role | Spec | Shipping | Why |
|---|---|---|---|
| `der` | `#4E86FF` | **`#3E9BD9`** | hue moved ~20° toward cyan; still unmistakably blue, no longer `blue400` |
| `die` | `#FF6FA5` | **`#D9628F`** | same pink family, saturation pulled back so it stops shouting |
| `das` | `#35C48A` | **`#4FA96B`** | greener and darker than `success`, so gender never reads as correctness |

Light-theme variants derived to hold WCAG AA. The article word stays printed on
every chip, so colour never carries meaning alone.

## B. `textTertiary #64707F` fails your own acceptance criteria

3.75:1 on `ink800` — below AA for body text, which §11 requires. §11 is the
harder constraint, so **`#7C889A`** ships. Same for the light equivalent.
Enforced by `frontend/test/theme_contrast_test.dart`.

## C. XP curve — formula wins

`80 * n^1.45` matches your table exactly at n=2 and n=10 and drifts elsewhere
(n=5: 825 vs 774; n=50: 23,259 vs 22,700; best-fit exponent for the table is
1.444). The table looks hand-computed. **The formula is authoritative**, in one
function, and the table in the spec is treated as illustrative.

Definition, since it was ambiguous: `xpForLevel(n)` is the **cumulative** XP
required to *reach* level `n`, with `xpForLevel(1) == 0`. The XP needed to
advance from `n` to `n+1` is the difference.

## D. Three unpriced XP cases

**Multiplier order** — deterministic and server-side:

```
attemptXp = baseXp(exerciseClass)
          × outcomeModifier          // first-ever 1.0 | due review 0.6 | ahead-of-schedule 0.4 | hint 0.5 | wrong 0
          × streakMultiplier         // 1.0 → 1.25
awarded   = attemptXp × dailyReturnFactor(runningDailyTotal)   // 1.0 | 0.5 | 0.25
```

Streak multiplier applies to the attempt; diminishing returns apply **last**,
against the running daily total, so no multiplier can escape the anti-grind cap.

**Practising ahead of schedule** (correct, not first-ever, not due) was
unpriced. Set to **× 0.4** — below a scheduled review's 0.6, because reviewing an
item that is not due teaches less, while still rewarding the effort.

`baseXp` and every modifier live in **one server-side table**, never in the
client.
