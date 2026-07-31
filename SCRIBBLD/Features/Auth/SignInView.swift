import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()
                VStack(spacing: 8) {
                    Text("Sign in to play\nwith friends")
                        .font(.caveat(38, weight: .bold))
                        .foregroundStyle(Color.inkBlue)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    PencilLineView(color: .redPen, lineWidth: 2.5, seed: 19)
                        .frame(width: 180, height: 8)
                }
                bulletPoints
                Spacer()
                appleButton
                signInError
                skipButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xl)
        }
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
            Button("Close") { dismiss() }.tint(Color.inkBlue)
        }}
    }

    private var bulletPoints: some View {
        VStack(alignment: .leading, spacing: 14) {
            bullet("Challenge friends in TTT, Dots & Boxes, Hangman and Stop!")
            bullet("Get notified when they reply with a score")
            bullet("Your name only — no email shared without your tap")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.inkGreen)
                .padding(.top, 4)
            Text(text)
                .font(.dmSans(14))
                .foregroundStyle(Color.inkBlue)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appleButton: some View {
        Button {
            HapticEngine.light()
            auth.signInWithApple()
        } label: {
            ZStack {
                if auth.isSigningIn {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "applelogo")
                        Text("Sign in with Apple")
                            .font(.dmSans(15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(auth.isSigningIn)
    }

    /// `auth.lastError` is an arbitrary message from the auth framework, so it
    /// can run to several lines. It used to sit in a `.overlay` pinned at
    /// `padding(.top, -18)` with no line limit, which meant a long error grew
    /// downward and rendered on top of the Sign in with Apple button. It now
    /// occupies its own row in the stack, where it can take the space it needs.
    @ViewBuilder private var signInError: some View {
        if let err = auth.lastError {
            Text(err)
                .font(.dmSans(11))
                .foregroundStyle(Color.redPen)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        }
    }

    private var skipButton: some View {
        Button("Maybe later") {
            HapticEngine.light()
            dismiss()
        }
        .font(.dmSans(13, weight: .semibold))
        .foregroundStyle(Color.softGray)
    }
}

#Preview {
    NavigationStack {
        SignInView().environmentObject(AuthService())
    }
}
