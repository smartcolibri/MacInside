import Foundation

/// État d'ordonnancement d'un process, mappé depuis `proc_bsdinfo.pbi_status`.
enum ProcessState: String, CaseIterable, Identifiable, Equatable {
    case running, sleeping, stopped, zombie, unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .running: return String(localized: "En cours")
        case .sleeping: return String(localized: "En veille")
        case .stopped: return String(localized: "Arrêté")
        case .zombie: return String(localized: "Zombie")
        case .unknown: return String(localized: "Inconnu")
        }
    }

    /// États proposés dans le filtre (l'état `unknown` est transitoire —
    /// process en cours de création — et n'aurait aucun sens à filtrer).
    static let filterable: [ProcessState] = [.running, .sleeping, .stopped, .zombie]
}

/// Une ligne de la fenêtre Processus. Contrairement à `ProcessUsageEntry`
/// (top 6 des cartes CPU/Mémoire), porte tout le détail par process.
struct ProcessEntry: Identifiable, Equatable {
    var id: Int32 { pid }
    var pid: Int32
    var parentPID: Int32
    var name: String
    var user: String
    var state: ProcessState
    var cpuPercent: Double
    var residentBytes: UInt64
    var virtualBytes: UInt64
    var threadCount: Int
    var startDate: Date?
    var runTime: TimeInterval
    var diskReadBytes: UInt64
    var diskWriteBytes: UInt64
    /// Ligne de commande complète ; chemin de l'exécutable ou nom en repli
    /// quand `KERN_PROCARGS2` est refusé (process d'un autre utilisateur).
    var command: String

    var stateLabel: String { state.label }
    /// Pour trier la colonne « Démarré » (`Date?` n'est pas `Comparable`).
    var startTimestamp: TimeInterval { startDate?.timeIntervalSince1970 ?? 0 }
    /// Clé d'épinglage : la ligne de commande, pas le PID — l'épinglage
    /// survit ainsi au redémarrage du process (idée reprise de NeoHtop).
    var pinKey: String { command.isEmpty ? name : command }
}

struct ProcessListStats: Equatable {
    var entries: [ProcessEntry] = []
    var capturedAt: Date = .distantPast
}
