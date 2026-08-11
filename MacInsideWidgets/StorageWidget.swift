import SwiftUI
import WidgetKit

struct StorageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.vincentlauriat.macinside.widget.storage",
                            provider: SnapshotProvider()) { entry in
            StorageWidgetView(entry: entry)
        }
        .configurationDisplayName("Stockage")
        .description("Espace disque, volumes externes et débit d'E/S.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StorageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let storage = entry.snapshot?.storage {
                content(storage, capturedAt: entry.snapshot!.capturedAt)
            } else {
                WidgetUnavailable(reason: entry.result)
            }
        }
        .widgetChrome()
    }

    @ViewBuilder
    private func content(_ storage: WidgetSnapshot.Storage, capturedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Stockage", systemImage: "internaldrive")

            if let volume = storage.systemVolume {
                WidgetValue(text: Formatters.percent(volume.usedPercent))
                ProgressView(value: volume.usedPercent, total: 100)
                    .tint(.accentColor)
                if family == .systemMedium {
                    Text("\(Formatters.bytes(volume.usedBytes)) utilisés sur \(Formatters.bytes(volume.totalBytes)) (\(Formatters.bytes(volume.availableBytes)) disponibles)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    WidgetRow(raw: volume.name,
                              "\(Formatters.bytes(volume.usedBytes)) / \(Formatters.bytes(volume.totalBytes))")
                }
            } else {
                Text("Volume système indisponible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            WidgetRow("Lecture", Formatters.bytesPerSecond(storage.readBytesPerSec))
            WidgetRow("Écriture", Formatters.bytesPerSecond(storage.writeBytesPerSec))

            if family == .systemMedium, !storage.externalVolumes.isEmpty {
                Divider()
                ForEach(storage.externalVolumes, id: \.name) { volume in
                    WidgetRow(raw: volume.name,
                              "\(Formatters.bytes(volume.usedBytes)) / \(Formatters.bytes(volume.totalBytes))")
                }
            }

            Spacer(minLength: 0)
            WidgetTimestamp(date: capturedAt)
        }
    }
}
