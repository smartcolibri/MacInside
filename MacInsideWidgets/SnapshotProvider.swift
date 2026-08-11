import WidgetKit
import SwiftUI

/// Entrée de timeline : l'instantané publié par l'app, ou la raison précise de
/// son absence.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let result: WidgetSnapshotStore.ReadResult

    var snapshot: WidgetSnapshot? {
        if case .available(let snapshot) = result { return snapshot }
        return nil
    }
}

/// Fournisseur commun aux quatre widgets : ils affichent tous des facettes du
/// même instantané, seule la vue change.
struct SnapshotProvider: TimelineProvider {
    /// Cadence demandée au système. WidgetKit reste libre de l'espacer selon le
    /// budget — c'est une intention, pas une garantie, d'où l'horodatage affiché
    /// par les widgets.
    private static let refreshInterval: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), result: .available(.placeholder))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        // En galerie de widgets, l'app n'a peut-être jamais tourné : montrer des
        // valeurs d'exemple plutôt qu'un état vide, sinon le widget paraît cassé
        // au moment précis où l'utilisateur choisit de l'ajouter.
        let result = WidgetSnapshotStore.read()
        let displayed: WidgetSnapshotStore.ReadResult
        if case .available = result {
            displayed = result
        } else if context.isPreview {
            displayed = .available(.placeholder)
        } else {
            displayed = result
        }
        completion(SnapshotEntry(date: Date(), result: displayed))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), result: WidgetSnapshotStore.read())
        let next = Date().addingTimeInterval(Self.refreshInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension WidgetSnapshot {
    /// Courbe d'exemple : une sinusoïde décalée, plausible sans être ronde.
    private static func demoHistory(base: Double, amplitude: Double, period: Double) -> [Double] {
        (0..<30).map { (index: Int) -> Double in
            base + amplitude * sin(Double(index) / period)
        }
    }

    /// Valeurs d'exemple pour la galerie et les previews. Volontairement
    /// plausibles plutôt que rondes, pour donner une idée juste du rendu.
    /// Construit par mutations successives : l'init memberwise unique était
    /// devenu trop gros pour le type-checker après l'ajout des 6 sections.
    static let placeholder: WidgetSnapshot = {
        var snapshot = WidgetSnapshot(
            capturedAt: Date(),
            cpu: .init(
                totalPercent: 23.4,
                userPercent: 16.1,
                systemPercent: 7.3,
                history: demoHistory(base: 18, amplitude: 12, period: 4),
                topProcessName: "Xcode",
                topProcessPercent: 42.7
            ),
            memory: .init(
                usedPercent: 61.2,
                usedBytes: 10_500_000_000,
                totalBytes: 17_179_869_184,
                history: demoHistory(base: 55, amplitude: 8, period: 5),
                topProcessName: "Safari",
                topProcessBytes: 1_900_000_000
            ),
            battery: .init(
                percentage: 76,
                isCharging: false,
                healthPercent: 98,
                cycleCount: 42,
                timeRemainingMinutes: 284,
                celsius: 31.4
            ),
            sensors: .init(
                available: true,
                hasFans: false,
                maxCelsius: 48.2,
                maxLabel: "CPU",
                readings: [
                    .init(label: "CPU", celsius: 48.2),
                    .init(label: "GPU", celsius: 44.6),
                    .init(label: "Airport", celsius: 39.1),
                    .init(label: "NAND", celsius: 36.8),
                ],
                fanRPMs: []
            )
        )
        snapshot.storage = .init(
            systemVolume: .init(name: "Macintosh HD",
                                usedBytes: 412_000_000_000,
                                totalBytes: 1_000_000_000_000),
            externalVolumes: [
                .init(name: "Backup", usedBytes: 1_400_000_000_000, totalBytes: 2_000_000_000_000),
            ],
            readBytesPerSec: 18_400_000,
            writeBytesPerSec: 6_200_000,
            readHistory: demoHistory(base: 12_000_000, amplitude: 8_000_000, period: 3),
            writeHistory: demoHistory(base: 5_000_000, amplitude: 3_000_000, period: 4)
        )
        snapshot.networkIdentity = .init(
            hostname: "macbook-pro",
            interfaceType: "Wi-Fi",
            interfaceName: "en0",
            localAddress: "192.168.1.24",
            publicAddress: "82.64.113.7",
            countryCode: "FR",
            gatewayAddress: "192.168.1.1"
        )
        snapshot.networkUsage = .init(
            downloadBytesPerSec: 2_400_000,
            uploadBytesPerSec: 340_000,
            downloadHistory: demoHistory(base: 1_800_000, amplitude: 900_000, period: 3),
            uploadHistory: demoHistory(base: 280_000, amplitude: 120_000, period: 5),
            totalDownloadBytes: 4_800_000_000,
            totalUploadBytes: 620_000_000
        )
        snapshot.fans = .init(
            available: true,
            hasFans: true,
            readings: [
                .init(label: "Ventilateur 1", rpm: 1840, percent: 31),
                .init(label: "Ventilateur 2", rpm: 1760, percent: 28),
            ]
        )
        snapshot.power = .init(
            available: true,
            readings: [
                .init(label: "DC In", value: 44.6, unit: "W"),
                .init(label: "System Total", value: 21.3, unit: "W"),
            ]
        )
        snapshot.accessories = .init(
            readings: [
                .init(name: "AirPods Pro", partLabel: "Gauche", percent: 84),
                .init(name: "AirPods Pro", partLabel: "Droite", percent: 82),
                .init(name: "AirPods Pro", partLabel: "Boîtier", percent: 47),
            ]
        )
        return snapshot
    }()
}
