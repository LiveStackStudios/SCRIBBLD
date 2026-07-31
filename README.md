# SCRIBBLD

**Six hand-drawn paper games for iOS.** Tic Tac Toe, Dots & Boxes, Hangman,
Stop! (Tutti Frutti), Sand Snake, and a free-draw Sketching canvas — all
rendered to look like pencil on graph paper, in English and Spanish.

By [LiveStack Studios](https://github.com/LiveStackStudios).

📄 [Privacy Policy](https://livestackstudios.github.io/SCRIBBLD/privacy-policy.html) ·
[Support](https://livestackstudios.github.io/SCRIBBLD/support.html) ·
[Terms of Use](https://livestackstudios.github.io/SCRIBBLD/terms-of-use.html)

---

## Built with

- **SwiftUI**, iOS 17+, portrait only. No UIKit shell.
- **Firebase** — Auth (Sign in with Apple), Firestore, Cloud Messaging, Analytics, App Check.
- **Cloud Functions** (Node 20) for push notifications and account deletion.
- **Google AdMob** — banners only, never mid-game.
- **PencilKit** for the sketching canvas.
- **[xcodegen](https://github.com/yonaskolb/XcodeGen)** — `project.yml` is the source of truth; the `.xcodeproj` is generated and not committed.

## The hand-drawn system

Nothing in the UI is a stock icon. Every line, mark and letter is drawn
procedurally in `Core/Design/`:

- `HandDrawn` — wobbly paths, arcs and rectangles from a seeded RNG, so a line
  looks drawn rather than plotted, and looks the *same* each time it renders.
- `InkBoundsLabel` — the Caveat handwriting font has glyphs whose ink extends
  past their advance width, which SwiftUI clips. This measures true ink bounds
  instead. See `docs/` and the design notes for the measured per-glyph data.
- `WatercolorFill`, `PencilButton`, `MultiStrokeMarks`, `SketchCircle`,
  `PencilDot` — the rest of the pencil-and-paper vocabulary.

## Getting set up

```bash
brew install xcodegen
xcodegen generate
open SCRIBBLD.xcodeproj
```

You'll also need your own `GoogleService-Info.plist` in `SCRIBBLD/Resources/`
— it's excluded from this repo. Create a Firebase project, register an iOS app
with your bundle id, and download it.

## Firestore rules

Security rules live in `firestore.rules` and are covered by a regression suite:

```bash
node tools/verify-firestore-rules.js      # 41 cases, no deploy, no data touched
firebase deploy --only firestore:rules
```

Each DENY case is a real privilege-escalation bug the rules once allowed; each
ALLOW case is a production flow that must keep working. **Run it before every
rules deploy** — a rules change that breaks the app fails here instead of in
TestFlight.

## Layout

```
SCRIBBLD/
├── App/          entry point, splash, tab nav
├── Core/
│   ├── Design/       hand-drawn primitives
│   ├── Monetization/ ads, StoreKit, subscription state
│   └── Remote/       auth, live games, invites, push, moderation, App Check
├── Features/
│   ├── Games/        TicTacToe · DotsAndBoxes · Hangman · Stop · SandSnake
│   ├── Sketching/    PencilKit canvas
│   └── …             Home, Friends, Profile, Settings, PostGame, Premium
└── Models/
functions/        Cloud Functions (push, account deletion, reports)
docs/             privacy policy, support and terms pages (GitHub Pages)
tools/            rules test suite, APNs key checker, TTL backfill
```

## Licence

All rights reserved. The source is public for transparency; the artwork, name
and game content are not licensed for reuse.
