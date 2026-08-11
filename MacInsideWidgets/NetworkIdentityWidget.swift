import SwiftUI
import WidgetKit

struct NetworkIdentityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.vincentlauriat.macinside.widget.networkidentity",
                            provider: SnapshotProvider()) { entry in
            NetworkIdentityWidgetView(entry: entry)
        }
        .configurationDisplayName("Identité réseau")
        .description("Interface, adresses IP et passerelle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NetworkIdentityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let identity = entry.snapshot?.networkIdentity {
                content(identity, capturedAt: entry.snapshot!.capturedAt)
            } else {
                WidgetUnavailable(reason: entry.result)
            }
        }
        .widgetChrome()
    }

    private func content(_ identity: WidgetSnapshot.NetworkIdentity, capturedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            WidgetHeader(title: "Identité réseau", systemImage: "network")

            WidgetRow("Interface", [identity.interfaceType, identity.interfaceName]
                .filter { !$0.isEmpty }.joined(separator: " · "))
            WidgetRow("Adresse locale", dash(identity.localAddress))
            WidgetRow("Adresse publique", dash(identity.publicAddress))
            WidgetRow("Pays", dash(identity.countryCode))

            if family == .systemMedium {
                WidgetRow("Hostname", dash(identity.hostname))
                WidgetRow("Passerelle", dash(identity.gatewayAddress))
            }

            Spacer(minLength: 0)
            WidgetTimestamp(date: capturedAt)
        }
    }

    private func dash(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }
}
