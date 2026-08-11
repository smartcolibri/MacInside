import Foundation
import WidgetKit

/// Publie l'état courant de l'app vers le conteneur App Group lu par les widgets.
///
/// Deux cadences volontairement distinctes :
/// - **l'écriture du fichier** suit la boucle de rafraîchissement du dashboard
///   (sérialiser une petite struct est négligeable) ;
/// - **`reloadAllTimelines()`** est throttlé fort. WidgetKit budgète les
///   rechargements par jour : en demander à chaque tick ferait consommer le
///   quota en quelques minutes, après quoi le système cesserait d'honorer les
///   demandes — les widgets seraient *moins* à jour, pas plus.
@MainActor
final class WidgetSnapshotPublisher {
    /// Intervalle minimal entre deux demandes de rechargement. Ordre de grandeur
    /// aligné sur ce que WidgetKit accorde en pratique ; descendre plus bas ne
    /// rendrait pas les widgets plus frais.
    private static let reloadInterval: TimeInterval = 5 * 60

    private var lastReload: Date?

    func publish(from model: AppModel) {
        let snapshot = Self.snapshot(from: model)
        guard WidgetSnapshotStore.write(snapshot) else { return }

        let now = snapshot.capturedAt
        if let lastReload, now.timeIntervalSince(lastReload) < Self.reloadInterval { return }
        lastReload = now
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func snapshot(from model: AppModel) -> WidgetSnapshot {
        let cpu = model.cpu
        let memory = model.memory
        let sensors = model.sensors
        let battery = model.battery
        let disk = model.disk
        let network = model.network

        // Même partition que le dashboard : les capteurs « Battery » vivent dans
        // la carte Batterie, pas dans la carte Capteurs (cf. BatteryCardView /
        // TemperatureCardView).
        let batteryTemperatures = sensors.temperatures.filter { $0.label.hasPrefix("Battery") }
        let otherTemperatures = sensors.temperatures.filter { !$0.label.hasPrefix("Battery") }
        let hottest = otherTemperatures.max { $0.celsius < $1.celsius }

        return WidgetSnapshot(
            capturedAt: Date(),
            cpu: .init(
                totalPercent: cpu.totalPercent,
                userPercent: cpu.userPercent,
                systemPercent: cpu.systemPercent,
                history: Array(cpu.loadHistory.suffix(WidgetSnapshot.historyLimit)),
                topProcessName: cpu.topProcesses.first?.name,
                topProcessPercent: cpu.topProcesses.first?.value
            ),
            memory: .init(
                usedPercent: memory.usedPercent,
                usedBytes: memory.usedBytes,
                totalBytes: memory.totalBytes,
                history: Array(memory.loadHistory.suffix(WidgetSnapshot.historyLimit)),
                topProcessName: memory.topProcesses.first?.name,
                topProcessBytes: memory.topProcesses.first?.value
            ),
            // `nil` plutôt qu'une struct à zéro : le widget doit distinguer
            // « Mac sans batterie » de « batterie déchargée ».
            battery: battery.isPresent ? .init(
                percentage: battery.percentage,
                isCharging: battery.isCharging,
                healthPercent: battery.healthPercent,
                cycleCount: battery.cycleCount,
                timeRemainingMinutes: battery.timeRemainingMinutes,
                celsius: batteryTemperatures.first?.celsius
            ) : nil,
            sensors: .init(
                available: sensors.available,
                hasFans: sensors.hasFans,
                maxCelsius: hottest?.celsius,
                maxLabel: hottest?.label,
                readings: otherTemperatures
                    .sorted { $0.celsius > $1.celsius }
                    .prefix(WidgetSnapshot.sensorLimit)
                    .map { .init(label: $0.label, celsius: $0.celsius) },
                fanRPMs: sensors.fans.map(\.rpm)
            ),
            storage: .init(
                systemVolume: disk.systemVolume.map(Self.volume),
                externalVolumes: disk.externalVolumes
                    .prefix(WidgetSnapshot.volumeLimit)
                    .map(Self.volume),
                readBytesPerSec: disk.readBytesPerSec,
                writeBytesPerSec: disk.writeBytesPerSec,
                readHistory: Array(disk.readHistory.suffix(WidgetSnapshot.historyLimit)),
                writeHistory: Array(disk.writeHistory.suffix(WidgetSnapshot.historyLimit))
            ),
            networkIdentity: .init(
                hostname: model.identity.hostname,
                interfaceType: network.interfaceType,
                interfaceName: network.interfaceName,
                localAddress: network.localAddress,
                publicAddress: network.publicAddress,
                countryCode: network.countryCode,
                gatewayAddress: network.gatewayAddress
            ),
            networkUsage: .init(
                downloadBytesPerSec: network.downloadBytesPerSec,
                uploadBytesPerSec: network.uploadBytesPerSec,
                downloadHistory: Array(network.downloadHistory.suffix(WidgetSnapshot.historyLimit)),
                uploadHistory: Array(network.uploadHistory.suffix(WidgetSnapshot.historyLimit)),
                totalDownloadBytes: network.totalDownloadBytes,
                totalUploadBytes: network.totalUploadBytes
            ),
            fans: .init(
                available: sensors.available,
                hasFans: sensors.hasFans,
                readings: sensors.fans.map { .init(label: $0.label, rpm: $0.rpm, percent: $0.percent) }
            ),
            // Même partition que PowerCardView : les lectures « Battery » vivent
            // dans le widget Batterie.
            power: .init(
                available: sensors.available,
                readings: sensors.power
                    .filter { !$0.label.hasPrefix("Battery") }
                    .prefix(WidgetSnapshot.powerLimit)
                    .map { .init(label: $0.label, value: $0.value, unit: $0.unit) }
            ),
            accessories: .init(readings: accessoryReadings(model.accessoryBatteries))
        )
    }

    private static func volume(_ volume: VolumeStats) -> WidgetSnapshot.Storage.Volume {
        .init(name: volume.name, usedBytes: volume.usedBytes, totalBytes: volume.totalBytes)
    }

    /// Même regroupement et même ordre stable (Gauche, Droite, Boîtier,
    /// Batterie) que AccessoryBatteryCardView, mais les libellés de partie
    /// partent déjà localisés — l'extension n'a pas le contexte pour traduire.
    private static func accessoryReadings(_ stats: AccessoryBatteryStats) -> [WidgetSnapshot.Accessories.Reading] {
        let names = Set(stats.accessories.map(\.name)).sorted()
        return names.flatMap { name in
            stats.accessories
                .filter { $0.name == name }
                .sorted { sortRank($0.part) < sortRank($1.part) }
                .map { WidgetSnapshot.Accessories.Reading(name: $0.name,
                                                          partLabel: partLabel($0.part),
                                                          percent: $0.percent) }
        }
        .prefix(WidgetSnapshot.accessoryLimit)
        .map { $0 }
    }

    private static func sortRank(_ part: String) -> Int {
        switch part {
        case "Left": return 0
        case "Right": return 1
        case "Case": return 2
        default: return 3
        }
    }

    private static func partLabel(_ part: String) -> String {
        switch part {
        case "Left": return String(localized: "Gauche")
        case "Right": return String(localized: "Droite")
        case "Case": return String(localized: "Boîtier")
        default: return String(localized: "Batterie")
        }
    }
}
