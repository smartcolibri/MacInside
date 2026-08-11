import SwiftUI

/// Bandeau d'identité machine en haut du tableau de bord.
struct HeaderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let identity = model.identity

        HStack(alignment: .top, spacing: 24) {
            HStack(spacing: 14) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.hostname.isEmpty ? "Mac" : identity.hostname)
                        .font(.title.weight(.semibold))
                    Text(identity.osVersion.isEmpty ? "—" : identity.osVersion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 24)

            HStack(alignment: .top, spacing: 32) {
                infoColumn {
                    infoRow("Puce", identity.chipName.isEmpty ? "—" : identity.chipName)
                    infoRow("Carte graphique", identity.gpuName.isEmpty ? "—" : identity.gpuName)
                    infoRow("Mémoire", Formatters.bytes(model.memory.totalBytes))
                    infoRow("Stockage", Formatters.bytes(model.disk.systemVolume?.totalBytes ?? 0))
                }

                infoColumn {
                    infoRow("Identifiant", identity.modelIdentifier.isEmpty ? "—" : identity.modelIdentifier)
                    infoRow("Architecture", identity.architecture.isEmpty ? "—" : identity.architecture)
                    HStack(spacing: 6) {
                        Text("Cœurs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.blue)
                            Text("\(identity.performanceCoreCount)")
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.teal)
                            Text("\(identity.efficiencyCoreCount)")
                        }
                        .font(.caption.monospacedDigit())
                    }
                    infoRow("Threads", "\(identity.threadCount)")
                }

                infoColumn {
                    infoRow("Modèle", identity.modelName.isEmpty ? "—" : identity.modelName)
                    infoRow("Numéro de série", identity.serialNumber.isEmpty ? "—" : identity.serialNumber)
                    infoRow("Uptime", Formatters.uptime(identity.uptime))
                    infoRow("Charge moyenne", identity.loadAverage.isEmpty
                        ? "—"
                        : identity.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                    HStack(spacing: 6) {
                        Text("État thermique")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Circle()
                            .fill(thermalColor(identity.thermalState))
                            .frame(width: 8, height: 8)
                        Text(thermalLabel(identity.thermalState))
                            .font(.caption)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    @ViewBuilder
    private func infoColumn<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .frame(minWidth: 150, alignment: .leading)
    }

    private func infoRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func thermalColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return String(localized: "Normal")
        case .fair: return String(localized: "Correct")
        case .serious: return String(localized: "Élevé")
        case .critical: return String(localized: "Critique")
        @unknown default: return String(localized: "Inconnu")
        }
    }
}
