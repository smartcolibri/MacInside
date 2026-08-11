import Foundation

/// Instantané des métriques écrit par l'app dans le conteneur App Group et relu
/// par l'extension widget.
///
/// L'extension est **obligatoirement sandboxée** (contrainte macOS sur les app
/// extensions) alors que l'app ne l'est pas : le widget ne peut donc pas lire le
/// SMC, IOKit ou `system_profiler` lui-même. Tout ce qu'il affiche transite par
/// cette struct.
///
/// Conséquence de conception : les libellés arrivent **déjà localisés**, générés
/// côté app à partir de `Localizable.xcstrings`. Dupliquer le catalogue dans
/// l'extension aurait fait diverger les deux traductions à la première retouche.
struct WidgetSnapshot: Codable, Equatable {
    /// Date de capture, affichée par les widgets : les données WidgetKit ont
    /// plusieurs minutes d'âge par construction, autant que ce soit visible
    /// plutôt que de laisser croire à du temps réel.
    var capturedAt: Date

    var cpu: CPU
    var memory: Memory
    /// `nil` sur une machine sans batterie (Mac mini, Studio…), cas distinct
    /// d'une batterie à 0 %.
    var battery: Battery?
    var sensors: Sensors

    // Sections ajoutées après le premier jet de widgets : optionnelles avec
    // défaut `nil` pour qu'un instantané écrit par une version antérieure de
    // l'app reste décodable — le widget concerné affiche alors « Lancez
    // MacInside » jusqu'au prochain tick de la nouvelle version.
    var storage: Storage? = nil
    var networkIdentity: NetworkIdentity? = nil
    var networkUsage: NetworkUsage? = nil
    var fans: Fans? = nil
    var power: Power? = nil
    var accessories: Accessories? = nil

    struct CPU: Codable, Equatable {
        var totalPercent: Double
        var userPercent: Double
        var systemPercent: Double
        /// Historique de charge le plus récent, borné à `historyLimit`.
        var history: [Double]
        var topProcessName: String?
        var topProcessPercent: Double?
    }

    struct Memory: Codable, Equatable {
        var usedPercent: Double
        var usedBytes: UInt64
        var totalBytes: UInt64
        var history: [Double]
        var topProcessName: String?
        var topProcessBytes: Double?
    }

    struct Battery: Codable, Equatable {
        var percentage: Int
        var isCharging: Bool
        var healthPercent: Int
        var cycleCount: Int
        var timeRemainingMinutes: Int?
        /// Température de la batterie si un capteur SMC la remonte, sinon `nil`.
        var celsius: Double?
    }

    struct Sensors: Codable, Equatable {
        var available: Bool
        var hasFans: Bool
        /// Température maximale hors capteurs « Battery » (déjà exposés par
        /// `Battery.celsius`), cohérent avec l'agrégat du dashboard.
        var maxCelsius: Double?
        var maxLabel: String?
        /// Quelques capteurs les plus chauds, libellés déjà localisés.
        var readings: [Reading]
        var fanRPMs: [Int]

        struct Reading: Codable, Equatable {
            var label: String
            var celsius: Double
        }
    }

    struct Storage: Codable, Equatable {
        /// `nil` si le volume système n'a pas pu être lu, cas distinct d'un
        /// volume plein (cf. « Volume système indisponible » du dashboard).
        var systemVolume: Volume?
        var externalVolumes: [Volume]
        var readBytesPerSec: Double
        var writeBytesPerSec: Double
        var readHistory: [Double]
        var writeHistory: [Double]

        struct Volume: Codable, Equatable {
            var name: String
            var usedBytes: UInt64
            var totalBytes: UInt64

            var availableBytes: UInt64 { totalBytes > usedBytes ? totalBytes - usedBytes : 0 }
            var usedPercent: Double {
                totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes) * 100
            }
        }
    }

    struct NetworkIdentity: Codable, Equatable {
        var hostname: String
        var interfaceType: String
        var interfaceName: String
        var localAddress: String
        var publicAddress: String
        var countryCode: String
        var gatewayAddress: String
    }

    struct NetworkUsage: Codable, Equatable {
        var downloadBytesPerSec: Double
        var uploadBytesPerSec: Double
        var downloadHistory: [Double]
        var uploadHistory: [Double]
        var totalDownloadBytes: UInt64
        var totalUploadBytes: UInt64
    }

    struct Fans: Codable, Equatable {
        var available: Bool
        var hasFans: Bool
        var readings: [Fan]

        struct Fan: Codable, Equatable {
            /// Libellé déjà localisé (« Ventilateur 1 »), comme tout ce qui
            /// transite dans l'instantané.
            var label: String
            var rpm: Int
            var percent: Double
        }
    }

    struct Power: Codable, Equatable {
        var available: Bool
        /// Hors lectures « Battery », affichées par le widget Batterie — même
        /// partition que PowerCardView.
        var readings: [Reading]

        struct Reading: Codable, Equatable {
            var label: String
            var value: Double
            var unit: String
        }
    }

    struct Accessories: Codable, Equatable {
        var readings: [Reading]

        struct Reading: Codable, Equatable {
            /// Nom d'appareil choisi par l'utilisateur, jamais traduit.
            var name: String
            /// Partie (« Gauche », « Boîtier »…), déjà localisée.
            var partLabel: String
            var percent: Int
        }
    }

    /// Les widgets n'affichent qu'une sparkline courte : transporter les 60
    /// échantillons du dashboard gonflerait le fichier sans rien apporter.
    static let historyLimit = 30
    /// Nombre de capteurs embarqués dans l'instantané (les plus chauds).
    static let sensorLimit = 4
    /// Volumes externes embarqués (un widget medium n'en affiche pas plus).
    static let volumeLimit = 3
    /// Lectures d'alimentation embarquées.
    static let powerLimit = 4
    /// Lignes d'accessoires embarquées (nom + partie).
    static let accessoryLimit = 8
}
