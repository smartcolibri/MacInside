import SwiftUI
import Sparkle

@main
struct MacInsideApp: App {
    @State private var settings = AppSettings()
    @State private var model: AppModel

    /// `automaticallyDownloadsUpdates` reste à `false` : Sparkle peut vérifier
    /// en tâche de fond, mais ne doit jamais télécharger/installer sans
    /// consentement explicite (l'app tournerait le tapis sous l'utilisateur).
    private let updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.automaticallyDownloadsUpdates = false
        return controller
    }()

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: AppModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(settings)
                .environment(model)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onAppear { model.start() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1500, height: 940)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Rechercher les mises à jour…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        // Fenêtre Processus (Phase 5) : `Window` plutôt que `WindowGroup`, une
        // seule instance suffit — la collecte complète est active tant qu'elle
        // est ouverte (cf. `AppModel.isProcessListActive`).
        Window("Processus", id: "processes") {
            ProcessWindowView()
                .environment(settings)
                .environment(model)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onAppear { model.start() }
        }
        .defaultSize(width: 1040, height: 640)

        // `SceneBuilder` ne supporte pas les `if`/`if-else` imbriqués comme
        // `ViewBuilder` (limites de buildEither/buildOptional côté Scene) —
        // chaque MenuBarExtra est donc toujours déclaré, son affichage étant
        // piloté dynamiquement par `isInserted` plutôt que par une
        // conditionnelle dans le corps de la scène.
        MenuBarExtra(isInserted: binding(\.menuBarModeIsCombined)) {
            MenuBarView()
                .environment(settings)
                .environment(model)
                .onAppear { model.start() }
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: separateBinding(\.showCPUMenuExtra)) {
            CPUCardView().environment(model).onAppear { model.start() }
        } label: {
            CPUMenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: separateBinding(\.showMemoryMenuExtra)) {
            MemoryCardView().environment(model).onAppear { model.start() }
        } label: {
            MemoryMenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: separateBinding(\.showNetworkMenuExtra)) {
            NetworkMenuBarContent().environment(model).onAppear { model.start() }
        } label: {
            NetworkMenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: separateBinding(\.showDiskMenuExtra)) {
            DiskMenuBarContent().environment(model).onAppear { model.start() }
        } label: {
            DiskMenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: separateBinding(\.showBatteryMenuExtra, requires: model.battery.isPresent)) {
            BatteryCardView().environment(model).onAppear { model.start() }
        } label: {
            BatteryMenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: separateBinding(\.showGPUMenuExtra)) {
            GPUMenuBarContent().environment(model).onAppear { model.start() }
        } label: {
            GPUMenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(settings)
                .environment(model)
        }
    }

    /// Binding en lecture seule dérivé d'une propriété calculée de `AppSettings`
    /// (le `set` est un no-op : ces indicateurs ne se pilotent que via les
    /// réglages, jamais par une action de l'utilisateur sur le menu bar item).
    private func binding(_ keyPath: KeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: keyPath] }, set: { _ in })
    }

    private func separateBinding(_ keyPath: KeyPath<AppSettings, Bool>, requires extra: Bool = true) -> Binding<Bool> {
        Binding(
            get: { settings.menuBarMode == .separate && settings[keyPath: keyPath] && extra },
            set: { _ in }
        )
    }
}
