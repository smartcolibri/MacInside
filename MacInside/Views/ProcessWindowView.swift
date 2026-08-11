import SwiftUI
import AppKit

/// Fenêtre « Processus » : liste complète triable, colonnes masquables
/// (clic droit sur les en-têtes, persisté), recherche multi-termes/regex,
/// filtres numériques et par statut, épinglage persistant et fiche détail.
/// Les actions (terminer, forcer l'arrêt, baisser la priorité) réutilisent
/// `ProcessMonitor`, déjà en place pour les top 6.
struct ProcessWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    @State private var sortOrder = [KeyPathComparator(\ProcessEntry.cpuPercent, order: .reverse)]
    @SceneStorage("processTableColumns")
    private var columnCustomization = TableColumnCustomization<ProcessEntry>()
    @State private var selection = Set<ProcessEntry.ID>()
    @State private var searchText = ""
    @State private var criteria = ProcessFilterCriteria()
    @State private var isFiltersPresented = false
    @State private var detailTarget: ProcessDetailTarget?
    @State private var pendingTermination: (entry: ProcessEntry, force: Bool)?

    var body: some View {
        table
            .searchable(text: $searchText,
                        prompt: Text("Rechercher : nom, commande ou PID (virgules = OU, regex acceptées)"))
            .toolbar { toolbarContent }
            .navigationTitle("Processus")
            .navigationSubtitle(Text("\(displayedEntries.count) / \(model.processList.entries.count) processus"))
            .sheet(item: $detailTarget) { target in
                ProcessDetailView(pid: target.id) { detailTarget = ProcessDetailTarget(id: $0) }
                    .environment(model)
            }
            .confirmationDialog(confirmationTitle,
                                isPresented: isPendingTerminationPresented,
                                titleVisibility: .visible) {
                if let pendingTermination {
                    Button(pendingTermination.force
                           ? String(localized: "Forcer l'arrêt")
                           : String(localized: "Terminer"),
                           role: .destructive) {
                        ProcessMonitor.terminate(pid: pendingTermination.entry.pid,
                                                 force: pendingTermination.force)
                        self.pendingTermination = nil
                    }
                    Button("Annuler", role: .cancel) { self.pendingTermination = nil }
                }
            }
            .onAppear { model.isProcessListActive = true }
            .onDisappear { model.isProcessListActive = false }
    }

    // MARK: - Données affichées

    private var displayedEntries: [ProcessEntry] {
        var criteria = criteria
        criteria.searchText = searchText
        var entries = ProcessFilter.apply(criteria, to: model.processList.entries)
        entries.sort(using: sortOrder)

        // Épinglés en tête, dans l'ordre du tri courant.
        let pinned = settings.pinnedProcessCommands
        guard !pinned.isEmpty else { return entries }
        return entries.filter { pinned.contains($0.pinKey) }
            + entries.filter { !pinned.contains($0.pinKey) }
    }

    /// Mêmes seuils que NeoHtop : CPU > 50 % ou > 10 % de la RAM totale.
    private func isHighUsage(_ entry: ProcessEntry) -> Bool {
        entry.cpuPercent > 50
            || (model.memory.totalBytes > 0
                && Double(entry.residentBytes) > Double(model.memory.totalBytes) * 0.1)
    }

    private func entry(for id: ProcessEntry.ID) -> ProcessEntry? {
        model.processList.entries.first { $0.pid == id }
    }

    // MARK: - Table

    private var table: some View {
        Table(displayedEntries, selection: $selection, sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Nom", value: \.name) { (entry: ProcessEntry) in
                    HStack(spacing: 6) {
                        Image(nsImage: ProcessIconCache.shared.icon(for: entry.pid))
                        Text(entry.name)
                            .foregroundStyle(isHighUsage(entry)
                                             ? AnyShapeStyle(.orange)
                                             : AnyShapeStyle(.primary))
                        if settings.pinnedProcessCommands.contains(entry.pinKey) {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 140, ideal: 220)
                .customizationID("name")
                .disabledCustomizationBehavior(.visibility)

                TableColumn("PID", value: \.pid) { (entry: ProcessEntry) in
                    Text(String(entry.pid)).monospacedDigit()
                }
                .width(min: 44, ideal: 56)
                .customizationID("pid")

                TableColumn("Utilisateur", value: \.user)
                    .width(min: 60, ideal: 90)
                    .customizationID("user")

                TableColumn("Statut", value: \.stateLabel)
                    .width(min: 60, ideal: 80)
                    .customizationID("state")

                TableColumn("CPU", value: \.cpuPercent) { (entry: ProcessEntry) in
                    Text(Formatters.percent(entry.cpuPercent, decimals: 1)).monospacedDigit()
                }
                .width(min: 52, ideal: 64)
                .customizationID("cpu")
            }

            Group {
                TableColumn("Mémoire", value: \.residentBytes) { (entry: ProcessEntry) in
                    Text(Formatters.bytes(entry.residentBytes)).monospacedDigit()
                }
                .width(min: 64, ideal: 84)
                .customizationID("memory")

                TableColumn("Mémoire virtuelle", value: \.virtualBytes) { (entry: ProcessEntry) in
                    Text(Formatters.bytes(entry.virtualBytes)).monospacedDigit()
                }
                .width(min: 64, ideal: 96)
                .defaultVisibility(.hidden)
                .customizationID("virtualMemory")

                TableColumn("Threads", value: \.threadCount) { (entry: ProcessEntry) in
                    Text(String(entry.threadCount)).monospacedDigit()
                }
                .width(min: 44, ideal: 56)
                .defaultVisibility(.hidden)
                .customizationID("threads")

                TableColumn("E/S lecture", value: \.diskReadBytes) { (entry: ProcessEntry) in
                    Text(Formatters.bytes(entry.diskReadBytes)).monospacedDigit()
                }
                .width(min: 64, ideal: 84)
                .customizationID("diskRead")

                TableColumn("E/S écriture", value: \.diskWriteBytes) { (entry: ProcessEntry) in
                    Text(Formatters.bytes(entry.diskWriteBytes)).monospacedDigit()
                }
                .width(min: 64, ideal: 84)
                .customizationID("diskWrite")
            }

            Group {
                TableColumn("Temps d'exécution", value: \.runTime) { (entry: ProcessEntry) in
                    Text(Formatters.uptime(entry.runTime)).monospacedDigit()
                }
                .width(min: 70, ideal: 90)
                .customizationID("runTime")

                TableColumn("Démarré", value: \.startTimestamp) { (entry: ProcessEntry) in
                    if let date = entry.startDate {
                        Text(date, format: .dateTime.day().month().hour().minute())
                    } else {
                        Text(verbatim: "—")
                    }
                }
                .width(min: 90, ideal: 120)
                .defaultVisibility(.hidden)
                .customizationID("started")

                TableColumn("PID parent", value: \.parentPID) { (entry: ProcessEntry) in
                    Text(String(entry.parentPID)).monospacedDigit()
                }
                .width(min: 56, ideal: 70)
                .defaultVisibility(.hidden)
                .customizationID("parentPID")

                TableColumn("Commande", value: \.command) { (entry: ProcessEntry) in
                    Text(entry.command)
                        .truncationMode(.middle)
                        .help(entry.command)
                }
                .width(min: 120, ideal: 280)
                .defaultVisibility(.hidden)
                .customizationID("command")
            }
        }
        .contextMenu(forSelectionType: ProcessEntry.ID.self) { ids in
            if let id = ids.first, let entry = entry(for: id) {
                contextMenu(for: entry)
            }
        } primaryAction: { ids in
            if let id = ids.first { detailTarget = ProcessDetailTarget(id: id) }
        }
    }

    @ViewBuilder
    private func contextMenu(for entry: ProcessEntry) -> some View {
        Button(settings.pinnedProcessCommands.contains(entry.pinKey)
               ? String(localized: "Désépingler")
               : String(localized: "Épingler")) {
            togglePin(entry)
        }
        Button("Détails") { detailTarget = ProcessDetailTarget(id: entry.pid) }
        Divider()
        Button("Baisser la priorité") { ProcessMonitor.lowerPriority(pid: entry.pid) }
        Divider()
        Button("Terminer") { pendingTermination = (entry, false) }
        Button("Forcer l'arrêt", role: .destructive) { pendingTermination = (entry, true) }
    }

    private func togglePin(_ entry: ProcessEntry) {
        var pinned = settings.pinnedProcessCommands
        if pinned.contains(entry.pinKey) {
            pinned.remove(entry.pinKey)
        } else {
            pinned.insert(entry.pinKey)
        }
        settings.pinnedProcessCommands = pinned
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                model.isFrozen.toggle()
            } label: {
                Label(model.isFrozen ? "Reprendre" : "Mettre en pause",
                      systemImage: model.isFrozen ? "play.fill" : "pause.fill")
            }
            .help(model.isFrozen ? Text("Reprendre") : Text("Mettre en pause"))
        }
        ToolbarItem {
            Button {
                isFiltersPresented.toggle()
            } label: {
                Label("Filtres",
                      systemImage: criteria.activeFilterCount > 0
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .help(Text("Filtres"))
            .popover(isPresented: $isFiltersPresented) {
                ProcessFiltersView(criteria: $criteria)
            }
        }
    }

    // MARK: - Confirmation

    private var confirmationTitle: String {
        guard let pendingTermination else { return "" }
        return pendingTermination.force
            ? String(localized: "Forcer l'arrêt de « \(pendingTermination.entry.name) » ?")
            : String(localized: "Terminer « \(pendingTermination.entry.name) » ?")
    }

    private var isPendingTerminationPresented: Binding<Bool> {
        Binding(get: { pendingTermination != nil },
                set: { if !$0 { pendingTermination = nil } })
    }
}

private struct ProcessDetailTarget: Identifiable {
    let id: Int32
}

/// Popover des filtres : trois seuils numériques avec opérateur, et un filtre
/// par statut. `Tout effacer` remet les critères à zéro (la recherche, elle,
/// vit dans le champ de la toolbar).
private struct ProcessFiltersView: View {
    @Binding var criteria: ProcessFilterCriteria

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            numericFilter("CPU (%)",
                          enabled: $criteria.cpuEnabled,
                          above: $criteria.cpuAbove,
                          value: $criteria.cpuThreshold)
            numericFilter("Mémoire (Mo)",
                          enabled: $criteria.memoryEnabled,
                          above: $criteria.memoryAbove,
                          value: $criteria.memoryThresholdMB)
            numericFilter("Durée (min)",
                          enabled: $criteria.runtimeEnabled,
                          above: $criteria.runtimeAbove,
                          value: $criteria.runtimeThresholdMinutes)

            Divider()

            Text("Statut")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(ProcessState.filterable) { state in
                Toggle(state.label, isOn: stateBinding(state))
            }

            Divider()

            Button("Tout effacer") { criteria = ProcessFilterCriteria() }
                .disabled(criteria.activeFilterCount == 0)
        }
        .padding(16)
        .frame(width: 250)
    }

    private func numericFilter(_ label: LocalizedStringKey,
                               enabled: Binding<Bool>,
                               above: Binding<Bool>,
                               value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Toggle(label, isOn: enabled)
                .frame(width: 110, alignment: .leading)
            Picker("", selection: above) {
                Text(verbatim: ">").tag(true)
                Text(verbatim: "<").tag(false)
            }
            .labelsHidden()
            .frame(width: 46)
            TextField("", value: value, format: .number)
                .labelsHidden()
                .frame(width: 60)
        }
        .disabled(false)
    }

    private func stateBinding(_ state: ProcessState) -> Binding<Bool> {
        Binding(
            get: { criteria.states.contains(state) },
            set: { included in
                if included {
                    criteria.states.insert(state)
                } else {
                    criteria.states.remove(state)
                }
            }
        )
    }
}

/// Icônes des process : vraie icône d'app via `NSRunningApplication` quand le
/// PID correspond à une app, icône générique d'exécutable sinon. Cachées par
/// PID — recalculer une NSImage par ligne et par tick serait ruineux.
@MainActor
final class ProcessIconCache {
    static let shared = ProcessIconCache()

    private var icons: [Int32: NSImage] = [:]

    func icon(for pid: Int32) -> NSImage {
        if let cached = icons[pid] { return cached }
        // Borne de sécurité : au-delà de quelques milliers de PID recyclés,
        // repartir de zéro plutôt que de grossir indéfiniment.
        if icons.count > 4096 { icons.removeAll(keepingCapacity: true) }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
            ?? NSWorkspace.shared.icon(for: .unixExecutable)
        icon.size = NSSize(width: 16, height: 16)
        icons[pid] = icon
        return icon
    }
}
