import SwiftUI
import UIKit

@main
struct VehicleCareApp: App {
    @State private var model: AppModel?
    @State private var startupError: String?

    init() {
        do {
            _model = State(initialValue: try AppModel.live())
        } catch {
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let model {
                RootView()
                    .environment(model)
                    .preferredColorScheme(model.settings.appearance.colorScheme)
                    .environment(\.theme, Theme.resolve(model.settings.themeId))
                    .task { await model.boot() }
                    .onAppear { KeyboardDismisser.shared.install() }
            } else {
                Text(L10n.App.startupError(AppInfo.name, startupError ?? "")).multilineTextAlignment(.center).padding()
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var model = model
        Group {
            if model.settings.onboardingDone {
                MainTabView()
            } else {
                OnboardingView(onSkip: { model.finishOnboarding(addVehicle: false) }, onDone: { model.finishOnboarding(addVehicle: true) })
            }
        }
        .alert(L10n.Common.errorTitle, isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert(L10n.Common.noteTitle, isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(model.notice ?? "")
        }
    }
}

struct MainTabView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            VehiclesView().tabItem { Label(L10n.Vehicles.title, icon: .vehicles) }
            HistoryView().tabItem { Label(L10n.History.title, icon: .history) }
            SettingsView().tabItem { Label(L10n.Settings.title, icon: .settings) }
        }
        .tint(theme.bottomBarActive)
        .toolbarBackground(theme.bottomBar, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear { UITabBar.appearance().unselectedItemTintColor = theme.bottomBarInactiveUIColor }
    }
}
