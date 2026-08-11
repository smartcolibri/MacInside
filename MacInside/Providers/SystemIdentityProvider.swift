import Foundation

/// Identité de la machine (modèle, puce, OS, série, uptime).
/// Les champs statiques (modèle, puce, série) sont résolus une seule fois via
/// `system_profiler SPHardwareDataType -json` — le seul moyen public fiable
/// d'obtenir un nom marketing ("Mac Studio (2022)", "Apple M1 Max") plutôt
/// qu'un identifiant brut ("Mac13,1"). L'uptime et l'état thermique sont
/// recalculés à chaque rafraîchissement (coût négligeable).
final class SystemIdentityProvider {
    private var cachedStatic: SystemIdentity?

    func snapshot() -> SystemIdentity {
        var identity = cachedStatic ?? Self.loadStatic()
        cachedStatic = identity
        identity.uptime = Self.uptime()
        identity.thermalState = ProcessInfo.processInfo.thermalState
        identity.loadAverage = Self.loadAverage()
        return identity
    }

    private static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : []
    }

    private static func loadStatic() -> SystemIdentity {
        var identity = SystemIdentity()
        identity.hostname = ProcessInfo.processInfo.hostName
            .replacingOccurrences(of: ".local", with: "")
        identity.osVersion = osVersionString()

        if let hardware = hardwareInfo() {
            identity.modelName = hardware["machine_name"] as? String ?? ""
            identity.modelIdentifier = hardware["machine_model"] as? String ?? ""
            identity.chipName = (hardware["chip_type"] as? String)
                ?? (hardware["cpu_type"] as? String) ?? ""
            identity.serialNumber = hardware["serial_number"] as? String ?? ""
        }
        identity.gpuName = displayInfo()?["_name"] as? String ?? ""

        identity.architecture = architectureName()
        (identity.performanceCoreCount, identity.efficiencyCoreCount) = coreCounts()
        identity.threadCount = sysctlInt("hw.logicalcpu") ?? identity.coreCount

        return identity
    }

    private static func hardwareInfo() -> [String: Any]? {
        firstEntry(dataType: "SPHardwareDataType")
    }

    private static func displayInfo() -> [String: Any]? {
        firstEntry(dataType: "SPDisplaysDataType")
    }

    private static func firstEntry(dataType: String) -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = [dataType, "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json[dataType] as? [[String: Any]],
                  let first = items.first else { return nil }
            return first
        } catch {
            return nil
        }
    }

    private static func osVersionString() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let codename = macOSCodename(major: v.majorVersion)
        let version = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        return codename.isEmpty ? "macOS \(version)" : "macOS \(codename) \(version)"
    }

    private static func macOSCodename(major: Int) -> String {
        switch major {
        case 15: return "Sequoia"
        case 14: return "Sonoma"
        case 13: return "Ventura"
        case 12: return "Monterey"
        default: return major > 15 ? "Tahoe" : ""
        }
    }

    private static func architectureName() -> String {
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        var value: Int32 = 0
        if size > 0 {
            sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        }
        return value == 1 ? "Apple Silicon" : "Intel"
    }

    private static func coreCounts() -> (performance: Int, efficiency: Int) {
        let perf = sysctlInt("hw.perflevel0.physicalcpu") ?? sysctlInt("hw.physicalcpu") ?? 0
        let eff = sysctlInt("hw.perflevel1.physicalcpu") ?? 0
        return (perf, eff)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname(name, &value, &size, nil, 0)
        return result == 0 ? Int(value) : nil
    }

    private static func uptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 else { return 0 }
        let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec) + TimeInterval(boottime.tv_usec) / 1_000_000)
        return Date().timeIntervalSince(bootDate)
    }
}
