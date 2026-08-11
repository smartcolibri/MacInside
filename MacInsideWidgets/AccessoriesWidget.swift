import SwiftUI
import WidgetKit

struct AccessoriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.vincentlauriat.macinside.widget.accessories",
                            provider: SnapshotProvider()) { entry in
            AccessoriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Accessoires")
        .description("Batterie des accessoires Bluetooth connectés.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AccessoriesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let accessories = entry.snapshot?.accessories {
                content(accessories, capturedAt: entry.snapshot!.capturedAt)
            } else {
                WidgetUnavailable(reason: entry.result)
            }
        }
        .widgetChrome()
    }

    @ViewBuilder
    private func content(_ accessories: WidgetSnapshot.Accessories, capturedAt: Date) -> some View {
        // L'ordre de l'instantané est déjà stable (nom, puis Gauche/Droite/
        // Boîtier) : regrouper ici sans re-trier.
        let names = accessories.readings.map(\.name).reduce(into: [String]()) {
            if !$0.contains($1) { $0.append($1) }
        }
        let shown = names.prefix(family == .systemMedium ? 3 : 1)

        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Accessoires", systemImage: "cable.connector")

            if accessories.readings.isEmpty {
                Text("Aucun accessoire Bluetooth avec batterie connecté")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shown, id: \.self) { name in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        ForEach(accessories.readings.filter { $0.name == name },
                                id: \.partLabel) { reading in
                            WidgetRow(raw: reading.partLabel, "\(reading.percent)%")
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            WidgetTimestamp(date: capturedAt)
        }
    }
}
