import SwiftUI
import AppKit

/// Fiche détail d'un process : identité, compteurs, commande complète,
/// navigation cliquable dans la parenté (parent ↔ enfants, idée reprise de
/// NeoHtop) et variables d'environnement lues à la demande.
struct ProcessDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let pid: Int32
    /// Appelé pour naviguer vers un autre process (parent ou enfant) dans la
    /// même feuille.
    let onNavigate: (Int32) -> Void

    @State private var environmentVariables: [String] = []

    private var entry: ProcessEntry? {
        model.processList.entries.first { $0.pid == pid }
    }

    private var children: [ProcessEntry] {
        model.processList.entries
            .filter { $0.parentPID == pid }
            .sorted { $0.pid < $1.pid }
    }

    private var parent: ProcessEntry? {
        guard let entry else { return nil }
        return model.processList.entries.first { $0.pid == entry.parentPID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry {
                header(entry)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        infoSection(entry)
                        commandSection(entry)
                        parentSection(entry)
                        childrenSection
                        environmentSection
                    }
                    .padding(16)
                }
            } else {
                // Le process a disparu entre l'ouverture de la fiche et le
                // tick courant.
                Text("Processus terminé")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            HStack {
                Spacer()
                Button("Fermer") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 540, height: 560)
        .task(id: pid) {
            environmentVariables = model.processEnvironment(pid: pid)
        }
    }

    private func header(_ entry: ProcessEntry) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: ProcessIconCache.shared.icon(for: entry.pid))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: "PID \(entry.pid) · \(entry.stateLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatters.percent(entry.cpuPercent, decimals: 1))
                .font(.title3.monospacedDigit())
        }
        .padding(16)
    }

    private func infoSection(_ entry: ProcessEntry) -> some View {
        VStack(spacing: 6) {
            row("Utilisateur", entry.user)
            row("Mémoire", Formatters.bytes(entry.residentBytes))
            row("Mémoire virtuelle", Formatters.bytes(entry.virtualBytes))
            row("Threads", String(entry.threadCount))
            row("E/S lecture", Formatters.bytes(entry.diskReadBytes))
            row("E/S écriture", Formatters.bytes(entry.diskWriteBytes))
            row("Temps d'exécution", Formatters.uptime(entry.runTime))
            if let date = entry.startDate {
                HStack {
                    Text("Démarré")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption.monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private func commandSection(_ entry: ProcessEntry) -> some View {
        if !entry.command.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("Commande")
                Text(entry.command)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder
    private func parentSection(_ entry: ProcessEntry) -> some View {
        if let parent {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("Processus parent")
                processLink(parent)
            }
        }
    }

    @ViewBuilder
    private var childrenSection: some View {
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("Processus enfants")
                ForEach(children) { child in
                    processLink(child)
                }
            }
        }
    }

    @ViewBuilder
    private var environmentSection: some View {
        if !environmentVariables.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("Variables d'environnement")
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(environmentVariables, id: \.self) { variable in
                        Text(variable)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func processLink(_ target: ProcessEntry) -> some View {
        Button {
            onNavigate(target.pid)
        } label: {
            HStack(spacing: 6) {
                Image(nsImage: ProcessIconCache.shared.icon(for: target.pid))
                Text(target.name)
                    .lineLimit(1)
                Text(verbatim: "PID \(target.pid)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .buttonStyle(.link)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}
