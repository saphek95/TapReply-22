import SwiftUI

// =============================================================================
// L'ÎLE SIMULÉE
// =============================================================================
//
// La vraie Live Activity ne s'affiche pas de façon fiable quand l'application
// est au premier plan : toute démonstration a donc besoin d'une copie dessinée.
//
// Extraite de l'ancien onboarding, supprimé en 2.1.0 : elle sert au TERRAIN
// D'ESSAI, qui reste bien vivant. La laisser dans un fichier d'onboarding mort
// aurait obligé à conserver 800 lignes pour 60 utiles.
// =============================================================================

// MARK: - L'île simulée (le moment magique de l'onboarding)
/// Pill noir qui apparaît sous la vraie Dynamic Island : barre « Analyse de ta
/// conversation… » qui se remplit, puis aperçu du message généré + coche verte.
struct FakeIslandView: View {
    enum IslandState { case generating, ready }

    let state: IslandState
    let reply: String

    @State private var progress: CGFloat = 0.06

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: state == .ready ? "checkmark.circle.fill" : "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14))
                    .foregroundColor(state == .ready ? DS.Colors.accent : .white)
                Text(state == .ready
                     ? String(localized: "Réponse prête ✓ copiée")
                     : String(localized: "Analyse de ta conversation…"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            if state == .generating {
                // Barre fine blanche qui se remplit (~8 s)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule().fill(Color.white)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 8)) { progress = 0.96 }
                }
            } else {
                Text(reply)
                    .font(.system(size: 13.5))
                    .foregroundColor(Color(hex: 0xE8E8E8))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                // ONBOARDING uniquement : rendre l'étape suivante évidente
                Text(String(localized: "📋 Copiée : tu n'as plus qu'à COLLER en bas ⬇️"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DS.Colors.ink)
        )
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .padding(.horizontal, DS.Spacing.l)
        .animation(.spring(duration: 0.4), value: state == .ready)
    }
}
