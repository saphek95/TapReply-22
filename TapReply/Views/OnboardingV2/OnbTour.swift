import SwiftUI

// =============================================================================
// LA VISITE GUIDÉE — juste après l'onboarding
// =============================================================================
//
// L'onboarding apprend LE GESTE. Il ne dit rien de l'application elle-même, et
// c'est volontaire : on ne fait pas visiter la maison avant d'avoir donné la
// clé. La visite arrive donc après, une fois que tout fonctionne.
//
// Trois partis pris :
//
// 1. TROIS ARRÊTS, PAS QUATRE. L'accueil, le studio, le terrain d'essai. Les
//    réglages n'ont pas besoin d'être présentés : personne n'a jamais cherché
//    où se trouvaient les réglages d'une application.
//
// 2. ON DÉSIGNE, ON N'EXPLIQUE PAS. Le voile s'assombrit partout SAUF sur
//    l'onglet dont on parle, et l'onglet correspondant s'ouvre en même temps.
//    On voit donc la page dont TapTap parle pendant qu'il en parle.
//
// 3. ON RESTE COURT. Une phrase par arrêt. Une visite qui dure plus longtemps
//    que l'onboarding lui-même est une visite qu'on saute.
// =============================================================================

struct OnbTour: View {
    /// L'onglet actuellement affiché, piloté pendant la visite.
    @Binding var selectedTab: Int
    /// Les rectangles RÉELS des onglets, mesurés par la barre elle-même.
    ///
    /// Ils ne peuvent pas être calculés : la barre n'a pas quatre cases égales
    /// mais une capsule de trois onglets à gauche, dont le sélectionné
    /// s'élargit pour afficher son libellé, et un bouton isolé à droite. Toute
    /// estimation par fractions tombait à côté de la cible.
    var tabRects: [Int: CGRect] = [:]
    let onFinish: () -> Void

    @ObservedObject private var theme = HZTheme.shared
    @State private var stop = 0
    @State private var appeared = false

    private var accent: Color { Color(hex: UInt(theme.accentHex)) }

    /// Les arrêts. `tab` est l'index dans la barre, donc la position du trou.
    private var stops: [(tab: Int, title: String, line: String)] {
        [(0,
          String(localized: "Ton accueil"),
          String(localized: "Le temps que tu as gagné, et toutes tes réponses passées. Tu les retrouves ici.")),
         // Le studio est la fonctionnalité la moins évidente de l'application,
         // et la plus différenciante. On ne dit donc pas « tu choisis un ton » —
         // ce qui ne dit rien à quelqu'un qui n'en a jamais choisi — on NOMME
         // les tons et on donne l'exemple concret d'un même message répondu
         // différemment.
         (1,
          String(localized: "Le studio"),
          String(localized: "C'est ici que tu décides COMMENT je réponds : professionnel pour un collègue, charmeur pour une première rencontre, rigolo entre amis. Tu peux même écrire ton propre ton, avec tes expressions à toi, et l'associer à un geste.")),
         (3,
          String(localized: "Le terrain d'essai"),
          String(localized: "Une fausse conversation, pour t'entraîner. Tu tapes deux fois au dos, tu vois ma réponse arriver, et personne ne reçoit rien. C'est aussi là que tu vérifies que le geste marche bien sur ton téléphone."))]
    }

    private var current: (tab: Int, title: String, line: String) {
        stops[min(stop, stops.count - 1)]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Le voile, troué à l'aplomb de l'onglet dont on parle.
            //
            // `compositingGroup` AVANT `blendMode(.destinationOut)` : sans lui,
            // le mode de fusion s'applique à toute la pile et efface aussi ce
            // qui est derrière le voile.
            Rectangle()
                .fill(.black.opacity(0.74))
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: hole.height / 2, style: .continuous)
                        .frame(width: hole.width, height: hole.height)
                        .offset(x: hole.minX, y: hole.minY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

            // L'anneau. Sans lui, le trou se lit comme une zone oubliée par le
            // voile, pas comme une cible. Il partage EXACTEMENT la géométrie du
            // trou : les deux sont posés dans le même repère, par offset et non
            // par position, pour qu'aucune marge de sécurité ne les sépare.
            RoundedRectangle(cornerRadius: hole.height / 2, style: .continuous)
                .strokeBorder(.white.opacity(0.92), lineWidth: 2.5)
                .frame(width: hole.width, height: hole.height)
                .offset(x: hole.minX, y: hole.minY)

            // TapTap et sa bulle, ancrés juste au-dessus du trou.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(current.title)
                        .font(HZ.Fonts.fig(19, .heavy))
                        .foregroundStyle(HZ.Colors.ink)
                    Text(current.line)
                        .font(HZ.Fonts.fig(15, .medium))
                        .foregroundStyle(HZ.Colors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    OnbBubbleShape(tail: .bottomAt(56))
                        .fill(.white)
                        .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
                )
                .padding(.bottom, 15)
                .id(stop)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                HStack(alignment: .bottom, spacing: 14) {
                    TapTapFigure(size: 96,
                                 beats: stop == stops.count - 1
                                    ? [.play(TapTapClips.miniDanse, speed: 1.2), .loop(TapTapClips.reposHeureux)]
                                    : [.play(TapTapClips.presente, speed: 1.1, holdMs: 700), .loop(TapTapClips.idle)])
                        .id(stop)

                    Spacer(minLength: 0)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        next()
                    } label: {
                        HStack(spacing: 8) {
                            Text(stop == stops.count - 1
                                 ? String(localized: "À moi de jouer")
                                 : String(localized: "Suivant"))
                                .font(HZ.Fonts.fig(16.5, .bold))
                            Image(systemName: stop == stops.count - 1
                                  ? "checkmark" : "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 52)
                        .background(Capsule().fill(accent))
                        .shadow(color: accent.opacity(0.4), radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            // La bulle s'arrête juste au-dessus du trou, jamais dessus.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, bubbleBottomInset)
            .opacity(appeared ? 1 : 0)
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.82), value: stop)
        .transition(.opacity)
        .task {
            selectedTab = stops[0].tab
            try? await Task.sleep(for: .milliseconds(340))
            withAnimation(.spring(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: Géométrie du trou, mesurée et non calculée

    /// Le rectangle à mettre en lumière, avec une marge autour de la cible.
    ///
    /// Le repli n'est utilisé qu'au premier rendu, avant que les ancres soient
    /// résolues : une valeur hors écran plutôt qu'un trou au mauvais endroit.
    private var hole: CGRect {
        guard let r = tabRects[current.tab] else {
            return CGRect(x: -400, y: -400, width: 10, height: 10)
        }
        return r.insetBy(dx: -7, dy: -7)
    }

    /// De combien la bulle doit rester au-dessus du bas de l'écran.
    private var bubbleBottomInset: CGFloat {
        guard let r = tabRects[current.tab] else { return 120 }
        // La bulle se cale au-dessus de la cible, avec l'espace de la pointe.
        return max(UIScreen.main.bounds.height - r.minY + 18, 100)
    }

    private func next() {
        guard stop < stops.count - 1 else {
            withAnimation(.easeOut(duration: 0.3)) { appeared = false }
            Task {
                try? await Task.sleep(for: .milliseconds(260))
                // On RESTE sur le dernier onglet présenté (le terrain d'essai) : revenir à l'accueil puis repartir
                // vers l'essai faisait un aller-retour inutile (retour du 25/09).
                onFinish()
            }
            return
        }
        withAnimation(.spring(duration: 0.45)) {
            stop += 1
            selectedTab = stops[stop].tab
        }
    }
}
