import SwiftUI
import UniformTypeIdentifiers

/// Grille "masonry" maison plutôt qu'un `LazyVGrid` : dans un `LazyVGrid`,
/// toutes les cartes d'une même ligne partagent la hauteur de la plus haute
/// d'entre elles, ce qui crée un grand vide sous les cartes plus courtes
/// (ex. CPU au-dessus de Ventilateurs). Ici chaque colonne empile ses cartes
/// indépendamment des autres colonnes, sans hauteur de ligne imposée.
///
/// L'ordre des cartes est piloté par `AppSettings.dashboardCardOrder` et
/// modifiable par glisser-déposer (chaque carte porte son `DashboardCardKind`
/// comme identité de drag).
struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    private let minColumnWidth: CGFloat = 260
    private let spacing: CGFloat = 16
    private let horizontalPadding: CGFloat = 20

    @State private var draggedKind: DashboardCardKind?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: spacing) {
                    HeaderView()
                    masonry(width: geo.size.width - horizontalPadding * 2)
                }
                .padding(horizontalPadding)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
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
                    openWindow(id: "processes")
                } label: {
                    Label("Processus", systemImage: "list.bullet.rectangle")
                }
                .help(Text("Processus"))
            }
        }
    }

    private var orderedKinds: [DashboardCardKind] {
        settings.dashboardCardOrder
            .filter { $0 != .battery || model.battery.isPresent }
            .filter { !settings.hiddenDashboardCards.contains($0) }
    }

    @ViewBuilder
    private func cardView(for kind: DashboardCardKind) -> some View {
        switch kind {
        case .cpu: CPUCardView()
        case .memory: MemoryCardView()
        case .storage: StorageCardView()
        case .networkIdentity: NetworkIdentityCardView()
        case .networkUsage: NetworkUsageCardView()
        case .fans: FansCardView()
        case .temperature: TemperatureCardView()
        case .power: PowerCardView()
        case .battery: BatteryCardView()
        case .accessoryBatteries: AccessoryBatteryCardView()
        }
    }

    private func masonry(width: CGFloat) -> some View {
        let kinds = orderedKinds
        let columnCount = max(1, Int((width + spacing) / (minColumnWidth + spacing)))
        var columns: [[DashboardCardKind]] = Array(repeating: [], count: columnCount)
        for (index, kind) in kinds.enumerated() {
            columns[index % columnCount].append(kind)
        }

        return HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columnCount, id: \.self) { column in
                VStack(spacing: spacing) {
                    ForEach(columns[column]) { kind in
                        draggableCard(kind)
                    }
                }
            }
        }
    }

    /// Revenu à un `.onDrag` sur toute la carte (comme avant) après retour de
    /// Vincent : la version restreinte à la seule poignée (icône barres
    /// horizontales) empêchait tout déplacement plutôt que de le fiabiliser —
    /// jamais vérifiée par un vrai geste de glisser (l'automatisation de ce
    /// geste n'est pas fiable dans cet environnement), seulement par capture
    /// d'écran statique, donc la régression n'avait pas été détectée avant
    /// que Vincent ne la constate. La poignée reste affichée à titre indicatif
    /// (aspect inchangé), mais ne conditionne plus le glisser.
    private func draggableCard(_ kind: DashboardCardKind) -> some View {
        cardView(for: kind)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(10)
            }
            .opacity(draggedKind == kind ? 0.4 : 1)
            .onDrag {
                draggedKind = kind
                return NSItemProvider(object: kind.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: CardDropDelegate(
                target: kind,
                draggedKind: $draggedKind,
                move: moveCard
            ))
    }

    /// Déplace `kind` relativement à `target` dans l'ordre persisté — les
    /// cartes masquées (ex. Batterie absente) restent à leur position dans
    /// l'ordre stocké, seul l'ordre relatif des cartes visibles change.
    ///
    /// Insère avant ou après `target` selon le sens du déplacement (comparaison
    /// des index d'origine) plutôt que toujours avant : en insérant
    /// systématiquement avant la carte survolée, il était impossible de placer
    /// une carte sous une autre (en particulier en dernière position d'une
    /// colonne, puisque survoler la dernière carte ne faisait que la remettre
    /// avant elle) — signalé par Vincent.
    ///
    /// Animé : sans ça, la grille se réarrangeait d'un coup sec (chaque carte
    /// peut changer de colonne, pas seulement de position), ce qui rendait le
    /// résultat du glisser difficile à suivre.
    private func moveCard(_ kind: DashboardCardKind, relativeTo target: DashboardCardKind) {
        guard kind != target else { return }
        var order = settings.dashboardCardOrder
        guard let fromIndex = order.firstIndex(of: kind), let targetIndex = order.firstIndex(of: target) else { return }
        let movingDown = fromIndex < targetIndex

        order.remove(at: fromIndex)
        guard let newTargetIndex = order.firstIndex(of: target) else { return }
        let insertIndex = movingDown ? newTargetIndex + 1 : newTargetIndex
        order.insert(kind, at: min(insertIndex, order.count))

        withAnimation(.easeInOut(duration: 0.2)) {
            settings.dashboardCardOrder = order
        }
    }
}

private struct CardDropDelegate: DropDelegate {
    let target: DashboardCardKind
    @Binding var draggedKind: DashboardCardKind?
    let move: (DashboardCardKind, DashboardCardKind) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedKind, draggedKind != target else { return }
        move(draggedKind, target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedKind = nil
        return true
    }
}
