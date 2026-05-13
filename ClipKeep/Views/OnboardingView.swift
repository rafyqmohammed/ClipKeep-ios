import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            page1.tag(0)
            page2.tag(1)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
    }

    private var page1: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 36)
            Text(loc("onboarding.capture.title"))
                .font(.title.bold())
                .padding(.bottom, 12)
            Text(loc("onboarding.capture.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                withAnimation { page = 1 }
            } label: {
                Text(loc("action.next")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    private var page2: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange.gradient)
                .padding(.bottom, 36)
            Text(loc("onboarding.permission.title"))
                .font(.title.bold())
                .padding(.bottom, 12)
            Text(loc("onboarding.permission.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)
            Label(loc("onboarding.permission.instruction"), systemImage: "checkmark.circle")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                onDone()
            } label: {
                Text(loc("action.start")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingView { }
}
