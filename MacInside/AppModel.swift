import Foundation
import Observation

/// Point central : agrège tous les providers sur une seule boucle de
/// rafraîchissement et publie leurs snapshots pour les vues SwiftUI.
@Observable
@MainActor
final class AppModel {
    private(set) var identity = SystemIdentity()
    private(set) var cpu = CPUStats()
    private(set) var memory = MemoryStats()
    private(set) var disk = DiskStats()
    private(set) var network = NetworkStats()
    private(set) var sensors = SensorStats()
    private(set) var battery = BatteryStats()
    private(set) var gpu = GPUStats()
    private(set) var accessoryBatteries = AccessoryBatteryStats()
    private(set) var processList = ProcessListStats()

    /// Rafraîchissement gelé (bouton pause) : la boucle continue de tourner
    /// mais ne relit plus rien — toutes les valeurs affichées restent figées.
    var isFrozen = false

    /// Vrai tant que la fenêtre Processus est ouverte. La collecte complète
    /// (3 appels noyau par process) ne tourne que si quelqu'un la regarde ;
    /// le dashboard, lui, se contente toujours du top 6.
    var isProcessListActive = false {
        didSet {
            guard isProcessListActive, !oldValue else { return }
            // Premier snapshot immédiat pour ne pas ouvrir une fenêtre vide ;
            // les % CPU demandent deux échantillons et se remplissent au tick
            // suivant.
            processList = processListMonitor.snapshot()
        }
    }

    private let identityProvider = SystemIdentityProvider()
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()
    private let sensorMonitor = SensorMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let batteryAlertMonitor = BatteryAlertMonitor()
    private let gpuMonitor = GPUMonitor()
    private let accessoryBatteryMonitor = AccessoryBatteryMonitor()
    private let processMonitor = ProcessMonitor()
    private let processListMonitor = ProcessListMonitor()
    private let publicAddressLookup = PublicAddressLookup()
    private let widgetPublisher = WidgetSnapshotPublisher()

    private var refreshTask: Task<Void, Never>?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                if !self.isFrozen { self.refresh() }
                let interval = self.settings.refreshInterval
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func requestBatteryAlertAuthorization() {
        batteryAlertMonitor.requestAuthorizationIfNeeded()
    }

    /// Variables d'environnement d'un process, lues à la demande (fiche
    /// détail de la fenêtre Processus).
    func processEnvironment(pid: Int32) -> [String] {
        processListMonitor.environment(pid: pid)
    }

    private func refresh() {
        identity = identityProvider.snapshot()

        var cpuStats = cpuMonitor.snapshot()
        cpuStats.topProcesses = processMonitor.topByCPU()
        cpu = cpuStats

        var memoryStats = memoryMonitor.snapshot()
        memoryStats.topProcesses = processMonitor.topByMemory()
        memory = memoryStats

        disk = diskMonitor.snapshot()
        network = networkMonitor.snapshot()
        sensors = sensorMonitor.snapshot()
        battery = batteryMonitor.snapshot()
        batteryAlertMonitor.evaluate(battery: battery, settings: settings)
        gpu = gpuMonitor.snapshot()
        accessoryBatteries = accessoryBatteryMonitor.snapshot()
        if isProcessListActive {
            processList = processListMonitor.snapshot()
        }

        // Après l'affectation de tous les snapshots : les widgets lisent un
        // instantané cohérent, jamais un mélange de deux tours de boucle.
        widgetPublisher.publish(from: self)

        Task { [weak self] in
            guard let self, let result = await self.publicAddressLookup.current() else { return }
            self.network.publicAddress = result.ip
            self.network.countryCode = result.countryCode
        }
    }
}
