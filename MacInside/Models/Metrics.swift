import Foundation

struct SystemIdentity: Equatable {
    var hostname: String = ""
    var osVersion: String = ""
    var modelName: String = ""
    var modelIdentifier: String = ""
    var chipName: String = ""
    var gpuName: String = ""
    var architecture: String = ""
    var performanceCoreCount: Int = 0
    var efficiencyCoreCount: Int = 0
    var threadCount: Int = 0
    var serialNumber: String = ""
    var uptime: TimeInterval = 0
    var thermalState: ProcessInfo.ThermalState = .nominal
    /// Load average 1 / 5 / 15 min (`getloadavg`), vide si indisponible.
    var loadAverage: [Double] = []

    var coreCount: Int { performanceCoreCount + efficiencyCoreCount }
}

struct ProcessUsageEntry: Identifiable, Equatable {
    var id: Int32 { pid }
    var pid: Int32
    var name: String
    var value: Double // % CPU ou bytes mémoire selon le contexte
}

struct CPUStats: Equatable {
    var systemPercent: Double = 0
    var userPercent: Double = 0
    var idlePercent: Double = 100
    var perCoreLoad: [Double] = []
    var loadHistory: [Double] = []
    var topProcesses: [ProcessUsageEntry] = []

    var totalPercent: Double { systemPercent + userPercent }
}

struct MemoryStats: Equatable {
    var totalBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var activeBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var availableBytes: UInt64 = 0
    var loadHistory: [Double] = []
    var topProcesses: [ProcessUsageEntry] = []

    var usedBytes: UInt64 { totalBytes > availableBytes ? totalBytes - availableBytes : 0 }
    var usedPercent: Double { totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes) * 100 }
}

struct VolumeStats: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var totalBytes: UInt64
    var availableBytes: UInt64
    var isExternal: Bool

    var usedBytes: UInt64 { totalBytes > availableBytes ? totalBytes - availableBytes : 0 }
    var usedPercent: Double { totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes) * 100 }
}

struct DiskStats: Equatable {
    var systemVolume: VolumeStats?
    var externalVolumes: [VolumeStats] = []
    /// Débit agrégé tous disques confondus : les compteurs IOKit "Statistics"
    /// vivent sur le pilote physique (`IOBlockStorageDriver`), pas sur les
    /// volumes/conteneurs APFS montés — pas de ventilation fiable par volume.
    var readBytesPerSec: Double = 0
    var writeBytesPerSec: Double = 0
    var readHistory: [Double] = []
    var writeHistory: [Double] = []
    var totalReadBytes: UInt64 = 0
    var totalWriteBytes: UInt64 = 0
}

struct NetworkStats: Equatable {
    var interfaceName: String = ""
    var interfaceType: String = ""
    var macAddress: String = ""
    var gatewayAddress: String = ""
    var subnetMask: String = ""
    var localAddress: String = ""
    var publicAddress: String = ""
    var countryCode: String = ""
    var downloadBytesPerSec: Double = 0
    var uploadBytesPerSec: Double = 0
    var downloadHistory: [Double] = []
    var uploadHistory: [Double] = []
    var totalDownloadBytes: UInt64 = 0
    var totalUploadBytes: UInt64 = 0
}

struct SensorReading: Identifiable, Equatable {
    var id: String { key }
    var key: String
    var label: String
    var celsius: Double
}

struct FanReading: Identifiable, Equatable {
    var id: Int
    var label: String
    var rpm: Int
    var minRpm: Int
    var maxRpm: Int

    var percent: Double {
        guard maxRpm > minRpm else { return 0 }
        return Double(rpm - minRpm) / Double(maxRpm - minRpm) * 100
    }
}

struct PowerReading: Identifiable, Equatable {
    var id: String { key }
    var key: String
    var label: String
    var value: Double
    var unit: String
}

struct SensorStats: Equatable {
    var available: Bool = false
    var hasFans: Bool = false
    var temperatures: [SensorReading] = []
    var fans: [FanReading] = []
    var power: [PowerReading] = []
    /// Historique de la température maximale relevée (hors capteurs
    /// "Battery", déjà affichés à part dans la carte Batterie) : une seule
    /// tendance agrégée plutôt qu'un graphique par capteur SMC individuel.
    var temperatureHistory: [Double] = []
}

struct GPUStats: Equatable {
    var available: Bool = false
    var deviceUtilizationPercent: Int = 0
    var rendererUtilizationPercent: Int = 0
    var tilerUtilizationPercent: Int = 0
    var inUseSystemMemoryBytes: UInt64 = 0
    var allocSystemMemoryBytes: UInt64 = 0
    var recoveryCount: Int = 0
    var loadHistory: [Double] = []

    var memoryUsagePercent: Double {
        allocSystemMemoryBytes == 0 ? 0 : Double(inUseSystemMemoryBytes) / Double(allocSystemMemoryBytes) * 100
    }
}

struct AccessoryBatteryReading: Identifiable, Equatable {
    var id: String { name + part }
    var name: String
    /// Brut ("", "Left", "Right", "Case"), tel que renvoyé par
    /// `system_profiler` — localisé à l'affichage (cf. `AccessoryBatteryCardView`),
    /// pas ici (`name`, lui, est un nom d'appareil choisi par l'utilisateur et
    /// ne doit jamais être traduit).
    var part: String
    var percent: Int
}

struct AccessoryBatteryStats: Equatable {
    var accessories: [AccessoryBatteryReading] = []
}

struct BatteryStats: Equatable {
    var isPresent: Bool = false
    var percentage: Int = 0
    var isCharging: Bool = false
    var cycleCount: Int = 0
    var healthPercent: Int = 100
    var timeRemainingMinutes: Int?
    var wattage: Double = 0
}
