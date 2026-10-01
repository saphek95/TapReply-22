import SwiftUI

// =============================================================================
// ACTES 3 ET 4 — TON TAPTAP, ET LA CONFIANCE
// =============================================================================
//
// S9  : la carte de membre. TapTap (Héros) sort une carte géante de sa poche et
//       la tient au-dessus de sa tête — la carte est DESSINÉE PAR L'APP (v3),
//       posée exactement entre ses mains ; on écrit le prénom dessus. Une seule
//       mise en scène, clavier ouvert ou fermé : quand le clavier monte, la
//       scène se resserre (TapTap plus petit, la carte reste visible).
// S10 : la couleur. Neuf pastilles EN ARC au-dessus de TapTap ; chaque tap le
//       recolore et déclenche la pose de cette couleur. « Elle est parfaite » →
//       miroir de poche, puis T5.
// S11 : le consentement. TapTap Compagnon, en haut à droite, sans accessoire :
//       le sérieux se lit par l'absence de gag. Il regarde chaque fait qui
//       apparaît. Accepter → hoche ; refuser → hausse d'épaules souriant.
// =============================================================================

// MARK: - S9 · La carte de membre

struct Onb3Name: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @FocusState private var focused: Bool
    @ObservedObject private var keyboard = HZKeyboard.shared
    @State private var cardOut = false
    @State private var shake = 0
    @State private var greeting = false

    private var accent: Color { draft.accent }
    private var trimmed: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// « Enchanté » : on passe tout de suite — c'est sur l'écran suivant qu'il réagit (il marche vers l'arc).
    private func greet() {
        guard !greeting else { return }
        greeting = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onNext()
    }

    var body: some View {
        GeometryReader { geo in
            // La carte fait 443 unités pour un TapTap de 300 : sa largeur fixe l'échelle de toute la scène.
            let compact = keyboard.isVisible
            let cardWidth = min(geo.size.width - 2 * HZ.Spacing.gutter - 24, compact ? 250 : 320)
            let cardHeight = cardWidth * (268.0 / 443.0)
            // hauteur de la scène : carte (167→435) + TapTap dessous (jambes à 748) ≈ 1,31 × largeur de carte
            let sceneHeight = cardWidth * ((748.5 - 167) / 443.0) + 8
            VStack(alignment: .leading, spacing: 0) {
                OnbTypewriter(text: String(localized: "On se tutoie ?\nComment tu t'appelles ?"), font: HZ.Fonts.fig(compact ? 22 : 27, .heavy))
                    .padding(.top, compact ? 2 : 10)
                if !compact {
                    Text(String(localized: "Juste pour que je sache comment t'appeler. Rien ne sort de ton téléphone."))
                        .font(HZ.Fonts.fig(15, .medium)).foregroundStyle(HZ.Colors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                Spacer(minLength: 6)

                // Il tend la carte au-dessus de sa tête ; la carte SwiftUI est posée entre ses mains (rectangle
                // mesuré de la carte du clip, retirée du dessin).
                HStack {
                    Spacer(minLength: 0)
                    // La carte est DEVANT ses mains (il la tient par l'arrière, comme dans le dessin) : ses bras
                    // disparaissent sous le bord de la carte, proprement — la carte est un occulteur.
                    TapTapRectSlot(canvasRect: TapTapClips.memberCardFace,
                                   beats: cardOut ? [.still(TapTapClips.tendLaCarte)] : [.play(TapTapClips.tendLaCarte, speed: 1.2)],
                                   accent: accent, transit: .cut, behindContent: cardOut, occluderRadius: cardWidth * 0.055) {
                        MemberCard(name: $draft.name, accent: accent, width: cardWidth, focused: $focused)
                            .opacity(cardOut ? 1 : 0)
                            .scaleEffect(cardOut ? 1 : 0.6, anchor: .bottom)
                            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: cardOut)
                            .cardTilt(shake)
                    }
                    Spacer(minLength: 0)
                }
                // clavier ouvert : TapTap est sous le clavier, on ne garde pas sa place (sinon « Enchanté » passe dessous sur iPhone SE)
                .padding(.bottom, compact ? 12 : sceneHeight - cardHeight)

                Spacer(minLength: 10)

                if compact {
                    HStack {
                        Spacer(minLength: 0)
                        Button { focused = false; greet() } label: {
                            HStack(spacing: 7) {
                                Text(trimmed.isEmpty ? String(localized: "Passer") : String(localized: "Enchanté"))
                                    .font(HZ.Fonts.fig(16, .bold))
                                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(.white).padding(.horizontal, 20).frame(height: 50)
                            .background(Capsule().fill(accent))
                            .shadow(color: accent.opacity(0.32), radius: 12, y: 5)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)
                    }
                } else {
                    OnbButton(title: trimmed.isEmpty ? String(localized: "Je préfère rester anonyme") : String(localized: "Enchanté, \(trimmed)"),
                              icon: "arrow.right", fill: accent, enabled: !greeting) { focused = false; greet() }
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 24)
            .animation(.spring(duration: 0.4), value: compact)
            .onChange(of: trimmed) { old, new in
                // Chaque lettre : la carte frémit (pas TapTap — il ne bouge pas quand on écrit), petite haptique.
                if new.count > old.count { shake += 1; UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }
            }
            .task {
                // V22b ×1,2 : la carte est en place (bras tendus) vers 2,2 s.
                try? await Task.sleep(for: .milliseconds(2_300))
                cardOut = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }
}

/// À chaque lettre : la carte s'incline légèrement (2°) et revient — pas un gauche-droite (qui se lit « erreur »).
private struct CardTilt: ViewModifier {
    var trigger: Int
    @State private var angle: Double = 0
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle), anchor: .bottom)
            .onChange(of: trigger) { _, _ in
                withAnimation(.easeOut(duration: 0.09)) { angle = 2 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { angle = 0 }
                }
            }
    }
}
private extension View { func cardTilt(_ trigger: Int) -> some View { modifier(CardTilt(trigger: trigger)) } }

// MARK: - S10 · Choisis mon look

struct Onb3Color: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var reaction: Int? = nil     // index de la couleur dont on joue la pose
    @State private var validating = false

    private let remarks: [String] = [
        String(localized: "Le violet, c'est ma couleur de naissance. Je suis peut-être partial."),
        String(localized: "Bleu. Sérieux, carré, on te fera confiance."),
        String(localized: "Ciel ! Là je me sens en vacances."),
        String(localized: "Vert. Franchement, ça me va super bien."),
        String(localized: "Jaune ?! Bon. Au moins on me verra de loin."),
        String(localized: "Orange, j'aime bien. Ça réveille."),
        String(localized: "Corail. Là je fais chaleureux, non ?"),
        String(localized: "Rose. Assumé. Je respecte."),
        String(localized: "Encre. Très chic. Un peu sévère pour moi, mais très chic.")
    ]

    private var accent: Color { draft.accent }

    var body: some View {
        GeometryReader { geo in
            let hero = TapTapScale.hero(geo.size) * 0.9
            let radius = min(geo.size.width / 2 - HZ.Spacing.gutter - 12, hero * 0.78)
            VStack(alignment: .leading, spacing: 0) {
                OnbTypewriter(text: String(localized: "Choisis mon look.\nJe te suis partout."), font: HZ.Fonts.fig(27, .heavy))
                    .padding(.top, 10)

                Spacer(minLength: 8)

                // L'arc des neuf couleurs, au-dessus de TapTap ; il joue la pose de la couleur touchée.
                ZStack(alignment: .bottom) {
                    ColorArc(selected: draft.colorIndex, radius: radius, onPick: pick)
                        .frame(maxWidth: .infinity)
                        .offset(y: -hero * 0.62)
                    HStack {
                        Spacer(minLength: 0)
                        TapTapSlot(height: hero, beats: beats, accent: accent, transit: .walk)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, radius * 0.45)

                TapTapBubble(text: remarks[min(draft.colorIndex, remarks.count - 1)], accent: accent, tail: .none, typing: false)
                    .id(draft.colorIndex)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                Spacer(minLength: 12)

                OnbButton(title: String(localized: "Elle est parfaite"), icon: "arrow.right", fill: accent, enabled: !validating) { validate() }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 24)
            .animation(.spring(duration: 0.4), value: draft.colorIndex)
        }
    }

    private var beats: [TapTapBeat] {
        if validating { return [.play(TapTapClips.miroir, speed: 1.25), .loop(TapTapClips.idle)] }
        if let r = reaction, TapTapClips.reactionCouleur.indices.contains(r) {
            return [.play(TapTapClips.reactionCouleur[r], speed: 1.2), .loop(TapTapClips.idle)]
        }
        return [.loop(TapTapClips.idle)]
    }

    private func pick(_ i: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(duration: 0.35)) { draft.colorIndex = i }
        reaction = i
    }

    /// Gag de validation : le miroir de poche (l'objet enfin petit), puis on part.
    private func validate() {
        validating = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3_600))
            onNext()
        }
    }
}

// MARK: - S11 · Le consentement (acte 4)

struct Onb3Privacy: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false
    @State private var revealed = 0
    @State private var gaze = 0
    @State private var leaving: Bool? = nil   // true = accepte · false = refuse

    private var accent: Color { draft.accent }

    private var facts: [ConsentFacts.Fact] { ConsentFacts.all }

    var body: some View {
        GeometryReader { geo in
            let companion = TapTapScale.companion(geo.size)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    OnbTypewriter(text: String(localized: "Avant d'aller plus loin,\nton accord."), font: HZ.Fonts.fig(27, .heavy))
                    Spacer(minLength: 0)
                    // Compagnon, en haut à droite, arrivé par un pouf : il laisse la place à l'écran.
                    TapTapSlot(height: companion, beats: beats, accent: accent, transit: .pouf)
                        .padding(.top, -6)
                }
                .padding(.top, 10)

                Text(String(localized: "Pour écrire tes réponses, j'ai besoin de lire la conversation affichée. Voilà exactement ce que ça implique."))
                    .font(HZ.Fonts.fig(15, .medium)).foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { i, f in
                        if i < revealed {
                            HStack(alignment: .top, spacing: 13) {
                                ZStack {
                                    Circle().fill(accent.opacity(0.12)).frame(width: 38, height: 38)
                                    Image(systemName: f.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(accent)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(f.title).font(HZ.Fonts.fig(15.5, .bold)).foregroundStyle(HZ.Colors.ink).fixedSize(horizontal: false, vertical: true)
                                    Text(f.detail).font(HZ.Fonts.fig(13.5, .medium)).foregroundStyle(HZ.Colors.sub).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    if revealed >= facts.count {
                        ConsentFacts.policyLink(accent: accent)
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 22)
                }
                .scrollBounceBehavior(.basedOnSize)

                Spacer(minLength: 10)

                Text(leaving == false
                     ? String(localized: "Pas de souci. Sans ton accord, je ne peux pas écrire de réponses : tu pourras l'activer plus tard dans Réglages, Partage avec l'IA.")
                     : String(localized: "Je préfère te le dire maintenant que tu le découvres après."))
                    .font(HZ.Fonts.fig(14.5, .semibold)).foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                OnbButton(title: String(localized: "J'accepte l'envoi du texte à l'IA"), icon: "checkmark", fill: accent, enabled: leaving == nil) {
                    consentAccepted = true
                    Analytics.track("consent", ["value": "accepted", "where": "onboarding"])
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    leaving = true
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); onNext() }
                }
                OnbLink(title: String(localized: "Je refuse pour l'instant")) {
                    guard leaving == nil else { return }
                    consentAccepted = false
                    Analytics.track("consent", ["value": "refused", "where": "onboarding"])
                    leaving = false
                    // le temps de lire l'explication (ce que le refus implique) avant de continuer
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(3_200)); onNext() }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 24)
            .animation(.spring(duration: 0.4), value: revealed)
            .task {
                for i in 1...facts.count {
                    try? await Task.sleep(for: .milliseconds(i == 1 ? 900 : 650))
                    revealed = i; gaze += 1
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
        }
    }

    private var beats: [TapTapBeat] {
        if leaving == false { return [.play(TapTapClips.hausseEpaules, speed: 1.1)] }
        if gaze > 0 && revealed < facts.count + 1 { return [.play(TapTapClips.regardBas, speed: 1.2, holdMs: 500), .loop(TapTapClips.idle)] }
        return [.loop(TapTapClips.idle)]
    }
}
