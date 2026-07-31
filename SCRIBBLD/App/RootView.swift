import SwiftUI

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            TabRootView()
                .opacity(showSplash ? 0 : 1)
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showSplash)
        .task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { showSplash = false }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(StoreManager())
}
