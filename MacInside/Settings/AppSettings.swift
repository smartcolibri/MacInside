import SwiftUI
import Observation
import ServiceManagement

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    var label: String {
        switch self {
        case .system: return String(localized: "Système")
        case .light:  return String(localized: "Clair")
        case .dark:   return String(localized: "Sombre")
        }
    }
}

/// Style de la barre de menu : un seul dropdown combiné (historique) ou une
/// icône compacte par métrique, façon Stats/iStat Menus (chaque icône ouvre
/// son propre dropdown détaillé).
enum MenuBarMode: String, CaseIterable, Identifiable {
    case combined, separate
    var id: String { rawValue }
    var label: String {
        switch self {
        case .combined: return String(localized: "Combiné")
        case .separate: return String(localized: "Icônes séparées")
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    var appearanceRaw: String {
        didSet { UserDefaults.standard.set(appearanceRaw, forKey: "appearance") }
    }
    var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    var menuBarModeRaw: String {
        didSet { UserDefaults.standard.set(menuBarModeRaw, forKey: "menuBarMode") }
    }
    var showCPUMenuExtra: Bool { didSet { UserDefaults.standard.set(showCPUMenuExtra, forKey: "showCPUMenuExtra") } }
    var showMemoryMenuExtra: Bool { didSet { UserDefaults.standard.set(showMemoryMenuExtra, forKey: "showMemoryMenuExtra") } }
    var showNetworkMenuExtra: Bool { didSet { UserDefaults.standard.set(showNetworkMenuExtra, forKey: "showNetworkMenuExtra") } }
    var showDiskMenuExtra: Bool { didSet { UserDefaults.standard.set(showDiskMenuExtra, forKey: "showDiskMenuExtra") } }
    var showBatteryMenuExtra: Bool { didSet { UserDefaults.standard.set(showBatteryMenuExtra, forKey: "showBatteryMenuExtra") } }
    var showGPUMenuExtra: Bool { didSet { UserDefaults.standard.set(showGPUMenuExtra, forKey: "showGPUMenuExtra") } }
    var dashboardCardOrderRaw: String {
        didSet { UserDefaults.standard.set(dashboardCardOrderRaw, forKey: "dashboardCardOrder") }
    }
    var hiddenDashboardCardsRaw: String {
        didSet { UserDefaults.standard.set(hiddenDashboardCardsRaw, forKey: "hiddenDashboardCards") }
    }
    var lowBatteryAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(lowBatteryAlertEnabled, forKey: "lowBatteryAlertEnabled") }
    }
    var lowBatteryAlertThreshold: Int {
        didSet { UserDefaults.standard.set(lowBatteryAlertThreshold, forKey: "lowBatteryAlertThreshold") }
    }
    var highBatteryAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(highBatteryAlertEnabled, forKey: "highBatteryAlertEnabled") }
    }
    var highBatteryAlertThreshold: Int {
        didSet { UserDefaults.standard.set(highBatteryAlertThreshold, forKey: "highBatteryAlertThreshold") }
    }
    var pinnedProcessCommandsRaw: String {
        didSet { UserDefaults.standard.set(pinnedProcessCommandsRaw, forKey: "pinnedProcessCommands") }
    }

    init() {
        let defaults = UserDefaults.standard
        appearanceRaw = defaults.string(forKey: "appearance") ?? AppearanceMode.system.rawValue
        let storedInterval = defaults.double(forKey: "refreshInterval")
        refreshInterval = storedInterval > 0 ? storedInterval : 1.0
        menuBarModeRaw = defaults.string(forKey: "menuBarMode") ?? MenuBarMode.combined.rawValue

        showCPUMenuExtra = defaults.object(forKey: "showCPUMenuExtra") as? Bool ?? true
        showMemoryMenuExtra = defaults.object(forKey: "showMemoryMenuExtra") as? Bool ?? true
        showNetworkMenuExtra = defaults.object(forKey: "showNetworkMenuExtra") as? Bool ?? true
        showDiskMenuExtra = defaults.object(forKey: "showDiskMenuExtra") as? Bool ?? false
        showBatteryMenuExtra = defaults.object(forKey: "showBatteryMenuExtra") as? Bool ?? false
        showGPUMenuExtra = defaults.object(forKey: "showGPUMenuExtra") as? Bool ?? false
        dashboardCardOrderRaw = defaults.string(forKey: "dashboardCardOrder") ?? ""
        hiddenDashboardCardsRaw = defaults.string(forKey: "hiddenDashboardCards") ?? ""

        pinnedProcessCommandsRaw = defaults.string(forKey: "pinnedProcessCommands") ?? ""

        lowBatteryAlertEnabled = defaults.object(forKey: "lowBatteryAlertEnabled") as? Bool ?? true
        lowBatteryAlertThreshold = defaults.object(forKey: "lowBatteryAlertThreshold") as? Int ?? 20
        highBatteryAlertEnabled = defaults.object(forKey: "highBatteryAlertEnabled") as? Bool ?? false
        highBatteryAlertThreshold = defaults.object(forKey: "highBatteryAlertThreshold") as? Int ?? 90
    }

    var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    var menuBarMode: MenuBarMode { MenuBarMode(rawValue: menuBarModeRaw) ?? .combined }
    var menuBarModeIsCombined: Bool { menuBarMode == .combined }

    /// Ordre des cartes du dashboard, choisi par l'utilisateur via glisser-déposer.
    /// Les nouvelles cartes (ajoutées dans une version ultérieure) sont
    /// automatiquement ajoutées à la fin si elles sont absentes de l'ordre stocké.
    var dashboardCardOrder: [DashboardCardKind] {
        get {
            var order = dashboardCardOrderRaw
                .split(separator: ",")
                .compactMap { DashboardCardKind(rawValue: String($0)) }
            for kind in DashboardCardKind.allCases where !order.contains(kind) {
                order.append(kind)
            }
            return order
        }
        set { dashboardCardOrderRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    /// Cartes masquées par l'utilisateur (Réglages → « Cartes du dashboard »),
    /// indépendamment de leur ordre.
    var hiddenDashboardCards: Set<DashboardCardKind> {
        get { Set(hiddenDashboardCardsRaw.split(separator: ",").compactMap { DashboardCardKind(rawValue: String($0)) }) }
        set { hiddenDashboardCardsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    /// Processus épinglés dans la fenêtre Processus, par ligne de commande
    /// (cf. `ProcessEntry.pinKey`) et persistés — deux améliorations par
    /// rapport à NeoHtop, qui épingle par commande mais perd tout à la
    /// fermeture. Séparateur `\n` : une commande peut contenir des virgules,
    /// jamais de retour à la ligne (aplati à la collecte).
    var pinnedProcessCommands: Set<String> {
        get { Set(pinnedProcessCommandsRaw.split(separator: "\n").map(String.init)) }
        set { pinnedProcessCommandsRaw = newValue.sorted().joined(separator: "\n") }
    }

    /// Démarrage automatique à l'ouverture de session, via `SMAppService`
    /// (remplaçant moderne de `SMLoginItemSetEnabled`, pas d'entitlement
    /// supplémentaire requis pour l'app principale). L'état réel (`status`)
    /// fait foi plutôt qu'un booléen mis en cache dans `UserDefaults` : il ne
    /// peut pas se désynchroniser de l'état système (ex. si l'utilisateur
    /// désactive l'élément depuis Réglages Système > Général > Ouverture).
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Best-effort : l'utilisateur peut avoir refusé/révoqué côté
                // Réglages Système, rien à faire de plus côté app.
            }
        }
    }
}
