# SCRIBBLD — Hand-Drawn Rendering System
## Claude Code Prompt: Make Every Stroke Feel Like Real Pencil on Paper

---

## THE CORE PROBLEM

The current SCRIBBLD UI uses clean digital lines, perfect circles, and Bezier curves rendered with `stroke-width: 2pt` straight paths. That looks like an app. The reference mockups look like **someone actually drew the app in a sketchbook**.

Your job: build a reusable rendering system in SwiftUI so that **every line, border, icon, and game element in SCRIBBLD looks hand-drawn with a pencil or ink pen**. This is the difference between "looks nice" and "people will tell their friends about it."

Reference images are at `/mnt/user-data/uploads/SCRIBBLD_*.png` — open them and study every stroke before writing code.

---

## WHAT "HAND-DRAWN" ACTUALLY MEANS (TECHNICAL BREAKDOWN)

Study the references and you'll see these specific qualities in every stroke:

### 1. Stroke imperfection
- Lines are **never perfectly straight** — they wobble slightly along their length
- Endpoints are **slightly past or short** of where they "should" end (overshoot/undershoot 1–3pt)
- Two parallel lines drawn by a human are never the exact same length or perfectly parallel
- Corners don't meet cleanly — they cross over each other slightly, like a sketch

### 2. Stroke variation
- Pressure varies along the stroke: heavier at start, lighter at middle, sometimes heavier at end
- Width oscillates ±0.5pt along the path
- Opacity varies subtly — denser where the pencil pressed harder

### 3. Stroke texture
- Edges are **not smooth anti-aliased lines** — they have slight roughness
- Pencil strokes show graphite grain
- Pen strokes have ink bleed at corners and slow points

### 4. Multiple overlapping strokes
- A "rectangle" in a sketchbook is often drawn with 2 or 3 short strokes per side, not one long line
- Circles are often drawn with 2 overlapping arcs that don't quite close
- Filled areas use cross-hatching, not solid fills

### 5. The wash effect (for filled areas)
- Watercolor washes have soft, irregular edges that bleed past the line
- Density varies — pooling in some spots, lighter in others
- The wash is **behind** the line, often slightly offset from it

---

## THE RENDERING SYSTEM TO BUILD

### File: `Core/Design/HandDrawn.swift`

Build a namespace with helpers for every primitive shape. All take a `seed: UInt64` parameter so the "randomness" is deterministic per element (the same line redraws the same way every frame — only changes when you want it to).

```swift
import SwiftUI

enum HandDrawn {
    // MARK: - Stroke Styles
    enum StrokeStyle {
        case pencil       // Graphite — soft, textured, grayish
        case inkPen       // Ballpoint — confident, slight bleed
        case fountainPen  // Variable width, expressive
        case marker       // Thick, slightly fuzzy edges
        case redPen       // Sharp red, for corrections and emphasis
    }

    // MARK: - Hand-drawn line between two points
    static func line(
        from: CGPoint,
        to: CGPoint,
        style: StrokeStyle = .inkPen,
        seed: UInt64 = 0
    ) -> some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: seed)
            let path = wobblyPath(from: from, to: to, rng: &rng)
            drawStrokedPath(path, style: style, context: context, rng: &rng)
        }
    }

    // MARK: - Hand-drawn rectangle (the sketch-border modifier)
    static func rectangle(
        in rect: CGRect,
        style: StrokeStyle = .inkPen,
        cornerStyle: CornerStyle = .crossover,
        seed: UInt64 = 0
    ) -> some View { /* ... */ }

    // MARK: - Hand-drawn circle (two overlapping arcs)
    static func circle(
        in rect: CGRect,
        style: StrokeStyle = .inkPen,
        seed: UInt64 = 0
    ) -> some View { /* ... */ }

    // MARK: - Watercolor wash (irregular filled area)
    static func wash(
        in path: Path,
        color: Color,
        intensity: Double = 0.3,
        seed: UInt64 = 0
    ) -> some View { /* ... */ }
}
```

### Core algorithm: the wobbly path

This is the most important function. Every other shape uses it:

```swift
private static func wobblyPath(
    from: CGPoint,
    to: CGPoint,
    rng: inout SeededRandom,
    wobble: CGFloat = 1.5,        // max deviation in pts
    segmentLength: CGFloat = 8     // sample every N pts
) -> Path {
    var path = Path()
    let dx = to.x - from.x
    let dy = to.y - from.y
    let length = sqrt(dx*dx + dy*dy)
    let segments = max(2, Int(length / segmentLength))

    // Overshoot/undershoot the start and end (±2pt)
    let startOffset = rng.next(-2, 2)
    let endOffset = rng.next(-2, 2)
    let ux = dx / length
    let uy = dy / length

    // Perpendicular vector for wobble
    let px = -uy
    let py = ux

    var points: [CGPoint] = []
    for i in 0...segments {
        let t = CGFloat(i) / CGFloat(segments)
        let lineX = from.x + dx * t
        let lineY = from.y + dy * t

        // Smooth wobble — use sin curve modulated by random
        let wobbleAmount = wobble * sin(t * .pi * (1 + rng.next(0, 2)))
                         * rng.next(0.5, 1.0)

        let x = lineX + px * wobbleAmount
        let y = lineY + py * wobbleAmount
        points.append(CGPoint(x: x, y: y))
    }

    // Apply overshoot to endpoints
    points[0].x += ux * startOffset
    points[0].y += uy * startOffset
    points[points.count - 1].x += ux * endOffset
    points[points.count - 1].y += uy * endOffset

    // Build path with smooth curves between sample points
    path.move(to: points[0])
    for i in 1..<points.count {
        let p1 = points[i-1]
        let p2 = points[i]
        let mid = CGPoint(x: (p1.x+p2.x)/2, y: (p1.y+p2.y)/2)
        path.addQuadCurve(to: mid, control: p1)
    }
    path.addLine(to: points.last!)

    return path
}
```

### Drawing the stroke with variable width

```swift
private static func drawStrokedPath(
    _ path: Path,
    style: StrokeStyle,
    context: GraphicsContext,
    rng: inout SeededRandom
) {
    let baseWidth: CGFloat
    let baseOpacity: Double
    let color: Color

    switch style {
    case .pencil:
        baseWidth = 1.8
        baseOpacity = 0.78
        color = Color(hex: "#2A2A2A")  // graphite, not pure black
    case .inkPen:
        baseWidth = 2.0
        baseOpacity = 0.92
        color = Color(hex: "#1A365D")  // ink blue
    case .fountainPen:
        baseWidth = 2.4
        baseOpacity = 0.95
        color = Color(hex: "#1A365D")
    case .marker:
        baseWidth = 3.2
        baseOpacity = 0.85
        color = Color(hex: "#1A365D")
    case .redPen:
        baseWidth = 2.2
        baseOpacity = 0.90
        color = Color(hex: "#C53030")
    }

    // Draw the main stroke
    context.stroke(
        path,
        with: .color(color.opacity(baseOpacity)),
        style: StrokeStyle(
            lineWidth: baseWidth,
            lineCap: .round,
            lineJoin: .round
        )
    )

    // For pencil: add a second lighter stroke offset slightly to simulate grain
    if style == .pencil {
        var offsetPath = path
        offsetPath = offsetPath.applying(
            CGAffineTransform(translationX: rng.next(-0.5, 0.5),
                              y: rng.next(-0.5, 0.5))
        )
        context.stroke(
            offsetPath,
            with: .color(color.opacity(0.35)),
            style: StrokeStyle(lineWidth: baseWidth * 0.6, lineCap: .round)
        )
    }

    // For ink pen: add tiny ink-bleed circles at endpoints
    if style == .inkPen || style == .fountainPen {
        if let first = path.cgPath.allPoints.first,
           let last = path.cgPath.allPoints.last {
            let bleedRadius = rng.next(0.5, 1.2)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: first.x - bleedRadius,
                    y: first.y - bleedRadius,
                    width: bleedRadius * 2,
                    height: bleedRadius * 2
                )),
                with: .color(color.opacity(0.6))
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: last.x - bleedRadius,
                    y: last.y - bleedRadius,
                    width: bleedRadius * 2,
                    height: bleedRadius * 2
                )),
                with: .color(color.opacity(0.6))
            )
        }
    }
}
```

### Seeded random (deterministic per-element)

```swift
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let normalized = CGFloat(state >> 33) / CGFloat(UInt32.max)
        return min + normalized * (max - min)
    }
}
```

---

## SHAPES TO BUILD (USE THE WOBBLY-LINE PRIMITIVE)

### 1. Hand-drawn rectangle (used for cards, borders, buttons)
- 4 sides, each its own wobbly line
- Corners use one of three styles:
  - `.crossover`: lines extend past corner 2–4pt (sketch style — DEFAULT for game cards on home screen)
  - `.closed`: lines meet at corner with slight gap (0.5–1.5pt)
  - `.rounded`: short curved segment connects sides (for buttons)

### 2. Hand-drawn circle (Hangman head, dots in Dots & Boxes, stamps)
- Draw as TWO arcs, each starting/ending at slightly different angles
- Arc 1: from -10° to 175° (top half + a bit)
- Arc 2: from 170° to 360° + random offset (bottom half + overlap)
- The arcs overlap slightly at top, don't quite close at bottom — exactly how humans draw circles

### 3. Tally marks (used in score displays — see TTT and Dots & Boxes mockups)
- 4 vertical strokes, each `wobblyLine` from top to bottom of bounds
- 5th stroke: diagonal `wobblyLine` crossing all 4
- Each stroke has slightly different start/end positions
- Group of 5 = "cluster" — multiple clusters with small gap between them

### 4. The X mark (Tic Tac Toe)
- Two diagonal `wobblyLine` strokes
- Each stroke uses `.inkPen` style with blue color
- The two strokes don't meet exactly at center — crossing point is 1–2pt off
- Drawn with `trim(from:to:)` animation: first stroke 0→1, then second stroke 0→1
- Animation duration: 0.18s + 0.18s = 0.36s total

### 5. The O mark (Tic Tac Toe)
- Single `wobblyCircle` in red-pen style
- Starts and ends near the top, with overshoot — the start of the stroke crosses past the end
- Animated with `trim(from:to:)` over 0.30s — feels like watching someone draw it

### 6. Hashed/cross-hatched fill (Hangman gallows, mockup shows this)
- Inside a rectangular area, draw 8–15 parallel diagonal lines
- Each line is a `wobblyLine` in pencil style
- Lines at ~45° angle, spaced 4–6pt apart
- Some lines start before the boundary, some end before — irregular

### 7. The watercolor wash (Dots & Boxes box fills, TTT win splash, post-game)
- Generate 3–5 overlapping `Ellipse` paths
- Each ellipse: slightly different center (±8pt), slightly different scale (0.8x–1.2x)
- Each ellipse: opacity 0.12–0.25, color from the wash palette
- Render in order: largest/lightest first, smaller/darker on top
- For an extra detail: add 1–2 tiny darker "pooling" spots near the edges

### 8. The strikethrough (Hangman wrong letters)
- A single `wobblyLine` from upper-left to lower-right of the letter's bounding box
- In red-pen style
- Slight extension past both ends of the letter

### 9. The graph paper grid
- Horizontal lines every 24pt, vertical lines every 24pt
- Use `wobblyLine` with very low wobble (0.3pt) and pencil style at opacity 0.18
- This is the canonical SCRIBBLD background — appears under almost everything

### 10. Notebook lines (Hangman, Stop! screens)
- Horizontal lines every 28pt at opacity 0.4 in grid-gray
- Red vertical margin line at x = 36pt at opacity 0.3 in red-pen

---

## VIEW MODIFIERS TO MAKE EVERYTHING USE THIS

### `.handDrawnBorder(style:cornerStyle:)`

Replaces every use of `.border()` and `.overlay(RoundedRectangle...)` in the codebase:

```swift
extension View {
    func handDrawnBorder(
        style: HandDrawn.StrokeStyle = .inkPen,
        cornerStyle: HandDrawn.CornerStyle = .crossover,
        cornerRadius: CGFloat = 0,
        seed: UInt64 = 0
    ) -> some View {
        self.overlay(
            GeometryReader { geo in
                HandDrawn.rectangle(
                    in: CGRect(origin: .zero, size: geo.size),
                    style: style,
                    cornerStyle: cornerStyle,
                    seed: seed
                )
            }
        )
    }
}
```

### `.paperBackground()`

```swift
extension View {
    func paperBackground(_ kind: PaperKind = .graph) -> some View {
        self.background(
            PaperBackgroundView(kind: kind)
                .allowsHitTesting(false)
        )
    }
}

enum PaperKind {
    case graph      // Square grid (default for most screens)
    case lined      // Horizontal lines (Hangman, Stop!)
    case dotted     // Bullet-journal style
    case blank      // Just cream, no pattern
}
```

### `.handDrawnButton()`

```swift
extension View {
    func handDrawnButton(
        fill: Color = .clear,
        stroke: HandDrawn.StrokeStyle = .inkPen,
        seed: UInt64 = 0
    ) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(fill)
            .handDrawnBorder(style: stroke, cornerStyle: .rounded, seed: seed)
    }
}
```

### `.handWritten(font:size:weight:)`

For all text that should look written rather than typed:

```swift
extension View {
    func handWritten(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        self.font(.custom("Caveat", size: size).weight(weight))
            .foregroundColor(Color(hex: "#1A365D"))
    }

    func typed(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.custom("DMSans", size: size).weight(weight))
    }
}
```

---

## STABLE SEEDS — CRITICAL

If you regenerate the "randomness" every frame, the lines wobble and animate — which looks broken. Every hand-drawn element needs a STABLE seed that's tied to its identity:

```swift
struct GameCard: View {
    let game: Game
    var body: some View {
        VStack { /* content */ }
            .handDrawnBorder(seed: game.id.uuidString.stableSeed)
    }
}

extension String {
    var stableSeed: UInt64 {
        var hash: UInt64 = 5381
        for byte in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }
}
```

**Rules**:
- Static UI element (border, divider) → seed from view position or a constant per-view
- Game state element (a placed X, a drawn line) → seed from that element's ID
- Animated draw-in (drawing an X) → seed is stable, only the `trim` animates

---

## ACROSS THE APP — WHERE TO APPLY THIS

### Home screen (`HomeView.swift`)
- The 4 game cards: each gets `.handDrawnBorder()` with a per-card stable seed
- The illustrations inside each card: rebuild as hand-drawn primitives (not SF Symbols, not emoji)
  - Tic Tac Toe card: 3×3 of `wobblyLine` plus some X's and O's drawn in
  - Dots & Boxes card: small grid of `circle` dots, some `wobblyLine` connections, one watercolor wash
  - Hangman card: simplified gallows + stick figure, all from `wobblyLine`
  - Stop! card: the octagonal STOP sign drawn as 8 wobbly lines
- Daily Challenge card border: red-pen style, dashed wobbly outline

### Tic Tac Toe (`TicTacToeView.swift`)
- The 3×3 grid: 2 horizontal + 2 vertical `wobblyLine`s in pencil style — NOT a `Grid`/`HStack` with borders
- X marks: hand-drawn X primitive in `.inkPen` blue
- O marks: hand-drawn circle in `.redPen`
- Winning line strikethrough: thick `wobblyLine` in `.redPen` style, animated trim 0→1 over 0.5s
- Tally marks for scoreboard: use the tally mark primitive
- The "Player 1 (X) Wins!" text: handWritten 24pt
- Watercolor splash behind win: 3 overlapping wash ellipses in pale red

### Hangman (`HangmanView.swift`)
- Notebook background: `paperBackground(.lined)`
- Gallows: 4 separate `wobblyLine`s drawn in `.inkPen` blue, each animated in sequence as guesses are wrong
- The hashed shading on gallows base + top: cross-hatched fill primitive
- Stick figure: head as hand-drawn circle, body/limbs as `wobblyLine`s
- Word display underscores: `wobblyLine` segments under each letter slot
- Wrong letters with strikethrough: text + the strikethrough primitive
- Keyboard keys: each key gets `.handDrawnBorder(cornerStyle: .closed)` with a unique seed

### Dots & Boxes (`DotsAndBoxesView.swift`)
- Dot grid: 8×8 of hand-drawn circles (use `.pencil` style at small radius)
- Drawn edges: `wobblyLine` between dots, `.inkPen` blue for player, `.redPen` for opponent
- Completed boxes: watercolor wash inside the square + the "ME" / "T" / "P" text labels handWritten 12pt
- The pencil cursor following finger: small hand-drawn pencil icon
- Score tally marks: tally mark primitive (see how they look in the mockup — that exact style)
- "END GAME" button: handDrawnButton with crossover corners

### Stop! (`StopGameView.swift`)
- Letter circle: hand-drawn circle in red-pen, with the inner dashed circle as 12 short `wobblyLine` segments around the perimeter
- The table grid: every line in the table is a `wobblyLine`, not a 1pt rectangle border
- The STOP! button: handDrawnButton with rounded corners, marker stroke style, red fill
- Player progress dots: hand-drawn circles

### Sketching (`SketchingView.swift`)
- The brush style icons: hand-drawn primitives showing each brush
- Color palette circles: hand-drawn circle borders around each color
- The canvas itself uses PencilKit (real Apple Pencil/finger drawing) — no wobble needed there since the user IS drawing
- All UI chrome around it: hand-drawn

### Profile / Stats (`ProfileView.swift`)
- Stamp borders: hand-drawn rectangles with serrated edges (alternating short `wobblyLine` segments along each side)
- Sparkline charts: built from `wobblyLine` segments between data points
- The user avatar circle: hand-drawn circle with the initials inside
- "Profile" title underline: a single `wobblyLine` in red-pen below the text

### Ink Pro / Premium (`InkProView.swift`)
- The Ink Pro seal/stamp: hand-drawn double circle (outer ring + inner ring), with rotated text around the perimeter
- The Membership Card: hand-drawn rectangle with the LEFT side being a perforated edge (small `wobblyLine` segments perpendicular to the side)
- The pricing cards (1 month, 12 months, Forever): each is a hand-drawn rectangle, the 12 months one gets a red-pen star drawn at the top
- Checkmarks in the feature list: hand-drawn checkmark primitive (two short `wobblyLine`s)

---

## PERFORMANCE NOTES

- A full SwiftUI `Canvas` redraw can be expensive. For static elements (borders, backgrounds), wrap in `.drawingGroup()` so Metal caches the rasterization
- Don't put the wobbly path generation inside `body` — compute it once in `onAppear` and store as `@State`
- For game elements that animate (X being drawn), use `TimelineView` + `Canvas` together so the trim animation is GPU-accelerated
- The graph paper background should be rendered ONCE per app launch and cached as an image — it's identical every frame

```swift
struct CachedPaperBackground: View {
    static let image = ImageRenderer(content: PaperBackgroundCanvas()).cgImage
    var body: some View {
        Image(decorative: Self.image!, scale: UIScreen.main.scale)
    }
}
```

---

## ANIMATION DETAILS

When a hand-drawn element appears for the first time, it should **draw itself in** — not just fade in:

```swift
struct DrawingX: View {
    @State private var firstStrokeProgress: CGFloat = 0
    @State private var secondStrokeProgress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            // First diagonal stroke (top-left to bottom-right)
            let path1 = HandDrawn.wobblyPath(/* ... */)
            context.stroke(
                path1.trimmedPath(from: 0, to: firstStrokeProgress),
                with: .color(.inkBlue),
                lineWidth: 3
            )
            // Second diagonal (top-right to bottom-left)
            let path2 = HandDrawn.wobblyPath(/* ... */)
            context.stroke(
                path2.trimmedPath(from: 0, to: secondStrokeProgress),
                with: .color(.inkBlue),
                lineWidth: 3
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                firstStrokeProgress = 1
            }
            withAnimation(.easeOut(duration: 0.18).delay(0.18)) {
                secondStrokeProgress = 1
            }
        }
    }
}
```

Each game piece has its own draw-in animation:
- **X (TTT)**: 2 strokes, 0.36s total
- **O (TTT)**: 1 stroke, 0.30s, slight start-overshoot
- **Dots & Boxes line**: 1 stroke, 0.20s
- **Hangman body part**: 1 stroke per part, 0.4s each, sequenced
- **Watercolor wash**: fades in over 0.6s with slight scale (0.85 → 1.0)
- **Tally mark added to score**: 0.15s draw-in per stroke
- **Win-line strikethrough**: 0.5s, thicker stroke than usual

---

## ACCEPTANCE CRITERIA

The system is done when:

1. **Side-by-side test**: place a screenshot of the running app next to the reference mockup at `/mnt/user-data/uploads/SCRIBBLD_-_Tic_Tac_Toe.png` — they should look like they came from the same designer
2. **The "could a human have drawn this?" test**: every single line, border, circle, and shape on every screen passes this test
3. **The deterministic test**: open the app, take a screenshot, force-quit, reopen, take another screenshot — the wobbles should be identical (stable seeds working)
4. **The animation test**: every game piece draws itself in stroke-by-stroke, not fade-in
5. **The performance test**: scrolling the home screen at 120fps on iPhone 15 Pro stays at 120fps (no jank from rendering wobbly lines)
6. **The "no perfect lines" audit**: search the codebase for `Rectangle()`, `RoundedRectangle`, `.border(`, `Circle()` outside of `HandDrawn.*` — every result should be intentional (e.g., status bar) or should be converted
7. **Accessibility**: turning on Reduce Motion shows the lines without the draw-in animation (just appear instantly), but they're still hand-drawn

---

## REFERENCE — WHAT NOT TO DO

These are common mistakes that will make it look wrong:

- ❌ **Don't use SF Symbols for game illustrations** — they look like icons, not sketches. Build illustrations from `wobblyLine` primitives.
- ❌ **Don't use SwiftUI's `.stroke(StrokeStyle(dash:))`** for dashed lines — the dashes are perfectly even and look digital. Instead, draw dashes as individual short `wobblyLine` segments with random small gaps.
- ❌ **Don't use a single random offset for an entire stroke** — the wobble must vary ALONG the stroke length, not just shift the whole thing.
- ❌ **Don't make every stroke equally wobbly** — major structural lines (game card borders) should have less wobble than expressive lines (a drawn X). Use `wobble: 0.8` for structure, `wobble: 2.5` for expressive.
- ❌ **Don't forget the endpoints** — overshoot/undershoot is what sells the hand-drawn look more than the wobble itself. Without it, lines look "shaky" instead of "sketched."
- ❌ **Don't render at high contrast** — pure black on pure white looks digital. Use `#1A365D` (ink blue) on `#FEFCF3` (cream). Soften everything 10–15%.
- ❌ **Don't use `lineCap: .square`** — always `.round` for pencil/pen feel.

---

## REFERENCE — THE STROKE STYLE PALETTE

| Style | Color | Width | Opacity | Texture | Used For |
|---|---|---|---|---|---|
| `.pencil` | `#2A2A2A` graphite | 1.8pt | 0.78 | Grain (2nd offset stroke) | Grid lines, structural borders, secondary UI |
| `.inkPen` | `#1A365D` ink blue | 2.0pt | 0.92 | Endpoint bleed | Primary borders, X marks, gallows, most text borders |
| `.fountainPen` | `#1A365D` ink blue | 2.4pt variable | 0.95 | Endpoint bleed, varying width | Calligraphic text underlines, Profile title |
| `.marker` | `#1A365D` ink blue | 3.2pt | 0.85 | Fuzzy edges | STOP! button, primary CTAs |
| `.redPen` | `#C53030` red | 2.2pt | 0.90 | Endpoint bleed | O marks, win strikethrough, daily challenge border, corrections |

---

## BUILD ORDER

1. **Foundation**: `HandDrawn.swift` with `wobblyPath`, `SeededRandom`, all stroke styles, `line()`, `rectangle()`, `circle()`
2. **Modifiers**: `.handDrawnBorder()`, `.paperBackground()`, `.handDrawnButton()`, `.handWritten()`
3. **Primitives**: tally mark, X mark, O mark, strikethrough, cross-hatch fill, watercolor wash, checkmark
4. **Test screen**: build a `HandDrawnPreviewView` that shows every primitive in isolation — verify visually that each one looks right BEFORE applying across the app
5. **Migration**: go screen by screen — Home → TTT → Hangman → Dots & Boxes → Stop! → Sketching → Profile → InkPro — and replace every digital line/border/shape with the hand-drawn equivalent
6. **Animation pass**: add draw-in animations to every game piece
7. **Performance pass**: add `.drawingGroup()`, cache backgrounds, profile with Instruments
8. **Accessibility pass**: respect Reduce Motion, ensure VoiceOver still works through Canvas-drawn elements

---

## NOTE TO CLAUDE CODE

Before you write a single line of code, do this:

1. Open all 6 reference images in `/mnt/user-data/uploads/SCRIBBLD_*.png`
2. Zoom in on the actual strokes — look at how the lines aren't straight, how corners cross over, how the watercolor washes have irregular edges
3. Build the `HandDrawnPreviewView` test screen FIRST and show me screenshots before migrating any real screens
4. Tune the wobble/overshoot/opacity values until the preview looks like the references — this is the key calibration
5. Only then start migrating the actual game screens

The goal isn't "an app that has hand-drawn elements." The goal is "an app that looks like someone drew it in a sketchbook." Every shortcut you take here will be visible.

---

*"Play like it's analog."* — every pixel must earn that tagline.
