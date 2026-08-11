import Foundation
import Darwin

/// Liste complète des processus pour la fenêtre Processus, via `libproc` et
/// `sysctl` — même famille d'APIs que `ProcessMonitor` (top 6), mais collecte
/// tout le détail par process.
///
/// Sensiblement plus lourd que le top 6 (3 appels noyau par process au lieu
/// d'un) : `AppModel` ne l'appelle que quand la fenêtre Processus est ouverte.
/// Les champs immuables d'un process vivant (commande, utilisateur, date de
/// démarrage) sont mis en cache par PID et invalidés sur changement de date de
/// démarrage — un PID recyclé par le noyau ne doit pas hériter de la commande
/// de son prédécesseur.
final class ProcessListMonitor {
    private struct CPUSample { var totalTimeNanos: UInt64; var date: Date }
    private struct StaticInfo { var startSec: UInt64; var command: String; var user: String }

    private var previousSamples: [Int32: CPUSample] = [:]
    private var staticInfoCache: [Int32: StaticInfo] = [:]
    private var userNameCache: [uid_t: String] = [:]
    private let timebase: mach_timebase_info = {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return info
    }()

    func snapshot() -> ProcessListStats {
        let now = Date()
        var entries: [ProcessEntry] = []
        var seen = Set<Int32>()

        for pid in listPIDs() where pid > 0 {
            var bsdInfo = proc_bsdinfo()
            let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
            let bsdResult = withUnsafeMutablePointer(to: &bsdInfo) {
                proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0, bsdSize)
            }
            guard bsdResult == bsdSize else { continue }
            seen.insert(pid)

            // Un zombie n'a plus de task : continuer avec des compteurs à zéro
            // plutôt que de le faire disparaître de la liste.
            var taskInfo = proc_taskinfo()
            let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let hasTask = withUnsafeMutablePointer(to: &taskInfo) {
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, $0, taskSize)
            } == taskSize

            var cpuPercent = 0.0
            if hasTask {
                let ticks = taskInfo.pti_total_user + taskInfo.pti_total_system
                let nanos = ticks * UInt64(timebase.numer) / UInt64(max(timebase.denom, 1))
                if let previous = previousSamples[pid] {
                    let elapsed = now.timeIntervalSince(previous.date)
                    if elapsed > 0, nanos >= previous.totalTimeNanos {
                        cpuPercent = Double(nanos - previous.totalTimeNanos) / 1_000_000_000 / elapsed * 100
                    }
                }
                previousSamples[pid] = CPUSample(totalTimeNanos: nanos, date: now)
            }

            var diskReadBytes: UInt64 = 0
            var diskWriteBytes: UInt64 = 0
            var rusage = rusage_info_current()
            let rusageOK = withUnsafeMutablePointer(to: &rusage) { pointer in
                pointer.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            } == 0
            if rusageOK {
                diskReadBytes = rusage.ri_diskio_bytesread
                diskWriteBytes = rusage.ri_diskio_byteswritten
            }

            let statics = staticInfo(pid: pid, bsdInfo: bsdInfo)
            let startDate = statics.startSec > 0
                ? Date(timeIntervalSince1970: TimeInterval(statics.startSec)) : nil

            entries.append(ProcessEntry(
                pid: pid,
                parentPID: Int32(bitPattern: bsdInfo.pbi_ppid),
                name: processName(pid) ?? Self.commName(bsdInfo),
                user: statics.user,
                state: Self.state(from: bsdInfo.pbi_status),
                cpuPercent: max(cpuPercent, 0),
                residentBytes: hasTask ? taskInfo.pti_resident_size : 0,
                virtualBytes: hasTask ? taskInfo.pti_virtual_size : 0,
                threadCount: hasTask ? Int(taskInfo.pti_threadnum) : 0,
                startDate: startDate,
                runTime: startDate.map { max(now.timeIntervalSince($0), 0) } ?? 0,
                diskReadBytes: diskReadBytes,
                diskWriteBytes: diskWriteBytes,
                command: statics.command
            ))
        }

        // Éviction des PID disparus, sinon les caches grossissent sans borne.
        previousSamples = previousSamples.filter { seen.contains($0.key) }
        staticInfoCache = staticInfoCache.filter { seen.contains($0.key) }

        return ProcessListStats(entries: entries, capturedAt: now)
    }

    /// Variables d'environnement d'un process, à la demande (fiche détail) —
    /// jamais collectées à chaque tick. Vide si le noyau refuse l'accès
    /// (process d'un autre utilisateur) ou si le process a disparu.
    func environment(pid: Int32) -> [String] {
        procArgs(pid: pid)?.environment ?? []
    }

    // MARK: - Champs immuables (cachés par PID)

    private func staticInfo(pid: Int32, bsdInfo: proc_bsdinfo) -> StaticInfo {
        let startSec = bsdInfo.pbi_start_tvsec
        if let cached = staticInfoCache[pid], cached.startSec == startSec {
            return cached
        }
        let command = procArgs(pid: pid)?.command
            ?? executablePath(pid) ?? ""
        let info = StaticInfo(startSec: startSec,
                              command: command,
                              user: userName(uid: bsdInfo.pbi_uid))
        staticInfoCache[pid] = info
        return info
    }

    private func userName(uid: uid_t) -> String {
        if let cached = userNameCache[uid] { return cached }
        let name = getpwuid(uid).map { String(cString: $0.pointee.pw_name) } ?? String(uid)
        userNameCache[uid] = name
        return name
    }

    /// Arguments et environnement via `KERN_PROCARGS2` : un `Int32` (argc),
    /// le chemin de l'exécutable, du bourrage NUL, puis argv et env séparés
    /// par des NUL.
    private func procArgs(pid: Int32) -> (command: String, environment: [String])? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else { return nil }

        let argc = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
        guard argc > 0 else { return nil }

        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var strings: [String] = []
        var current: [UInt8] = []
        while index < size {
            if buffer[index] == 0 {
                if current.isEmpty {
                    // Double NUL après la zone env : fin des données utiles.
                    if strings.count >= argc { break }
                } else {
                    strings.append(String(decoding: current, as: UTF8.self))
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(buffer[index])
            }
            index += 1
        }
        guard strings.count >= argc else { return nil }

        // Une commande multi-ligne casserait la persistance des épinglages
        // (séparateur `\n` dans AppSettings) : aplatie ici, à la source.
        let command = strings.prefix(argc).joined(separator: " ")
            .replacingOccurrences(of: "\n", with: " ")
        return (command, Array(strings.dropFirst(argc)))
    }

    private func executablePath(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * 1024)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    // MARK: - Helpers partagés avec ProcessMonitor (mêmes conventions)

    private func listPIDs() -> [Int32] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(bufferSize) / MemoryLayout<Int32>.size)
        let written = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard written > 0 else { return [] }
        return Array(pids.prefix(Int(written)))
    }

    private func processName(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * 1024)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    /// `pbi_comm` en dernier recours (les zombies échouent sur `proc_name`).
    private static func commName(_ info: proc_bsdinfo) -> String {
        withUnsafeBytes(of: info.pbi_comm) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    /// Valeurs de `sys/proc.h`, macros non pontées vers Swift :
    /// SIDL=1, SRUN=2, SSLEEP=3, SSTOP=4, SZOMB=5.
    private static func state(from status: UInt32) -> ProcessState {
        switch status {
        case 2: return .running
        case 3: return .sleeping
        case 4: return .stopped
        case 5: return .zombie
        default: return .unknown
        }
    }
}
