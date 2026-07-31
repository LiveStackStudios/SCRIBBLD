# SCRIBBLD — Fix Text Clipping (SCRIBBLD wordmark, STOP letter, Caveat font)
## Quick Fix Prompt for Claude Code

---

## THE PROBLEM

The Caveat font (used for SCRIBBLD wordmark, Stop! game letter display, and all hand-written headers) has characters with **glyph metrics that extend past the font's advance width** — especially `D`, `K`, `R`, and uppercase letters with right-leaning tails. SwiftUI lays out text using the advance width, which causes the right edge of these characters to get clipped.

This is happening in three confirmed places:
1. **"SCRIBBLD" wordmark** — the trailing `D` is cut off on the right edge throughout the app
2. **Stop! game letter randomizer** — all single-letter displays (especially round letters like A, B, P, R, D) are clipped on the right
3. **Any view using `.font(.custom("Caveat", ...))` with a tight frame** — the last character bleeds

---

## THE FIX (THREE LAYERS — APPLY ALL THREE)

### Layer 1: Build a `HandwrittenText` view that handles padding automatically

Create `Core/Design/HandwrittenText.swift`:

```swift
import SwiftUI

/// A text view that uses the Caveat handwritten font with proper padding
/// to prevent the right-side glyph clipping that affects letters like D, K, R.
struct HandwrittenText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = .scribbldInk
    var alignment: TextAlignment = .leading

    var body: some View {
        Text(text)
            .font(.custom("Caveat", size: size).weight(weight))
            .foregroundColor(color)
            .multilineTextAlignment(alignment)
            // Critical: extra trailing padding to give the last glyph room to render
            .padding(.trailing, size * 0.12)
            // Critical: fixedSize prevents truncation in stack layouts
            .fixedSize(horizontal: false, vertical: true)
            // Critical: minimumScaleFactor prevents clipping if the frame is constrained
            .minimumScaleFactor(0.9)
            // Critical: lineLimit nil allows the text to wrap rather than clip
            .lineLimit(nil)
    }
}

/// Centered variant for single letters (Stop! game randomizer)
struct HandwrittenLetter: View {
    let letter: String
    var size: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = .scribbldRedPen

    var body: some View {
        Text(letter)
            .font(.custom("Caveat", size: size).weight(weight))
            .foregroundColor(color)
            // Letters need horizontal padding on BOTH sides to render correctly
            // when displayed in a tight container (circle, button, etc.)
            .padding(.horizontal, size * 0.18)
            .padding(.vertical, size * 0.05)
            .fixedSize()  // Don't let parent constrain it
    }
}
```

### Layer 2: Fix the SCRIBBLD wordmark specifically

The `D` at the end is the worst offender because Caveat italicizes it. Wherever you have:

```swift
// ❌ WRONG — this clips the D
Text("SCRIBBLD")
    .font(.custom("Caveat", size: 20).weight(.bold))
    .foregroundColor(.scribbldInk)
```

Replace with:

```swift
// ✅ CORRECT
HandwrittenText(text: "SCRIBBLD", size: 20)
```

Or if you can't use the component for some reason, use this inline pattern:

```swift
Text("SCRIBBLD")
    .font(.custom("Caveat", size: 20).weight(.bold))
    .foregroundColor(.scribbldInk)
    .padding(.trailing, 3)  // Specifically for the D tail
    .fixedSize(horizontal: true, vertical: true)
```

### Layer 3: Fix the Stop! game letter randomizer

The letter circle in the Stop! game has its own special problem — it's centered inside a constrained `frame`, which forces the text into a tight bounding box.

Find the `StopGameView.swift` letter display. It probably looks something like:

```swift
// ❌ WRONG — letter gets clipped inside the circle
ZStack {
    Circle()
        .stroke(Color.scribbldRedPen, lineWidth: 2.5)
    Text(currentLetter)
        .font(.custom("Caveat", size: 38).weight(.bold))
        .foregroundColor(.scribbldRedPen)
}
.frame(width: 54, height: 54)
```

Replace with:

```swift
// ✅ CORRECT — letter has its own padding inside the circle
ZStack {
    SketchCircle(stroke: .redPen, seed: 0x444)
    HandwrittenLetter(letter: currentLetter, size: 38)
        // Counter-rotate if the parent is rotated, so text stays upright
}
.frame(width: 64, height: 64)  // Slightly bigger than before to give the letter room
```

**Two important tweaks for the letter randomizer:**
1. **Increase the container size from 54 to 64pt** — handwritten letters need more breathing room than digital ones
2. **Don't apply rotation directly to the Text** — if you want the rotated/skewed look from the mockup, wrap the entire ZStack in `.rotationEffect()`, not just the text. Rotating the text alone causes additional clipping at the rotation bounds.

---

## CODEBASE SWEEP — FIND EVERY OCCURRENCE

Run this search in the Xcode workspace and replace each occurrence:

```
Search: .font(.custom("Caveat"
```

For every result, check:
1. Is it followed by tight frame constraints (`.frame(width: ...)` or inside a `Circle()` overlay)?
2. Does the text end with a wide-glyph character (D, K, R, B, P, A in uppercase, or any italic Caveat lowercase ending)?
3. Is `.fixedSize()` or sufficient `.padding()` already applied?

If yes to #1 or #2, and no to #3 → replace with `HandwrittenText` or apply the inline padding fix.

**Common offenders to find and fix:**
- Home screen: "SCRIBBLD" top bar wordmark
- Home screen: "Good morning," greeting
- Home screen: Game card titles ("Tic Tac Toe", "Dots and Boxes", "Hangman", "Stop")
- Tic Tac Toe: "SCRIBBLD" wordmark, "PLAYER 1 (X) WINS!" status
- Hangman: "SCRIBBLD" wordmark, word display letters
- Stop!: The letter randomizer (single letter), "¡STOP!" button text, all category headers
- Post-game: "Sharp. You got them." headline
- Profile: "Profile" title, all stamp labels
- Ink Pro: "Go Unlimited with Ink Pro!" headline, pricing card numbers
- Settings: All section headers

---

## THE ROOT CAUSE EXPLAINED

Caveat is a handwriting font where many glyphs have **negative right side bearing** — meaning the visible ink of the character extends past the character's official width. This is common in:
- Script and handwriting fonts
- Italic faces
- Calligraphic display fonts

SwiftUI's text rendering uses the font's advance width (the width the cursor moves after drawing the character) to size the text frame, not the actual ink bounds. When you put such text inside a tight container, the visible ink gets clipped at the frame's right edge.

This is a known SwiftUI / iOS text-rendering quirk. The fixes:
1. **`.fixedSize()`** — tells SwiftUI not to compress the text frame to fit the parent
2. **Trailing padding** — adds explicit room for the overflow ink
3. **`.padding(.horizontal, size * 0.18)`** — for centered single letters, pad both sides proportionally to the font size

---

## VERIFICATION

After applying fixes, test these specific screens on a small device (iPhone SE or iPhone 13 mini in simulator — the constraints are tightest):

1. **Home screen**: "SCRIBBLD" in the top bar — the `D` should have visible breathing room on its right edge, no character cut off
2. **Stop! game**: Cycle through letters A through Z in the randomizer — every single letter, especially `D`, `R`, `K`, `B`, `P`, should render completely with their tails/curves intact
3. **Tic Tac Toe**: "PLAYER 1 (X) WINS!" — the exclamation mark should be fully visible, no clipping
4. **Hangman**: When the word is revealed at end of game, each letter in the word display should render fully

**Test in both portrait orientations and with Dynamic Type at the largest setting** — that's when clipping becomes most obvious.

---

## ONE-LINE EMERGENCY FIX

If for some reason you need a quick-and-dirty fix without refactoring components, this single modifier added to any Caveat text will prevent clipping in 95% of cases:

```swift
.padding(.trailing, 4)
.fixedSize(horizontal: true, vertical: true)
```

But the proper fix is to use `HandwrittenText` and `HandwrittenLetter` consistently — apply Layer 1, then sweep the codebase to migrate every Caveat usage.

---

## DO NOT

- ❌ Don't change the Caveat font to a different font. The handwriting feel IS the design.
- ❌ Don't reduce the font size to make it fit — fix the padding instead.
- ❌ Don't use `.lineLimit(1)` with `.truncationMode(.tail)` to hide the problem — that just confirms the clip rather than fixing it.
- ❌ Don't apply `.frame(width:)` to handwritten text without also adding trailing padding.

The fix is padding and `.fixedSize()`. Apply both layers, then sweep the codebase.
