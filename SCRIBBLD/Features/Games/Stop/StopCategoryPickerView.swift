import SwiftUI

struct StopCategoryPickerView: View {
    @ObservedObject var vm: StopGameViewModel
    @EnvironmentObject private var store: StoreManager

    @AppStorage("scribbld.stop.customDeck") private var customDeckRaw: String = ""
    @State private var selected: Set<StopCategoryKey> = Set(StopPreset.classic.keys)
    @State private var presentPaywall = false

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)]

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header
                        languageRow
                        presetsRow
                        durationRow
                        Text(vm.game.language == .english ? "Categories (6–20)" : "Categorías (6 a 20)")
                            .font(.caveat(22, weight: .bold))
                            .foregroundStyle(Color.inkBlue)
                        categoryGrid
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 120)
                }
                Spacer(minLength: 0)
            }
            VStack {
                Spacer()
                startCTA
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, 24)
                    .background(LinearGradient(colors: [Color.cream.opacity(0), Color.cream], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            }
        }
        .sheet(isPresented: $presentPaywall) { InkProView().environmentObject(store) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.game.language == .english ? "Pick your categories" : "Elige tus categorías")
                .font(.caveat(32, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(vm.game.language == .english ? "Choose 6 to 20 categories" : "6 a 20 categorías")
                .font(.dmSans(13))
                .foregroundStyle(Color.softGray)
        }
    }

    /// Round timer picker — players pick how long each round runs.
    /// Defaults to 3 min (180s). Range matches what the user spec'd
    /// (2–5 min); shorter than 2 min isn't fun for 20 categories.
    private var durationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.game.language == .english ? "Round time" : "Tiempo por ronda")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            HStack(spacing: 8) {
                ForEach([2, 3, 4, 5], id: \.self) { minutes in
                    let durationSec = TimeInterval(minutes * 60)
                    let isOn = Int(vm.game.roundDuration) == Int(durationSec)
                    Text("\(minutes) min")
                        .font(.dmSans(13, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Color.cream : Color.inkBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if isOn {
                                    PencilFilledSurface(
                                        color: .inkBlue,
                                        cornerRadius: 18,
                                        seed: UInt64(minutes * 41)
                                    )
                                } else {
                                    Color.white.opacity(0.55)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            }
                        )
                        .overlay(
                            Group {
                                if !isOn {
                                    SketchBorderShape(cornerRadius: 18, jitter: 1.0, seed: UInt64(minutes * 41))
                                        .stroke(Color.inkBlue, lineWidth: 1.2)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticEngine.light()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                vm.game.roundDuration = durationSec
                            }
                        }
                }
            }
        }
    }

    private var languageRow: some View {
        HStack(spacing: 8) {
            ForEach(GameLanguage.allCases) { lang in
                let isOn = vm.game.language == lang
                Text(lang.label)
                    .font(.dmSans(12, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.cream : Color.inkBlue)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(isOn ? Color.inkBlue : Color.white.opacity(0.6))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.inkBlue.opacity(0.5), lineWidth: 1))
                    .onTapGesture {
                        HapticEngine.light()
                        vm.game.language = lang
                    }
            }
        }
    }

    private var presetsRow: some View {
        HStack(spacing: 8) {
            ForEach(StopPreset.allCases) { preset in
                Button {
                    HapticEngine.light()
                    apply(preset)
                } label: {
                    VStack(spacing: 2) {
                        Text(preset.label)
                            .font(.caveat(18, weight: .bold))
                            .foregroundStyle(Color.inkBlue)
                        Text("\(preset == .custom ? customDeckKeys().count : preset.keys.count)")
                            .font(.dmSans(11))
                            .foregroundStyle(Color.softGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.6))
                    .sketchBorder(color: .inkBlue, lineWidth: 1, cornerRadius: 8, jitter: 0.6, seed: UInt64(preset.rawValue.hashValue & 0xFFFF))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(StopCategoryKey.allCases) { key in
                CategoryChip(
                    key: key,
                    language: vm.game.language,
                    selected: selected.contains(key),
                    locked: key.tier == .premium && !store.premiumUnlocked,
                    canSelectMore: selected.count < 20
                ) {
                    toggle(key)
                } onLockedTap: {
                    presentPaywall = true
                }
            }
        }
        // The "INK PRO" ribbon on premium chips sits at `.offset(y: -6)`
        // to peek above the tile — give the grid enough vertical
        // breathing room that the ribbon doesn't get clipped by any
        // ancestor that decides to clip its bounds.
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    private var startCTA: some View {
        Button {
            guard selected.count >= 6 else { HapticEngine.error(); return }
            HapticEngine.medium()
            saveCustomDeck()
            vm.game.categories = StopCategoryKey.allCases.filter { selected.contains($0) }
            vm.startGame()
        } label: {
            HStack {
                Text(vm.game.language == .english ? "Start game" : "Empezar juego")
                Image(systemName: "arrow.right")
            }
            .font(.caveat(22, weight: .bold))
            .foregroundStyle(Color.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected.count < 6 ? Color.inkBlue.opacity(0.4) : Color.inkBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(selected.count < 6)
    }

    private func toggle(_ key: StopCategoryKey) {
        HapticEngine.light()
        if selected.contains(key) {
            selected.remove(key)
        } else if selected.count < 20 {
            selected.insert(key)
        } else {
            HapticEngine.error()
        }
    }

    private func apply(_ preset: StopPreset) {
        if preset == .custom {
            selected = Set(customDeckKeys())
        } else {
            selected = Set(preset.keys)
        }
    }

    private func customDeckKeys() -> [StopCategoryKey] {
        customDeckRaw.split(separator: ",").compactMap { StopCategoryKey(rawValue: String($0)) }
    }

    private func saveCustomDeck() {
        customDeckRaw = selected.map(\.rawValue).joined(separator: ",")
    }
}

private struct CategoryChip: View {
    let key: StopCategoryKey
    let language: GameLanguage
    let selected: Bool
    let locked: Bool
    let canSelectMore: Bool
    let onTap: () -> Void
    let onLockedTap: () -> Void

    var body: some View {
        Button {
            if locked { onLockedTap() } else { onTap() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: key.iconSystemName)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(selected ? Color.cream : Color.inkBlue)
                Text(key.spanishName)
                    .font(.caveat(16, weight: .bold))
                    .foregroundStyle(selected ? Color.cream : Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if language == .bilingual {
                    Text(key.englishName)
                        .font(.dmSans(9))
                        .foregroundStyle(selected ? Color.cream.opacity(0.8) : Color.softGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(8)
            .background(
                Group {
                    if selected {
                        PencilFilledSurface(
                            color: .inkBlue,
                            cornerRadius: 8,
                            seed: UInt64(key.rawValue.hashValue & 0xFFFF)
                        )
                    } else {
                        Color.white.opacity(0.75)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            )
            .overlay(alignment: .topTrailing) {
                if locked {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill").font(.system(size: 8))
                        Text("INK PRO").font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(Color.goldAccent)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(12))
                    .offset(x: 6, y: -6)
                }
            }
            .sketchBorder(color: selected ? .inkBlue : .lightLine, lineWidth: selected ? 1.6 : 1, cornerRadius: 8, jitter: 0.6, seed: UInt64(key.rawValue.hashValue & 0xFFFF))
            .opacity(locked ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canSelectMore && !selected && !locked)
    }
}

#Preview {
    StopCategoryPickerView(vm: StopGameViewModel())
        .environmentObject(StoreManager())
}
