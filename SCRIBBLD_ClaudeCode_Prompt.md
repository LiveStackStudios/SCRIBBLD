# SCRIBBLD — Complete Claude Code Build Prompt
## iOS App in Swift + SwiftUI + Xcode

---

## ROLE

You are a senior iOS engineer building **SCRIBBLD** — a premium paper-games app for iPhone. 
You write production-quality Swift + SwiftUI. You structure projects cleanly, separate concerns, 
and build every feature to ship. Read this entire document before writing a single line of code.

---

## WHAT YOU ARE BUILDING

A native iOS app (iPhone, portrait-only for V1) that digitizes 5 classic pen-and-paper experiences:
1. **Tic Tac Toe** — hand-sketch style X and O, animated pen strokes
2. **Dots & Boxes** — tap-to-draw lines, watercolor box fills, live score
3. **Hangman** — pencil-drawn gallows + body parts, typewriter keyboard
4. **Stop!** — category card game with analog countdown timer
5. **Sketching** — free-draw canvas with brush styles and color palette

**Tech stack**: iOS 17+, Swift 5.9+, SwiftUI, Xcode 15+  
**No backend for V1** — all state is local (UserDefaults + SwiftData where appropriate)  
**No user accounts** — device-local identity only

---

## PROJECT STRUCTURE

```
SCRIBBLD/
├── App/
│   ├── SCRIBBLDApp.swift
│   └── AppState.swift              // ObservableObject: subscription, streak, dailyChallenge
├── Core/
│   ├── Design/
│   │   ├── DesignTokens.swift      // Colors, fonts, spacing as static constants
│   │   ├── PencilStroke.swift      // Canvas drawing primitives (CGPath, animatable strokes)
│   │   └── HandDrawnModifiers.swift // ViewModifier for sketch borders, paper bg, ink effects
│   ├── Monetization/
│   │   ├── StoreManager.swift      // StoreKit 2 — products, purchase, restore, entitlement
│   │   ├── SubscriptionStatus.swift // Enum: free | trial | inkPro
│   │   └── AdManager.swift         // Google AdMob wrapper — banner, interstitial, rewarded
│   ├── Haptics/
│   │   └── HapticEngine.swift      // UIImpactFeedbackGenerator presets: light/medium/heavy
│   └── Notifications/
│       └── NotificationManager.swift // UNUserNotificationCenter — daily challenge, streak
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── Games/
│   │   ├── TicTacToe/
│   │   │   ├── TicTacToeView.swift
│   │   │   ├── TicTacToeViewModel.swift
│   │   │   └── TicTacToeAI.swift
│   │   ├── DotsAndBoxes/
│   │   │   ├── DotsAndBoxesView.swift
│   │   │   ├── DotsAndBoxesViewModel.swift
│   │   │   └── DotsAndBoxesAI.swift
│   │   ├── Hangman/
│   │   │   ├── HangmanView.swift
│   │   │   ├── HangmanViewModel.swift
│   │   │   └── HangmanWordBank.swift
│   │   └── Stop/
│   │       ├── StopView.swift
│   │       ├── StopViewModel.swift
│   │       └── StopCategories.swift
│   ├── Sketching/
│   │   ├── SketchingView.swift
│   │   ├── SketchingViewModel.swift
│   │   ├── SketchCanvas.swift      // UIViewRepresentable wrapping PKCanvasView (PencilKit)
│   │   └── BrushPalette.swift
│   ├── PostGame/
│   │   ├── PostGameView.swift
│   │   └── PostGameViewModel.swift
│   ├── DailyChallenge/
│   │   ├── DailyChallengeView.swift
│   │   └── DailyChallengeManager.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── StampCollection.swift
│   ├── Premium/
│   │   ├── InkProView.swift        // Upsell / paywall screen
│   │   └── TrialBannerView.swift   // 7-day trial countdown banner
│   └── Settings/
│       └── SettingsView.swift
├── Models/
│   ├── GameResult.swift
│   ├── Stamp.swift
│   ├── DailyChallenge.swift
│   └── StreakData.swift
└── Resources/
    ├── Fonts/                      // Caveat-Regular, Caveat-Bold, DMSans-Regular, DMSans-Medium
    ├── Assets.xcassets/
    └── Words/                      // hangman_words.json, stop_categories.json
```

---

## DESIGN TOKENS — IMPLEMENT EXACTLY

```swift
// DesignTokens.swift
extension Color {
    static let cream        = Color(hex: "#FEFCF3")   // app background
    static let inkBlue      = Color(hex: "#1A365D")   // primary text, buttons, fills
    static let redPen       = Color(hex: "#C53030")   // accent, errors, Player 2
    static let gridGray     = Color(hex: "#D4B896")   // graph paper lines
    static let softGray     = Color(hex: "#8C8C7A")   // secondary text
    static let lightLine    = Color(hex: "#EDE8D8")   // dividers, card borders
    static let goldAccent   = Color(hex: "#B7881A")   // premium/Ink Pro highlights
    static let inkGreen     = Color(hex: "#2E7D5A")   // win states, correct answers
}

extension Font {
    // Register Caveat (Google Fonts) and DM Sans in Info.plist
    static func caveat(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Caveat", size: size).weight(weight)
    }
    static func dmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("DMSans", size: size).weight(weight)
    }
}
```

**Graph paper background**: Always a subtle SVG-style grid, NOT a solid color.  
Build as a `Canvas` view drawing horizontal + vertical lines at 20pt intervals in `gridGray` at 0.3 opacity.  
Use `.background(GraphPaperView())` as a modifier throughout the app.

**Typography hierarchy**:
- Screen titles: Caveat Bold 32pt, inkBlue
- Card headings: Caveat Bold 22pt, inkBlue  
- Game names: Caveat Bold 18pt, inkBlue
- Body / labels: DM Sans Regular 13–14pt, inkBlue
- Secondary: DM Sans Regular 11–12pt, softGray
- Post-game hero: Caveat Bold 42pt — "Sharp. / You got them."

**Visual motifs** (implement each as a reusable SwiftUI view or modifier):
- `PencilLineView`: a wavy `Path` underline, ~2pt stroke, simulating a hand-drawn rule
- `SketchBorderModifier`: rounded rectangle overlay with slightly irregular corners (4 short Path segments with minor random offsets), 1.5pt stroke
- `WatercolorFill(color:)`: a rectangle fill with 2–3 overlapping rounded rects at low opacity to simulate watercolor wash
- `InkSplashEffect`: particle burst using `TimelineView` + `Canvas` — 8–12 ink droplets radiating from a center point, used on win in Tic Tac Toe

---

## SCREEN-BY-SCREEN SPECIFICATIONS

### 1. SPLASH SCREEN (`SplashView.swift`)

- Cream background with graph paper
- "SCRIBBLD" types out letter by letter using a `TimelineView` driving a `String` prefix
- Each letter appears as if drawn by a pen: fade-in + scale from 0.8→1.0 per letter, 120ms interval
- After the full word: tagline "Play like it's analog." fades in below (DM Sans 14pt, softGray)
- Auto-advances to HomeView after 1.8s total
- No login, no onboarding gate — straight to Home

### 2. HOME SCREEN (`HomeView.swift`)

**Tab bar** (matches mockup): Home / Games / Friends / Profile — icon + label  
Icons: SF Symbols — house.fill / gamecontroller.fill / person.2.fill / person.circle.fill  
Notification badges shown on Games and Friends tabs in the mockup (implement as `.badge()` modifier)

**Top bar**:
- Center: "SCRIBBLD" in Caveat Bold 20pt (acts as a logo wordmark — NOT a navigation title)
- Right: flame emoji + streak count in Caveat Bold 18pt, redPen color — e.g. "🔥 14"

**Greeting**: "Good morning," / "Good afternoon," / "Good evening," — Caveat Bold 28pt  
Determined by current hour: <12 = morning, 12–17 = afternoon, 17+ = evening

**Game grid** (2×2):  
Each card is a rounded rectangle (16pt corner), lightLine border, white fill, `SketchBorderModifier`  
Card contents:
- Hand-drawn style illustration (use SwiftUI `Canvas` or `Path` — NOT emoji or SF Symbols)
- Game name in Caveat Bold 18pt
- Short description in DM Sans 12pt softGray (e.g. "Hand sketched X's and O's")
- Tap → navigates to Game Detail screen

**Game illustrations** (draw with SwiftUI `Path` / `Canvas`):
- Tic Tac Toe card: 3×3 grid lines + X's and O's sketched in
- Dots & Boxes card: 3×3 dot grid with some connecting lines and colored boxes
- Hangman card: simplified gallows with stick figure
- Stop! card: STOP sign octagon + hand illustration

**Daily Challenge card** (below game grid):  
- Red dashed border rectangle (SketchBorderModifier with redPen stroke + dash pattern)
- Label "DAILY CHALLENGE" in DM Sans caps 10pt, centered, inkBlue
- Inside: challenge title in Caveat Bold 22pt + decorative tiles/icons
- Example: "Challenge: Quick Math" with illustrated number tiles
- Tap → DailyChallengeView

### 3. TIC TAC TOE (`TicTacToeView.swift`)

**Visual style** (matches mockup exactly):
- Cream background, graph paper grid underneath
- 3×3 grid drawn as 4 `Path` lines (2 horizontal, 2 vertical) — NOT RoundedRectangle borders
- Grid lines: inkBlue, 2pt stroke, slightly imperfect (add ±1pt random offset at endpoints stored as @State, set once on appear)
- **X marks**: drawn as 2 diagonal strokes using `Path`, animated with `trim(from:to:)` — inkBlue, 3pt stroke, round cap
- **O marks**: drawn as `Circle` with `trim(from:to:)` animation — redPen, 3pt stroke
- Animation duration per mark: 0.25s

**Top bar**:
- Left: "SCRIBBLD" wordmark
- Right: "TURN" label — indicates whose turn

**Status banner**: "PLAYER 1 (X) WINS!" — Caveat Bold 20pt, centered, appears with spring animation

**Win state**: 
- Animated line strikes through winning row/column/diagonal — redPen, 3pt, `trim` animation
- Behind winning line: `WatercolorFill` in redPen at 0.15 opacity sweeps across
- No confetti — use `InkSplashEffect` instead

**Score tracker** (bottom):
- "P1: 1 ✝✝✝✝ ||||" — tally marks drawn with `Path`, inkBlue
- "P2: 0 |" — in redPen
- Tally marks: vertical strokes with a diagonal fifth stroke, hand-drawn style

**Bottom controls**:
- Undo button (↺ SF Symbol) bottom-left
- Settings gear bottom-right

**AI modes**: Easy (random valid moves), Medium (block wins), Hard (minimax algorithm)  
Implement `TicTacToeAI.swift` with `func bestMove(for board: Board, as player: Player) -> Int`

### 4. DOTS & BOXES (`DotsAndBoxesView.swift`)

**Layout** (matches mockup):
- Top: back chevron left, "SCRIBBLD · Dots & Boxes" centered, gear right
- Score bar: "YOU (Blue): 14 | THEM (Red): 11" with tally marks below each
- "TURN: YOURS" centered label in DM Sans caps

**Grid**:
- Dots rendered as small filled circles (6pt diameter), gridGray
- Tappable edges: invisible hit areas between adjacent dots (use `Path` segments as touch targets via `.contentShape(Path(...))`)
- Drawn edges: `Path` line segment, 2pt stroke — inkBlue for player, redPen for AI
- Edge draw animation: `trim(from:to:)` over 0.15s, simulating pen stroke
- Completed boxes: `WatercolorFill` wash — inkBlue tint for player boxes, redPen tint for AI boxes
- Box labels: small initials "ME" / "T" or "P" inside boxes (DM Sans 9pt) — matches mockup

**Pencil cursor**: 
- During drag to select edge: show a small pencil icon SVG following the drag
- Implement with a `DragGesture` on the grid overlay

**Grid size**: 5×5 default (free), up to 8×8 (free), 10×10 (Ink Pro)  
Configurable in game detail screen

**Chain reaction signal**: when completing a box earns another turn, pulse the score counter with `.scaleEffect(1.1)` spring animation and fire medium haptic

**END GAME button**: bottom of screen, sketch-border rectangle, inkBlue text

### 5. HANGMAN (`HangmanView.swift`)

**Layout** (matches mockup):
- Top: "SCRIBBLD 🖊" wordmark, action icons right
- Subtitle: "WORD GAME / HANGMAN" in DM Sans caps, softGray
- Gallows + figure area: white card with rounded corners, notebook-lined background (horizontal rules drawn with Canvas), scroll-able

**Gallows drawing** (pure SwiftUI `Path`, drawn incrementally):
```
Stage 0: empty
Stage 1: base horizontal line
Stage 2: left vertical post  
Stage 3: top horizontal beam
Stage 4: short drop line (noose attachment)
Stage 5: head (circle)
Stage 6: body (vertical line)
Stage 7: left arm
Stage 8: right arm
Stage 9: left leg
Stage 10: right leg (game over)
```
Each part animates in with `trim(from:to:)` over 0.4s. Stroke: inkBlue 2pt, sketch-style (not perfectly straight — add minor Bezier control point wobble).

**Word display**: 
- Dashes for unknown letters, revealed letters animate scale 0.5→1.0 + fade in
- Font: Caveat Bold 28pt, inkBlue for correct letters
- Correct: inkGreen. Wrong: not shown here, shown in wrong letters section

**Wrong letters section**: 
- Shows incorrect guessed letters in a row, DM Sans Bold 18pt
- Each wrong letter rendered with a red strikethrough `Path` drawn across it
- Matches mockup: "E I Ø U X Z" with strikethroughs in redPen

**Status bar**: "GUESSES LEFT: 3   CATEGORY: ANIMALS" — DM Sans 11pt caps, softGray

**Keyboard** (custom — matches mockup):
- QWERTY layout, A–Z
- Each key: circle shape, DM Sans 14pt letter, inkBlue border
- State: default (inkBlue border), correct guess (inkGreen border + fill), wrong guess (grayed out, not pressable)
- Highlighted keys in mockup ("H", "K", "L" in green) = correct guesses

**Friendly mode**: replace gallows + figure with rocket ship losing fuel gauges (toggleable in Settings)

### 6. STOP! (`StopView.swift`)

**Layout** (matches mockup exactly):
- Top: hamburger menu left, "SCRIBBLD" center, player avatars right
- Subtitle: "Stop! Word Game" + coin/point counter right
- Analog timer: large clock-face style with sweep hand, "45s TIME REMAINING" label, round indicator style — implement with `Canvas` drawing arc + `TimelineView` driving angle

**Timer implementation**:
```swift
// Analog clock face style
Canvas { context, size in
    let center = CGPoint(x: size.width/2, y: size.height/2)
    let radius = min(size.width, size.height) / 2 - 4
    // Draw tick marks
    // Draw sweep arc from 0 to currentAngle in inkBlue
    // Draw hand line
}
.frame(width: 100, height: 100)
```

**Round label**: "ROUND 3" in DM Sans caps 12pt

**Category cards** (index card / sticky note style):
- White cards with pinned corners or tape corners simulated
- "COUNTRIES: Peru", "ANIMALS: Zebra" etc.
- Yellow sticky note for filled-in answers (like "FRUIT/VEG: Pear" in yellow)
- Empty cards show just the category label + blank lined area
- Cards arranged in 2-column grid

**STOP! button**:
- Large red rounded rectangle, full-width
- "STOP!" text in Caveat Bold 28pt, white
- `UIImpactFeedbackGenerator(.heavy).impactOccurred()` on tap
- Brief scale-down 0.95 spring animation on press

**Previous round results panel**:
- "PLAYER ANSWERS (RND 2)"
- Small index cards showing each player's answers with ✓ (inkGreen) or ✗ (redPen)

**Locked premium packs** (bottom):
- "LOCKED PREMIUM PACKS" label
- "MOVIES" / "TRAVEL" cards with lock icon and "INK PRO" diagonal ribbon
- Tap → InkProView

**Categories data** (`stop_categories.json`):
```json
{
  "free": ["Countries", "Animals", "Names", "Food", "Sports", "Colors", "Movies", "Cities"],
  "premium": ["Movies Deep Dive", "Travel & Places", "Science", "History", "Music", "Custom"]
}
```

### 7. SKETCHING (`SketchingView.swift`)

**This is a full PencilKit-based drawing canvas** — use `PKCanvasView` via `UIViewRepresentable`

**Layout** (matches mockup):
- Top: "SCRIBBLD" + search icon
- Section "SCRIBBLD Sketching"
- "Brush Styles" — horizontal scroll of brush chips
- "Color Palette" — circular color swatches with labels
- Canvas area below with title/date and the actual sketch

**Brush styles** (match mockup icons):
- Pencil, Calligraphy, Carbon, Chalk, Ink Pen, Marker
- Map to `PKInkingTool` types:
  - Pencil → `.pencil`
  - Calligraphy → `.pen` with flat nib
  - Carbon → `.monoline`
  - Chalk → custom texture via `.pencil` + opacity variation
  - Ink Pen → `.pen`
  - Marker → `.marker`

**Color palette** (matches mockup):
- Deep Ink Blue (#1A365D), Red Pen (#C53030), Forest Green (#2E7D5A), Burnt Sienna (#8B4513), Charcoal (#36454F), Gold (#B7881A), Soft Lavender (#B8A9C9)
- Each as a filled circle with label below

**FREE TIER RESTRICTIONS** (CRITICAL):
- Only **Black** and **Red Pen** colors available
- Only **Pencil** and **Ink Pen** brush styles available
- All other colors/brushes show as grayed out with a lock icon
- Banner ad shown at bottom of canvas
- A "Watch an ad to unlock [color/brush] for this session" rewarded ad button appears when user taps a locked item

**INK PRO TIER**:
- All 7 colors unlocked
- All 6 brush styles unlocked
- No ads
- Unlimited sketch saves

**Rewarded ad flow** (free tier):
1. User taps locked color or brush
2. Bottom sheet appears: "[Color Name] is an Ink Pro feature. Watch a short ad to use it for this session?"
3. Two buttons: "Watch Ad (15s)" | "Get Ink Pro"
4. If ad completes: unlock that specific color/brush for the current session only
5. On next app launch: reverts to locked state

**Sketch canvas header** (matches mockup):
- Title text field (e.g. "Summer cabin ideas!") in Caveat 20pt
- Date label (e.g. "12.10.23") in DM Sans 11pt softGray
- The canvas itself shows graph paper background

**Bottom toolbar** (matches mockup icons, left to right):
- Eraser, Undo, Redo, Zoom, Layers, Save, Settings

**Tab bar for Sketching module**: Notebook / Sketch / Gallery / Account

### 8. POST-GAME SCREEN (`PostGameView.swift`)

**This is the #1 retention screen — implement with highest visual polish**

**Layout** (matches mockup):
- Top: "SCRIBBLD" wordmark left, user display "🖊 Alex_S / 5,300 pts" right
- Hero area (top ~55% of screen): cream background with watercolor ink splash effect
  - Blue watercolor wash top-left area
  - Red watercolor wash bottom-right area
  - Implement both as `WatercolorFill` with `Canvas` + multiple overlapping ellipses, low opacity

**Result headline**:
- "Sharp." — Caveat Bold 42pt, inkBlue, with calligraphic flourishes
- "You got them." — same style, line below
- Flourishes: SVG-style curlicues rendered as `Path` curves around the text
- Animates in with `.transition(.move(edge: .top).combined(with: .opacity))`

**Stats section** (below hero):
- "Final Score: 4,850 pts" — DM Sans Medium 18pt, with red underline (PencilLineView)
- "Correct Answers: 24/25" — same style
- "Game Time: 12:38" — with flame icon

**Streak section**:
- "STREAK: 🔥 14 Games" — Caveat Bold 18pt, redPen
- Tally marks rendered as `Path` — groups of 5 vertical marks with diagonal fifth

**CTA buttons** (3, matching mockup — sketch-border rectangle style):
1. "Review Game" — inkBlue border, inkBlue text
2. "New Challenge" — inkBlue border, inkBlue text  
3. "Share Results" — redPen border, redPen text + share icon (this is the viral loop)

**Share Results implementation**:
```swift
let shareText = "I scored 4,850 pts in SCRIBBLD! 🖊 Can you beat me? [App Store link]"
let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
```
No spoilers in the share text — only score and bragging, no answers.

**Win/Loss/Draw copy variants**:
```
Win: "Sharp. / You got them." | "Clean sweep." | "No contest."
Loss: "So close. / Rematch?" | "They got lucky." | "Next time."
Draw: "Evenly matched." | "Call it a tie." | "Nobody wins. / Play again?"
```

### 9. PROFILE / STATS SCREEN (`ProfileView.swift`)

**Layout** (matches mockup):
- "Profile" in Caveat Bold 32pt with red-pen underline
- Settings gear + notification bell top right
- User avatar: circular stamp/seal design with initials "JD" and name arc text — rendered with `Canvas`
- "Jane Doe" in Caveat Bold 20pt, "Member Since: Nov 2023" in DM Sans 13pt redPen

**Daily Stamps Collection**:
- Section header "Daily Stamps Collection" Caveat Bold 20pt
- 2×3 grid of collectible stamps (rendered with SwiftUI Canvas):
  - Each stamp: rounded rectangle border with perforated/serrated edges (dashed dash pattern)
  - Inside: circular design with text arcing around a central icon
  - Examples from mockup: "7 Day Streak", "Mindful Writer", "Creative Flow", "Doodle Champ", "Ink Master", "100 Scribbles"
  - Earned stamps: fully rendered; Unearned: 30% opacity
- "COLLECTION" label below grid in DM Sans caps

**Stamp rendering** (pure SwiftUI, no images):
```swift
struct StampView: View {
    let stamp: Stamp
    var body: some View {
        Canvas { context, size in
            // Outer serrated rectangle border
            // Inner circle
            // Arc text (stamp.title)  
            // Central icon (stamp.icon as SF Symbol or simple Path)
        }
        .opacity(stamp.isEarned ? 1.0 : 0.3)
    }
}
```

**Game Stats section**:
- "Total Scribbles: 1,452" | "Daily Average: 42" | "Active Days: 184"
- "STAT BREAKDOWN" divider in DM Sans caps
- Sparkline charts (DM Sans 12pt labels below):
  - Words Written: 8.2k (red sparkline)
  - Sketches Drawn: 312 (blue sparkline)
  - Ideas Captured: 498 (blue sparkline)
  - Implement with SwiftUI `Path` drawn through data points

**Streak highlight** (bottom):
- Large flame emoji + "Longest Streak: 119 Days" — Caveat Bold 22pt, redPen
- Tally marks below (same hand-drawn style as post-game screen)

### 10. INK PRO UPSELL (`InkProView.swift`)

**This must feel like an invitation, not a paywall.**

**Layout** (matches mockup):
- "Ink Pro" seal/badge — circular stamp design (inkBlue border, goldAccent text) top-left
- "Go Unlimited with Ink Pro!" — Caveat Bold 28pt, inkBlue

**Theme preview carousel**:
- Horizontal `ScrollView` with page dots
- First card: "Premium Dark 'Midnight Ink' Theme Preview" — shows a dark-themed miniature UI screenshot
- Swipeable to show other themes

**Membership card** (matches mockup — vintage train ticket / library card aesthetic):
- Rectangle with serrated/perforated left edge (dashed Path)
- Postage stamp illustration top-right corner
- "MEMBERSHIP CARD" in DM Sans Bold caps
- Checkmarks with feature list:
  - ✓ UNLIMITED SKETCHBOOKS
  - ✓ EXCLUSIVE BRUSHES  
  - ✓ CLOUD SYNC (future)
  - ✓ PRIORITY SUPPORT
- Postmark stamp bottom-right: circular stamp saying "Active Now"

**Pricing options** (3 cards — matches mockup):
- "1 MONTH — $1.99/mo" — plain card
- "12 MONTHS — $14.99/yr — BEST VALUE — SAVE 37%" — slightly larger card, red star decoration, underlined pricing
- "FOREVER INK — $9.99 one-time" — plain card  

**Note on actual prices**: The mockup shows different prices. Use YOUR specified prices:
- Monthly: **$1.99/mo**
- Annual: **$14.99/yr** (save ~37%)
- Lifetime: **$9.99 one-time**

**CTA**: "★ Upgrade to Ink Pro ★" — full-width rounded rectangle, inkBlue fill, cream text, Caveat Bold 20pt

---

## MONETIZATION — IMPLEMENTATION DETAILS

### StoreKit 2 Products

```swift
// Product IDs
enum ProductID: String, CaseIterable {
    case monthlySubscription = "com.scribbld.inkpro.monthly"
    case annualSubscription  = "com.scribbld.inkpro.annual"
    case lifetimePurchase    = "com.scribbld.inkpro.lifetime"
}
```

### 7-Day Free Trial

- Configure the 7-day trial in App Store Connect on the monthly subscription product
- On first launch, prompt user to start trial (not a hard gate — they can skip)
- Show a subtle "Trial: X days remaining" banner in Settings during trial
- Trial banner copy: "Your Ink Pro trial has 5 days left. Keep it?"
- When trial ends: graceful downgrade to free tier, soft upsell card on Home

```swift
// StoreManager.swift
func startTrial() async throws {
    // Purchase monthly product — StoreKit 2 automatically applies trial
    let product = try await Product.products(for: [ProductID.monthlySubscription.rawValue]).first!
    let result = try await product.purchase()
    // Handle .success, .userCancelled, .pending
}
```

### Subscription Status Check

```swift
enum SubscriptionStatus {
    case free
    case trial(daysRemaining: Int)
    case inkPro
}

// Check on every app foreground
func refreshEntitlements() async {
    for await result in Transaction.currentEntitlements {
        // Determine status
    }
}
```

### Ad Placement Rules (STRICT)

| Location | Ad Type | Free | Ink Pro |
|---|---|---|---|
| Home screen (bottom) | Banner | ✅ | ❌ |
| Post-game screen | Banner | ✅ | ❌ |
| Mid-game | ANY | ❌ NEVER | ❌ NEVER |
| Daily Challenge | ANY | ❌ NEVER | ❌ NEVER |
| Sketch session (bottom) | Banner | ✅ | ❌ |
| Locked color/brush tap | Rewarded | ✅ optional | N/A |

```swift
// AdManager.swift
class AdManager: ObservableObject {
    // Google AdMob — import GoogleMobileAds
    private var bannerView: GADBannerView?
    private var rewardedAd: GADRewardedAd?
    
    func loadBanner(for adUnitID: String) { ... }
    func loadRewarded() async { ... }
    func showRewarded(completion: @escaping (Bool) -> Void) { ... }
    
    // ATT (App Tracking Transparency) — request BEFORE loading ads
    func requestTrackingPermission() async {
        await ATTrackingManager.requestTrackingAuthorization()
    }
}
```

**ATT prompt**: Show on second launch (not first), after user has seen value. Do NOT show before any gameplay.

### Rewarded Ad Flow (Sketching)

```swift
// When free user taps locked brush/color:
struct LockedFeatureSheet: View {
    let featureName: String
    @Environment(AdManager.self) var adManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(featureName) is Ink Pro")
                .font(.caveat(22, weight: .bold))
            Text("Watch a short ad to unlock it for this session")
                .font(.dmSans(14))
            
            Button("Watch Ad (15s)") {
                adManager.showRewarded { success in
                    if success { unlockForSession() }
                }
            }
            
            Button("Get Ink Pro →") {
                // Navigate to InkProView
            }
        }
    }
}
```

---

## RETENTION MECHANICS — IMPLEMENTATION DETAILS

### Daily Challenge System

```swift
// DailyChallengeManager.swift
struct DailyChallenge {
    let date: Date
    let gameType: GameType  // Rotates: Mon=TTT, Tue=D&B, Wed=Hangman, Thu=Stop, Fri=Sketch
    let parameters: ChallengeParameters
    var isCompleted: Bool
    var earnedStamp: Stamp?
}

// Rotation schedule
func gameForToday() -> GameType {
    let weekday = Calendar.current.component(.weekday, from: Date())
    return [.ticTacToe, .dotsAndBoxes, .hangman, .stop, .sketching, .ticTacToe, .dotsAndBoxes][weekday - 1]
}
```

### Streak System

```swift
// StreakData.swift (persisted via UserDefaults)
struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var freezesAvailable: Int    // 1 per week, max 2 stored
    var freezeUsedThisWeek: Bool
}

// Check on daily challenge completion:
func recordCompletion() {
    let today = Calendar.current.startOfDay(for: Date())
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    
    if lastCompletedDate == yesterday {
        currentStreak += 1
    } else if lastCompletedDate != today {
        if freezesAvailable > 0 && daysMissed == 1 {
            freezesAvailable -= 1
            currentStreak += 1  // Freeze used
        } else {
            currentStreak = 1   // Reset
        }
    }
    lastCompletedDate = today
}
```

**Streak milestones → stamp awards**:
- 7 days → "7 Day Streak" stamp
- 30 days → "Monthly Master" stamp  
- 100 days → "Ink Legend" stamp + special Ink Legend badge in Profile

### Push Notifications

```swift
// NotificationManager.swift
func scheduleDailyReminder(at hour: Int, minute: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Your daily challenge is waiting 🔥"
    content.body = streakCount > 3 
        ? "Day \(streakCount + 1) of your streak. Don't break it now."
        : "A new game is ready for you."
    content.sound = .default
    
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(identifier: "daily_challenge", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

// Re-engagement notifications:
// - 3 days inactive: "You left a Dots & Boxes game unfinished..."
// - 6-day streak: "One more day for your weekly badge 🏆"
// - 7-day streak milestone: "7 days! You're the real deal."

// WHEN TO REQUEST PERMISSION: 
// After user completes their FIRST daily challenge (not on first launch)
func requestPermissionAfterFirstWin() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in }
}
```

### Friend Sharing (Viral Loop)

```swift
// Generate challenge deep link
func generateChallengeLink(game: GameType, score: Int) -> URL {
    // URL scheme: scribbld://challenge?game=tictactoe&score=9&challenger=Alex_S
    // For V1: use universal link or simple URL scheme
    // Share via UIActivityViewController
    var components = URLComponents()
    components.scheme = "scribbld"
    components.host = "challenge"
    components.queryItems = [
        URLQueryItem(name: "game", value: game.rawValue),
        URLQueryItem(name: "score", value: "\(score)"),
    ]
    return components.url!
}

let shareText = """
I just beat the AI in Tic Tac Toe on SCRIBBLD — think you can do better?
Score: \(score) pts
[App Store link]
"""
```

---

## HAPTICS — USE THROUGHOUT

```swift
// HapticEngine.swift
class HapticEngine {
    static func light()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()  { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// Usage:
// Placing a mark (TTT, D&B): .light()
// Completing a box (D&B): .medium()
// Pressing STOP! button: .heavy()
// Winning a game: .success()
// Wrong letter (Hangman): .error()
// Tapping keyboard key (Hangman): .light()
// Subscribing to Ink Pro: .success() x 2
```

---

## ACCESSIBILITY

- All interactive elements: minimum 44×44pt touch target
- All colors pass WCAG AA contrast on cream (#FEFCF3) background
- VoiceOver labels on all game elements:
  - TTT cells: "Row 2, Column 3. Empty." / "Row 1, Column 1. X placed."
  - Hangman keyboard: "Letter A. Available." / "Letter E. Already guessed."
- Dynamic Type: all DM Sans body text respects `.body` / `.caption` type sizes
- Reduce Motion: respect `@Environment(\.accessibilityReduceMotion)` — skip animations, show static versions

---

## SETTINGS SCREEN (`SettingsView.swift`)

**Sections**:
1. **Notifications** — Daily challenge reminder toggle + time picker
2. **Sound & Haptics** — Sound effects toggle, Haptic feedback toggle
3. **Appearance** — Light (default, free), Midnight Ink (Ink Pro — tapping it goes to InkProView if not subscribed)
4. **Hangman Style** — Classic (gallows) / Friendly (rocket) pill toggle
5. **Ink Pro** — Shows subscription status; "Manage Subscription" link to App Store settings
6. **About** — Version number, Privacy Policy (WKWebView or Safari), Rate the App (SKStoreReviewController), Tell a Friend (UIActivityViewController), Restore Purchases

---

## GAME DETAIL SCREEN (shared template, `GameDetailView.swift`)

For each of the 4 paper games, same template:
- Hero header: large hand-drawn game illustration (Canvas), game name Caveat Bold 32pt
- Description paragraph: DM Sans 14pt
- **Mode selector**: "vs AI" / "Pass & Play" / "Invite Friend" — pill-style segmented control, sketch border style
- **Difficulty** (AI only): Easy / Medium / Hard — pencil-sketch pill buttons (rounded rect, no fill for unselected, inkBlue fill for selected)
- **Personal stats**: Played / Won / Win Rate / Best Streak — 2×2 grid of stat cards
- **"Start Game"** CTA: full-width, inkBlue fill, cream text, Caveat Bold 20pt, 16pt corners
- **"How to Play"** disclosure group: hand-illustrated mini rules (use SF Symbol line art + DM Sans text)

---

## DATA PERSISTENCE STRATEGY

```swift
// UserDefaults keys (simple values):
// - streak_current: Int
// - streak_longest: Int
// - streak_last_date: Date
// - session_count: Int  
// - first_launch_date: Date
// - notification_permission_asked: Bool
// - daily_challenge_dates: [String] (ISO dates of completions)
// - freeze_count: Int

// SwiftData (structured records):
// - GameResult: id, game, outcome, score, duration, date
// - Stamp: id, title, description, earnedDate?, iconName
// - SketchPage: id, title, date, pkDrawingData (PKDrawing serialized)
```

---

## BUILD ORDER (recommended for Claude Code)

Build in this sequence — each step is testable before moving to the next:

1. **Foundation**: DesignTokens, GraphPaperView, PencilLineView, SketchBorderModifier, WatercolorFill
2. **App shell**: SCRIBBLDApp, AppState, tab bar navigation structure, SplashView
3. **Home screen**: HomeView + HomeViewModel (static data first, no games yet)
4. **StoreKit**: StoreManager, SubscriptionStatus — test with sandbox
5. **Tic Tac Toe**: Full game including AI, animations, post-game transition
6. **Post-game screen**: PostGameView with all 3 CTAs and share functionality
7. **Dots & Boxes**: Full game with AI
8. **Hangman**: Full game with word bank
9. **Stop!**: Full game with timer and categories
10. **Sketching**: PencilKit canvas, brush palette, free/pro restrictions
11. **AdMob integration**: Banner + rewarded ads, ATT flow
12. **Notifications**: Daily challenge scheduler, re-engagement messages
13. **Profile / Stamps**: StampCollection, ProfileView
14. **Ink Pro upsell**: InkProView with all 3 pricing options
15. **Settings**: All toggles, restore purchases
16. **Polish pass**: All animations, haptics, accessibility labels, empty states

---

## EMPTY STATES & ERROR STATES

Every list/collection needs an empty state:
- Recent games empty: "No games yet. Pick one above and start playing." — Caveat 18pt + small pencil illustration
- Stamps empty: "Complete daily challenges to earn stamps." 
- Friends empty: "Challenge someone? Share a game link."

Error states:
- No internet (if needed): "Looks like you're offline. Games still work — we'll sync when you're back."
- StoreKit error: "Couldn't complete purchase. Check your payment method in Settings."
- Ad load failure: silently skip the ad, do not show error to user

---

## WHAT NOT TO BUILD (V1 CONSTRAINTS)

- No user accounts / sign-in
- No real-time multiplayer (deep links only for async challenges)
- No Android
- No dark mode UI (Midnight Ink is locked behind Ink Pro, implement as a full `.colorScheme(.dark)` toggle on the app window)
- No cloud backup of sketches (V1: local only)
- No leaderboards
- No social feed

---

## FINAL NOTES FOR CLAUDE CODE

- When drawing game boards, ALWAYS use SwiftUI `Canvas` or `Path` — never use grid layouts or borders to simulate drawn lines.
- Every animation should feel like ink on paper: `spring(response: 0.4, dampingFraction: 0.7)` is your default.
- Test on iPhone 14 Pro (Dynamic Island) and iPhone SE (small screen) — layouts must work on both.
- The streak number, subscription status, and daily challenge state must be correct on every cold launch.
- Build the StoreKit sandbox first with a test account before adding any real product IDs.
- Add `#Preview` macros for every view using realistic sample data.

---

*SCRIBBLD — Play like it's analog.*
