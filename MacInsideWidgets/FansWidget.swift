import SwiftUI
import WidgetKit

struct FansWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.vincentlauriat.macinside.widget.fans",
                            provider: SnapshotProvider()) { entry in
            FansWidgetView(entry: entry)
        }
        .configurationDisplayName("Ventilateurs")
        .description("Vitesse des ventilateurs.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FansWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let fans = entry.snapshot?.fans {
                content(fans, capturedAt: entry.snapshot!.capturedAt)
            } else {
                WidgetUnavailable(reason: entry.result)
            }
        }
        .widgetChrome()
    }

    @ViewBuilder
    private func content(_ fans: WidgetSnapshot.Fans, capturedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Ventilateurs", systemImage: "fan")

            if !fans.available {
                Text("Capteurs indisponibles sur ce Mac")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !fans.hasFans {
                Text("Pas de ventilateur sur ce Mac")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fans.readings.prefix(family == .systemMedium ? 4 : 2), id: \.label) { fan in
                    VStack(alignment: .leading, spacing: 2) {
                        WidgetRow(raw: fan.label, String(localized: "\(fan.rpm) tr/min"))
                        ProgressView(value: min(fan.percent, 100), total: 100)
                            .tint(.cyan)
                    }
                }
            }

            Spacer(minLength: 0)
            WidgetTimestamp(date: capturedAt)
        }
    }
}
