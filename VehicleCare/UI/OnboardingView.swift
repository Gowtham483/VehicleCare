import SwiftUI

struct OnboardingSlide: Identifiable {
    let id: String
    let icon: AppIcon
    let title: String
    let text: String
}

enum OnboardingContent {
    static var slides: [OnboardingSlide] { [
        OnboardingSlide(id: "services", icon: .tourServices, title: L10n.Onboarding.servicesTitle,
                        text: L10n.Onboarding.servicesText),
        OnboardingSlide(id: "quick", icon: .tourQuickLog, title: L10n.Onboarding.quickTitle,
                        text: L10n.Onboarding.quickText),
        OnboardingSlide(id: "reminders", icon: .tourReminders, title: L10n.Onboarding.remindersTitle,
                        text: L10n.Onboarding.remindersText),
        OnboardingSlide(id: "backup", icon: .tourTransfer, title: L10n.Onboarding.backupTitle,
                        text: L10n.Onboarding.backupText),
        OnboardingSlide(id: "start", icon: .tourStart, title: L10n.Onboarding.startTitle, text: L10n.Onboarding.startText),
    ] }
}

/// Skippable intro tour, used on first launch and for the replay from Settings.
struct OnboardingView: View {
    @Environment(\.theme) private var theme
    var doneLabel = L10n.Onboarding.addFirstVehicle
    let onSkip: () -> Void
    let onDone: () -> Void
    @State private var index = 0

    private var isLast: Bool { index == OnboardingContent.slides.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(L10n.Common.skip, action: onSkip)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel(L10n.Onboarding.skipAccessibility)
            }
            .padding()

            TabView(selection: $index) {
                ForEach(Array(OnboardingContent.slides.enumerated()), id: \.element.id) { i, slide in
                    VStack(spacing: 20) {
                        Image.app(slide.icon)
                            .font(.system(size: 52))
                            .foregroundStyle(theme.accent)
                            .frame(width: 120, height: 120)
                            .background(theme.surfaceAlt, in: Circle())
                            .padding(.bottom, 12)
                        Text(slide.title).font(.title.bold()).foregroundStyle(theme.textPrimary)
                        Text(slide.text).font(.body).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 36)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<OnboardingContent.slides.count, id: \.self) { i in
                    Circle().fill(i == index ? theme.accent : theme.border).frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 16)
            .accessibilityHidden(true)

            Button(isLast ? doneLabel : L10n.Common.next) {
                if isLast { onDone() } else { withAnimation { index += 1 } }
            }
            .buttonStyle(.app())
            .padding()
        }
        .background(theme.background)
    }
}
