import SwiftUI
import WidgetKit

/// Éléments visuels communs aux quatre widgets : en-tête, jauge, sparkline,
/// horodatage, état vide. Volontairement plus sobres que les cartes du
/// dashboard — un widget est lu d'un coup d'œil, à petite taille.
struct WidgetHeader: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Grande valeur en tête de widget.
struct WidgetValue: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.title, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Sparkline minimaliste, sans axes ni légende : à cette taille, seule la forme
/// de la courbe porte de l'information.
struct WidgetSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let points = normalized()
            if points.count > 1 {
                ZStack {
                    line(points, in: geo.size)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    line(points, in: geo.size, closed: true)
                        .fill(color.opacity(0.15))
                }
            }
        }
    }

    /// Ramène les valeurs dans [0, 1]. Une série plate (min == max) est centrée
    /// plutôt que collée en bas, sinon une charge stable ressemble à une panne
    /// de mesure.
    private func normalized() -> [Double] {
        guard let min = values.min(), let max = values.max() else { return [] }
        guard max > min else { return values.map { _ in 0.5 } }
        return values.map { ($0 - min) / (max - min) }
    }

    private func line(_ points: [Double], in size: CGSize, closed: Bool = false) -> Path {
        Path { path in
            let step = size.width / CGFloat(points.count - 1)
            for (index, value) in points.enumerated() {
                let point = CGPoint(x: CGFloat(index) * step,
                                    y: size.height * (1 - CGFloat(value)))
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            if closed {
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
        }
    }
}

/// Ligne libellé/valeur compacte, commune aux widgets à contenu tabulaire.
struct WidgetRow: View {
    private let label: Text
    private let value: String

    init(_ label: LocalizedStringKey, _ value: String) {
        self.label = Text(label)
        self.value = value
    }

    /// Libellé arrivé déjà localisé dans l'instantané (capteur, accessoire…).
    init(raw label: String, _ value: String) {
        self.label = Text(label)
        self.value = value
    }

    var body: some View {
        HStack(spacing: 4) {
            label
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(value)
                .font(.caption2.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// Âge de la donnée. Affiché sur tous les widgets à dessein : les données
/// WidgetKit ont plusieurs minutes de retard par construction (l'extension est
/// sandboxée et ne peut pas lire les capteurs elle-même), autant que ce soit
/// lisible plutôt que de laisser croire à du temps réel.
struct WidgetTimestamp: View {
    let date: Date

    var body: some View {
        Text(date, style: .relative)
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}

/// Affiché faute de données, avec la raison — les deux causes n'appellent pas
/// du tout le même geste, les confondre laisse l'utilisateur sans piste.
struct WidgetUnavailable: View {
    let reason: WidgetSnapshotStore.ReadResult

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
    }

    private var symbol: String {
        if case .containerUnavailable = reason { return "exclamationmark.triangle" }
        return "questionmark.circle"
    }

    private var message: LocalizedStringKey {
        if case .containerUnavailable = reason {
            // Cas d'une app mal signée : réinstaller depuis le DMG officiel est
            // le seul geste utile, relancer l'app n'y changerait rien.
            return "Réinstallez MacInside"
        }
        return "Lancez MacInside"
    }
}

extension View {
    /// Fond de widget requis depuis macOS 14 : sans lui, le système journalise
    /// un avertissement et le rendu est incohérent selon l'emplacement.
    func widgetChrome() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}
