import SwiftUI
import PencilKit
import UIKit
import Photos

struct SketchingView: View {
    @EnvironmentObject private var store: StoreManager
    @State private var drawing = PKDrawing()
    @State private var canvasView = PKCanvasView()
    @State private var brush: SketchBrush = .pencil
    @State private var paletteColor: SketchPaletteColor = .deepInkBlue
    @State private var brushWidth: CGFloat = 4
    @State private var isErasing: Bool = false
    @State private var presentLockedSheet = false
    @State private var lockedKey: String?
    /// Localized display name of whatever the user just tapped, shown in the
    /// unlock sheet alongside `lockedKey` (which stays the entitlement key).
    @State private var lockedTitle: String = ""
    @State private var title: String = ""
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }
    @State private var presentPaywall = false
    @State private var presentLayersSheet = false
    @State private var presentSettings = false
    @State private var saveToast: String?

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.18).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                topBar
                Divider().background(Color.inkBlue.opacity(0.4))
                titleRow

                brushSection
                colorSection
                canvasSection
                bottomToolbar
                BannerAdView(adUnitID: AdConfig.Banner.sketch)
            }
            .padding(.horizontal, Spacing.lg)

            if let saveToast {
                Text(saveToast)
                    .font(.dmSans(14, weight: .semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(Color.inkBlue)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 80)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .sheet(isPresented: $presentLockedSheet) {
            LockedFeatureSheet(featureName: lockedTitle, onUnlock: {
                if let key = lockedKey {
                    store.unlockForSession(key)
                    applyTool()
                }
                presentLockedSheet = false
            }, onPaywall: {
                presentLockedSheet = false
                presentPaywall = true
            })
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $presentPaywall) {
            InkProView().environmentObject(store)
        }
        .sheet(isPresented: $presentLayersSheet) {
            LayersSheet(onUpgrade: {
                presentLayersSheet = false
                presentPaywall = true
            })
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $presentSettings) {
            SketchSettingsSheet(brushWidth: $brushWidth, isErasing: $isErasing)
                .presentationDetents([.medium])
        }
        .onChange(of: brush) { _, _ in isErasing = false; applyTool() }
        .onChange(of: paletteColor) { _, _ in applyTool() }
        .onChange(of: brushWidth) { _, _ in applyTool() }
        .onAppear { applyTool() }
    }

    /// Matches the in-game top bars (Hangman / Stop! / TTT): wordmark and a
    /// tool glyph on the left, nothing on the right. The old centered
    /// wordmark + magnifying glass didn't match anything and the glass was a
    /// dead control — there is no search in Sketching.
    private var topBar: some View {
        HStack(spacing: 4) {
            ScribbldWordmark(size: 24)
            Image(systemName: "pencil.tip")
                .foregroundStyle(Color.inkBlue)
            Spacer()
        }
    }

    private var titleRow: some View {
        Text(language == .spanish ? "Dibujo Libre" : "Sketching")
            .font(.caveat(28, weight: .bold))
            .foregroundStyle(Color.inkBlue)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brushSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .spanish ? "Estilos de Pincel" : "Brush Styles")
                .font(.caveat(22, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(SketchBrush.allCases) { b in
                        BrushChip(brush: b, selected: brush == b && !isErasing,
                                  locked: !b.isFree && !store.isUnlocked("brush.\(b.rawValue)")) {
                            if b.isFree || store.isUnlocked("brush.\(b.rawValue)") {
                                brush = b
                                HapticEngine.light()
                            } else {
                                lockedKey = "brush.\(b.rawValue)"
                                lockedTitle = b.title(in: language)
                                presentLockedSheet = true
                            }
                        }
                    }
                }
                // Vertical padding gives the lock badge room to sit
                // at its offset position (~14pt above the chip's natural
                // top edge for a 16pt lock circle at offset -6) without
                // being clipped by the ScrollView. Trailing padding
                // makes the last chip easy to reach.
                .padding(.top, 16)
                .padding(.bottom, 4)
                .padding(.trailing, Spacing.lg)
            }
            // Soft fade on the right edge as a visual hint that there
            // are more chips to scroll to.
            .mask(scrollFadeMask)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .spanish ? "Paleta de Colores" : "Color Palette")
                .font(.caveat(22, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(SketchPaletteColor.allCases) { c in
                        ColorSwatch(color: c, selected: paletteColor == c,
                                    locked: !c.isFree && !store.isUnlocked("color.\(c.rawValue)")) {
                            if c.isFree || store.isUnlocked("color.\(c.rawValue)") {
                                paletteColor = c
                                HapticEngine.light()
                            } else {
                                lockedKey = "color.\(c.rawValue)"
                                // Swatch titles carry a hard wrap for the
                                // two-line label slot; flatten it for prose.
                                lockedTitle = c.title(in: language)
                                    .replacingOccurrences(of: "\n", with: " ")
                                presentLockedSheet = true
                            }
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 4)
                .padding(.trailing, Spacing.lg)
            }
            .mask(scrollFadeMask)
        }
    }

    /// Horizontal linear gradient that fades to clear at the right edge.
    /// Used as a `.mask` over the brush + color scroll views so the
    /// hidden overflow content fades naturally instead of being
    /// abruptly clipped at the screen edge.
    private var scrollFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black,            location: 0.0),
                .init(color: .black,            location: 0.85),
                .init(color: .black.opacity(0), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(language == .spanish ? "Título del boceto" : "Sketch title", text: $title)
                    .font(.caveat(20, weight: .bold))
                    .padding(.trailing, 5)
                    .foregroundStyle(Color.inkBlue)
                    .submitLabel(.done)
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits)))
                    .font(.dmSans(11))
                    .foregroundStyle(Color.softGray)
            }
            ZStack {
                Color.white.opacity(0.6)
                GraphPaperView(lineOpacity: 0.18).clipShape(RoundedRectangle(cornerRadius: 6))
                SketchCanvas(drawing: $drawing, tool: currentTool, canvasView: $canvasView)
            }
            .frame(minHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .sketchBorder(color: .inkBlue.opacity(0.5), lineWidth: 1, cornerRadius: 8, jitter: 0.6, seed: 17)
        }
    }

    private var bottomToolbar: some View {
        let es = language == .spanish
        return HStack(spacing: 12) {
            toolbarIcon("eraser", label: es ? "Borrador" : "Eraser", active: isErasing) {
                isErasing.toggle()
                applyTool()
            }
            toolbarIcon("arrow.uturn.backward", label: es ? "Deshacer" : "Undo") {
                canvasView.undoManager?.undo()
            }
            toolbarIcon("arrow.uturn.forward", label: es ? "Rehacer" : "Redo") {
                canvasView.undoManager?.redo()
            }
            toolbarIcon("plus.magnifyingglass", label: es ? "Zoom" : "Zoom") {
                cycleZoom()
            }
            toolbarIcon("square.stack.3d.up", label: es ? "Capas" : "Layers") {
                presentLayersSheet = true
            }
            toolbarIcon("tray.and.arrow.down", label: es ? "Guardar" : "Save") {
                Task { await saveSketch() }
            }
            toolbarIcon("gearshape", label: es ? "Ajustes del pincel" : "Brush settings") {
                presentSettings = true
            }
        }
        .padding(.vertical, 8)
    }

    private func toolbarIcon(
        _ name: String,
        label: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: { HapticEngine.light(); action() }) {
            Image(systemName: name)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(active ? Color.cream : Color.inkBlue)
                .frame(width: 36, height: 36)
                .background {
                    if active {
                        PencilFilledSurface(color: .inkBlue, cornerRadius: 18, seed: 91, pressed: false)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .overlay(Circle().stroke(Color.inkBlue.opacity(0.4), lineWidth: 0.8))
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var currentTool: PKTool {
        if isErasing { return PKEraserTool(.bitmap) }
        return brush.tool(color: UIColor(paletteColor.color), width: brushWidth)
    }

    private func applyTool() {
        canvasView.tool = currentTool
    }

    private func cycleZoom() {
        let next = canvasView.zoomScale >= 2 ? 1.0 : canvasView.zoomScale + 0.5
        canvasView.setZoomScale(next, animated: true)
    }

    @MainActor
    private func saveSketch() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let authorized: Bool
        switch status {
        case .authorized, .limited: authorized = true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            authorized = (newStatus == .authorized || newStatus == .limited)
        default: authorized = false
        }
        let es = language == .spanish
        guard authorized else {
            showToast(es ? "Acceso a Fotos denegado" : "Photo access denied")
            return
        }
        let bounds = canvasView.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 1024, height: 1024)
            : canvasView.bounds
        let image = canvasView.drawing.image(from: bounds, scale: UIScreen.main.scale)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }
            showToast(es ? "Guardado en Fotos" : "Saved to Photos")
            HapticEngine.success()
        } catch {
            showToast((es ? "No se pudo guardar: " : "Couldn't save: ") + error.localizedDescription)
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            saveToast = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { saveToast = nil }
        }
    }
}

struct BrushChip: View {
    let brush: SketchBrush
    let selected: Bool
    let locked: Bool
    let action: () -> Void
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }

    private var seed: UInt64 { UInt64(abs(brush.rawValue.hashValue) & 0xFFFF) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Selected chips use the same colored-in surface as the
                    // segmented pickers elsewhere in the app, so "this one is
                    // active" reads identically everywhere.
                    Group {
                        if selected {
                            brush.strokePreview(color: .cream)
                                .frame(width: 56, height: 56)
                                .pencilFill(color: .inkBlue, cornerRadius: 8, seed: seed)
                        } else {
                            brush.strokePreview(color: .inkBlue)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.7))
                                .sketchBorder(color: .lightLine, lineWidth: 1.4, cornerRadius: 8, jitter: 0.5, seed: seed)
                        }
                    }
                    .opacity(locked ? 0.55 : 1)
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.white)
                            .padding(3).background(Color.inkBlue).clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
                Text(brush.title(in: language))
                    .font(.dmSans(11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.inkBlue : Color.softGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }
}

struct ColorSwatch: View {
    let color: SketchPaletteColor
    let selected: Bool
    let locked: Bool
    let action: () -> Void
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // A hand-drawn ring rather than a geometric stroke, and a
                    // second outer ring when selected — the swatch itself has
                    // to stay a clean circle of the actual ink color, so
                    // selection reads through the ring, not a fill.
                    SketchCircle(seed: UInt64(abs(color.rawValue.hashValue) & 0xFFFF))
                        .stroke(
                            Color.inkBlue.opacity(selected ? 1 : 0.35),
                            lineWidth: selected ? 2.2 : 1
                        )
                        .frame(width: selected ? 46 : 42, height: selected ? 46 : 42)
                        .overlay {
                            Circle()
                                .fill(color.color)
                                .frame(width: 34, height: 34)
                        }
                        .opacity(locked ? 0.55 : 1)
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.white)
                            .padding(3).background(Color.inkBlue).clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(height: 48)
                Text(color.title(in: language))
                    .font(.dmSans(10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.inkBlue : Color.softGray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }
}

struct LockedFeatureSheet: View {
    /// Already-localized display name (e.g. "Carboncillo"), not the raw
    /// "brush.carbon" key — deriving a label by capitalizing the key produced
    /// English-only, sometimes mangled, titles.
    let featureName: String
    let onUnlock: () -> Void
    let onPaywall: () -> Void
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }

    var body: some View {
        let es = language == .spanish
        VStack(spacing: 16) {
            Text(es ? "\(featureName) es de Ink Pro" : "\(featureName) is Ink Pro")
                .font(.caveat(28, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .multilineTextAlignment(.center)
            Text(es
                 ? "Mira un anuncio corto para desbloquearlo durante esta sesión."
                 : "Watch a short ad to unlock it for this session.")
                .font(.dmSans(14))
                .foregroundStyle(Color.softGray)
                .multilineTextAlignment(.center)
            Button(action: onUnlock) {
                Text(es ? "Ver anuncio (15s)" : "Watch Ad (15s)")
                    .font(.caveat(20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.inkBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            Button(action: onPaywall) {
                HStack(spacing: 6) {
                    Text(es ? "Obtener Ink Pro" : "Get Ink Pro")
                    Image(systemName: "arrow.right")
                }
                    .font(.dmSans(14, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
            }
        }
        .padding(24)
    }
}

struct LayersSheet: View {
    let onUpgrade: () -> Void
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }

    var body: some View {
        let es = language == .spanish
        VStack(spacing: 16) {
            Text(es ? "Capas" : "Layers")
                .font(.caveat(28, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            VStack(spacing: 12) {
                LayerRow(name: es ? "Capa 1" : "Layer 1", isActive: true)
                LayerRow(name: es ? "Fondo" : "Background", isActive: false)
            }
            .padding(.horizontal, 24)
            Spacer()
            Text(es
                 ? "La edición por capas es parte de Ink Pro."
                 : "Multi-layer editing is part of Ink Pro.")
                .font(.dmSans(13))
                .foregroundStyle(Color.softGray)
            Button(action: onUpgrade) {
                HStack(spacing: 6) {
                    Text(es ? "Obtener Ink Pro" : "Get Ink Pro")
                    Image(systemName: "arrow.right")
                }
                    .font(.caveat(20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.inkBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }
}

private struct LayerRow: View {
    let name: String
    let isActive: Bool
    var body: some View {
        HStack {
            Image(systemName: isActive ? "eye.fill" : "eye.slash")
                .foregroundStyle(Color.inkBlue)
            Text(name).font(.dmSans(15, weight: .medium))
            Spacer()
            Image(systemName: "line.3.horizontal").foregroundStyle(Color.softGray)
        }
        .padding(10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lightLine, lineWidth: 1))
    }
}

struct SketchSettingsSheet: View {
    @Binding var brushWidth: CGFloat
    @Binding var isErasing: Bool
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }

    var body: some View {
        let es = language == .spanish
        VStack(alignment: .leading, spacing: 16) {
            Text(es ? "Ajustes del Pincel" : "Brush Settings")
                .font(.caveat(28, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            VStack(alignment: .leading, spacing: 6) {
                Text((es ? "Grosor: " : "Width: ") + "\(Int(brushWidth))")
                    .font(.dmSans(14, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
                Slider(value: $brushWidth, in: 1...30, step: 1)
                    .tint(Color.inkBlue)
            }
            Toggle(es ? "Modo borrador" : "Eraser mode", isOn: $isErasing)
                .tint(Color.inkBlue)
                .font(.dmSans(14, weight: .semibold))
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        SketchingView()
            .environmentObject(AppState())
            .environmentObject(StoreManager())
    }
}
