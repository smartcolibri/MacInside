import XCTest
@testable import MacInside

/// Le filtrage de la fenêtre Processus est la partie testable sans UI (les
/// interactions `Table`/`searchable` ne s'automatisent pas dans cet
/// environnement) : recherche multi-termes/regex et seuils numériques.
final class ProcessFilterTests: XCTestCase {
    private func entry(pid: Int32 = 1,
                       name: String = "proc",
                       command: String = "",
                       cpu: Double = 0,
                       residentMB: Double = 0,
                       runMinutes: Double = 0,
                       state: ProcessState = .running) -> ProcessEntry {
        ProcessEntry(pid: pid, parentPID: 0, name: name, user: "vincent",
                     state: state, cpuPercent: cpu,
                     residentBytes: UInt64(residentMB * 1_048_576),
                     virtualBytes: 0, threadCount: 1, startDate: nil,
                     runTime: runMinutes * 60, diskReadBytes: 0,
                     diskWriteBytes: 0, command: command)
    }

    func testEmptyCriteriaKeepsEverything() {
        let entries = [entry(pid: 1), entry(pid: 2)]
        XCTAssertEqual(ProcessFilter.apply(ProcessFilterCriteria(), to: entries).count, 2)
    }

    func testSearchMatchesNameCommandAndPID() {
        let entries = [
            entry(pid: 101, name: "Safari"),
            entry(pid: 202, name: "helper", command: "/usr/bin/safari-agent --daemon"),
            entry(pid: 303, name: "Xcode"),
        ]
        var criteria = ProcessFilterCriteria()

        criteria.searchText = "safari"
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [101, 202])

        criteria.searchText = "303"
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [303])
    }

    /// Termes séparés par des virgules = OU logique (comportement NeoHtop).
    func testCommaSeparatedTermsAreORed() {
        let entries = [entry(pid: 1, name: "Safari"), entry(pid: 2, name: "Xcode"),
                       entry(pid: 3, name: "Finder")]
        var criteria = ProcessFilterCriteria()
        criteria.searchText = "safari, xcode"
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1, 2])
    }

    func testRegexSearch() {
        let entries = [entry(pid: 1, name: "launchd"), entry(pid: 2, name: "systemd"),
                       entry(pid: 3, name: "Finder")]
        var criteria = ProcessFilterCriteria()
        // Daemons : se termine par « d » — l'exemple canonique de NeoHtop.
        criteria.searchText = "d$"
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1, 2])
    }

    /// Un motif regex invalide (parenthèse non fermée) doit se replier sur
    /// une recherche de sous-chaîne, pas tout rejeter ni planter.
    func testInvalidRegexFallsBackToSubstring() {
        let entries = [entry(pid: 1, name: "helper(v2)"), entry(pid: 2, name: "swift")]
        var criteria = ProcessFilterCriteria()
        criteria.searchText = "helper("
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1])
    }

    func testNumericThresholdsWithBothOperators() {
        let entries = [entry(pid: 1, cpu: 80, residentMB: 1000, runMinutes: 90),
                       entry(pid: 2, cpu: 5, residentMB: 50, runMinutes: 10)]
        var criteria = ProcessFilterCriteria()

        criteria.cpuEnabled = true
        criteria.cpuThreshold = 50
        criteria.cpuAbove = true
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1])
        criteria.cpuAbove = false
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [2])
        criteria = ProcessFilterCriteria()

        criteria.memoryEnabled = true
        criteria.memoryThresholdMB = 500
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1])
        criteria = ProcessFilterCriteria()

        criteria.runtimeEnabled = true
        criteria.runtimeThresholdMinutes = 60
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1])
    }

    func testStateFilter() {
        let entries = [entry(pid: 1, state: .running), entry(pid: 2, state: .zombie)]
        var criteria = ProcessFilterCriteria()
        criteria.states = [.zombie]
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [2])
    }

    /// Filtres et recherche se cumulent (ET entre familles de critères).
    func testFiltersAndSearchCombine() {
        let entries = [entry(pid: 1, name: "Safari", cpu: 80),
                       entry(pid: 2, name: "Safari", cpu: 5),
                       entry(pid: 3, name: "Xcode", cpu: 90)]
        var criteria = ProcessFilterCriteria()
        criteria.searchText = "safari"
        criteria.cpuEnabled = true
        criteria.cpuThreshold = 50
        XCTAssertEqual(ProcessFilter.apply(criteria, to: entries).map(\.pid), [1])
    }

    func testActiveFilterCountIgnoresSearch() {
        var criteria = ProcessFilterCriteria()
        criteria.searchText = "safari"
        XCTAssertEqual(criteria.activeFilterCount, 0)
        criteria.cpuEnabled = true
        criteria.states = [.running]
        XCTAssertEqual(criteria.activeFilterCount, 2)
    }
}
