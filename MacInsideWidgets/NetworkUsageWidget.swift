import SwiftUI
import WidgetKit

struct NetworkUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.vincentlauriat.macinside.widget.networkusage",
                            provider: SnapshotProvider()) { entry in
            NetworkUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Débit réseau")
        .description("Débit descendant et montant du réseau.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NetworkUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let usage = entry.snapshot?.networkUsage {
                content(usage, capturedAt: entry.snapshot!.capturedAt)
            } else {
                WidgetUnavailable(reason: entry.result)
            }
        }
        .widgetChrome()
    }

    private func content(_ usage: WidgetSnapshot.NetworkUsage, capturedAt: Date) -> some View {
        let sparklineHeight: CGFloat = family == .systemMedium ? 26 : 16
        return VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "Débit réseau", systemImage: "arrow.up.arrow.down")

            WidgetRow("Download", Formatters.bytesPerSecond(usage.downloadBytesPerSec))
            if !usage.downloadHistory.isEmpty {
                WidgetSparkline(values: usage.downloadHistory, color: .blue)
                    .frame(height: sparklineHeight)
            }

            WidgetRow("Upload", Formatters.bytesPerSecond(usage.uploadBytesPerSec))
            if !usage.uploadHistory.isEmpty {
                WidgetSparkline(values: usage.uploadHistory, color: .orange)
                    .frame(height: sparklineHeight)
            }

            if family == .systemMedium {
                WidgetRow("Total depuis le lancement",
                          "↓ \(Formatters.bytes(usage.totalDownloadBytes))  ↑ \(Formatters.bytes(usage.totalUploadBytes))")
            }

            Spacer(minLength: 0)
            WidgetTimestamp(date: capturedAt)
        }
    }
}
