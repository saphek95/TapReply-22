import SwiftUI

/// LE SPLASH DE LANCEMENT — TapTap apparaît dans un pouf, salue, puis va prendre sa place.
///
/// Il remplace l'ancien splash de marque sur le chemin de lancement. Deux choses utiles :
///
/// 1. IL RECONNAÎT L'UTILISATEUR. TapTap porte LA couleur choisie pendant l'onboarding.
/// 2. IL RACCORDE À L'ACCUEIL. Il ne disparaît pas en fondu : il file vers le coin haut-gauche, là où son
///    avatar figure dans l'en-tête de l'accueil (le même moteur, la même silhouette : le raccord est exact).
///
/// Jamais la lampe ici : elle est réservée à la première rencontre. Durée totale ≈ 1,3 s.
struct TapTapSplash: View {
    var onFinished: () -> Void

    @ObservedObject private var theme = HZTheme.shared
    /// 0 pouf · 1 il salue au centre · 2 il file vers l'accueil
    @State private var phase = 0
    @State private var pouf = false

    var body: some View {
        GeometryReader { geo in
            let big: CGFloat = 200
            let small: CGFloat = 54
            // L'avatar de l'accueil : à `gutter` du bord gauche, ~74 pt du haut (même valeur que HomeView.header).
            let target = CGPoint(x: HZ.Spacing.gutter + small / 2, y: 74)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.44)
            ZStack {
                HZ.Colors.page.ignoresSafeArea()

                if pouf {
                    TapTapPouf(size: big * 0.9).position(center)
                }

                if phase >= 1 {
                    TapTapFigure(size: phase == 2 ? small : big,
                                 beats: [.play(TapTapClips.coucou, speed: 1.7), .loop(TapTapClips.idle)])
                        .position(phase == 2 ? target : center)
                        .opacity(phase == 2 ? 0 : 1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: phase)
                }
            }
        }
        .task {
            pouf = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            try? await Task.sleep(for: .milliseconds(180))
            phase = 1
            try? await Task.sleep(for: .milliseconds(780))
            phase = 2
            try? await Task.sleep(for: .milliseconds(420))
            onFinished()
        }
    }
}
