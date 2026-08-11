import Foundation

/// Critères de la fenêtre Processus : recherche textuelle + filtres
/// numériques + filtre par statut. Struct valeur pure, testable sans UI.
struct ProcessFilterCriteria: Equatable {
    var searchText = ""

    var cpuEnabled = false
    var cpuAbove = true
    var cpuThreshold: Double = 50

    var memoryEnabled = false
    var memoryAbove = true
    var memoryThresholdMB: Double = 500

    var runtimeEnabled = false
    var runtimeAbove = true
    var runtimeThresholdMinutes: Double = 60

    /// Vide = tous les statuts acceptés.
    var states: Set<ProcessState> = []

    /// Nombre de filtres actifs (hors recherche), pour le badge de la toolbar.
    var activeFilterCount: Int {
        (cpuEnabled ? 1 : 0) + (memoryEnabled ? 1 : 0) + (runtimeEnabled ? 1 : 0)
            + (states.isEmpty ? 0 : 1)
    }
}

/// Filtrage pur, inspiré de la recherche NeoHtop : termes séparés par des
/// virgules (OU logique), chaque terme essayé comme regex insensible à la
/// casse (repli sur une recherche de sous-chaîne si le motif est invalide),
/// confronté au nom, à la ligne de commande et au PID.
enum ProcessFilter {
    static func apply(_ criteria: ProcessFilterCriteria, to entries: [ProcessEntry]) -> [ProcessEntry] {
        // Regex compilées une fois par application du filtre (à chaque tick),
        // pas une fois par ligne.
        let terms = searchTerms(criteria.searchText).map { term in
            (term, try? NSRegularExpression(pattern: term, options: [.caseInsensitive]))
        }
        return entries.filter { matches($0, criteria: criteria, terms: terms) }
    }

    static func searchTerms(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func matches(_ entry: ProcessEntry,
                                criteria: ProcessFilterCriteria,
                                terms: [(String, NSRegularExpression?)]) -> Bool {
        if criteria.cpuEnabled {
            let passes = criteria.cpuAbove
                ? entry.cpuPercent > criteria.cpuThreshold
                : entry.cpuPercent < criteria.cpuThreshold
            guard passes else { return false }
        }
        if criteria.memoryEnabled {
            let thresholdBytes = criteria.memoryThresholdMB * 1_048_576
            let passes = criteria.memoryAbove
                ? Double(entry.residentBytes) > thresholdBytes
                : Double(entry.residentBytes) < thresholdBytes
            guard passes else { return false }
        }
        if criteria.runtimeEnabled {
            let thresholdSeconds = criteria.runtimeThresholdMinutes * 60
            let passes = criteria.runtimeAbove
                ? entry.runTime > thresholdSeconds
                : entry.runTime < thresholdSeconds
            guard passes else { return false }
        }
        if !criteria.states.isEmpty {
            guard criteria.states.contains(entry.state) else { return false }
        }

        guard !terms.isEmpty else { return true }
        let haystacks = [entry.name, entry.command, String(entry.pid)]
        return terms.contains { term, regex in
            if let regex {
                return haystacks.contains { haystack in
                    regex.firstMatch(in: haystack,
                                     range: NSRange(haystack.startIndex..., in: haystack)) != nil
                }
            }
            return haystacks.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }
}
