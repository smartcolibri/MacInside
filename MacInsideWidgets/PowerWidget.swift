import SwiftUI
import WidgetKit

struct PowerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.vincentlauriat.macinside.widget.power",
                            provider: SnapshotProvider()) { entry in
            PowerWidgetView(entry: entry)
        }
        .configurationDisplayName("Alimentation")
        .description("Tension, courant et puissance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PowerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let power = entry.snapshot?.power {
                content(power, capturedAt: entry.snapshot!.capturedAt)
            } else {
                WidgetUnavailable(reason: entry.result)
            }
        }
        .widgetChrome()
    }

    @ViewBuilder
    private func content(_ power: WidgetSnapshot.Power, capturedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            WidgetHeader(title: "Alimentation", systemImage: "bolt.fill")

            if !power.available {
                Text("Capteurs indisponibles sur ce Mac")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if power.readings.isEmpty {
                Text("Aucune donnée d'alimentation")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(power.readings.prefix(family == .systemMedium ? WidgetSnapshot.powerLimit : 3),
                        id: \.label) { reading in
                    WidgetRow(raw: reading.label,
                              String(format: "%.2f %@", reading.value, reading.unit))
                }
            }

            Spacer(minLength: 0)
            WidgetTimestamp(date: capturedAt)
        }
    }
}
