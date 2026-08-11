import SwiftUI
import WidgetKit

/// Point d'entrée de l'extension. Widgets **statiques** : les rendre
/// configurables (choix du capteur, par exemple) imposerait AppIntents, hors
/// périmètre de ce premier jet.
@main
struct MacInsideWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CPUWidget()
        MemoryWidget()
        BatteryWidget()
        SensorsWidget()
        StorageWidget()
        NetworkIdentityWidget()
        NetworkUsageWidget()
        FansWidget()
        PowerWidget()
        AccessoriesWidget()
    }
}
