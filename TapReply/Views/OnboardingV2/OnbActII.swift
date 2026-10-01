import SwiftUI

// =============================================================================
// ACTE II — LA MAGIE, ESSAYÉE
// =============================================================================
//
// Objectif : faire VIVRE le résultat avant de demander le moindre effort. Fond
// saturé à la couleur choisie — c'est le pic émotionnel du parcours.
//
// LA DÉCISION QUI RÈGLE LA CONFUSION DOS / ÉCRAN
//
// Faire taper l'écran alors qu'on vient d'expliquer qu'il faut taper le dos,
// c'est se contredire. La rustine verbale (« c'est juste pour te montrer ») ne
// suffit pas.
//
// La solution est visuelle : on affiche un iPhone vu de DOS, et on demande de
// taper deux fois SUR CE DOS-LÀ. Le geste devient cohérent avec sa cible —
// l'utilisateur tape deux fois sur un dos de téléphone. C'est une répétition
// mentale exacte, pas une approximation. Puis le téléphone SE RETOURNE pour
// révéler la réponse, ce qui relie le geste à son effet par un seul objet.
// =============================================================================

// MARK: - 5 · À toi d'essayer

struct OnbTryIt: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    private enum Phase { case waiting, working, done }
    @State private var phase: Phase = .waiting
    @State private var flip: Double = 0        // 0 = dos · 180 = face
    @State private var speaks = false

    private let reply = String(localized: "Oui carrément, 18h comme prévu. Hâte !")

    var body: some View {
        VStack(spacing: 0) {
            // Consigne — la seule action possible sur cet écran.
            VStack(spacing: 7) {
                Text(phase == .done
                     ? String(localized: "Voilà. C'est tout ce que je fais.")
                     : String(localized: "À toi d'essayer."))
                    .font(HZ.Fonts.fig(27, .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // « Tape deux fois sur le dos du téléphone » était ambigu : on ne
                // savait pas s'il s'agissait du sien ou de celui dessiné. On
                // désigne l'image, et on écarte explicitement l'autre lecture.
                Text(phase == .done
                     ? String(localized: "Et je le ferai dans toutes tes applications de messages.")
                     : String(localized: "Tape deux fois sur le téléphone dessiné ci-dessous. Pas sur le tien : ça viendra plus tard."))
                    .font(HZ.Fonts.fig(15.5, .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.horizontal, 6)
            .animation(.spring(duration: 0.5), value: phase)

            Spacer(minLength: 10)

            // LE TÉLÉPHONE. Il se retourne sur son axe vertical : le dos qu'on
            // a tapé devient la face qui répond. Un seul objet, donc un seul
            // récit — le geste et son effet ne sont pas deux images séparées.
            ZStack {
                // Face avant : visible quand la carte est retournée.
                phoneFront
                    .opacity(flip > 90 ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                // Dos : visible au départ.
                DoubleTapZone(enabled: phase == .waiting) { trigger() } content: {
                    // La même largeur que la face : les deux vivent dans le même ZStack
                    // pendant le retournement, donc c'est le PLUS GRAND des deux
                    // qui fixe la hauteur. Réduire seulement la face ne libérait
                    // rien.
                    PhoneBack(width: phase == .done ? 168 : 208,
                              accent: .white,
                              pulsing: phase == .waiting)
                        .overlay {
                            if phase == .waiting {
                                // Le rappel du geste passe SOUS la pomme : c'est
                                // elle la cible, la recouvrir d'une icône de main
                                // reviendrait à cacher ce qu'on demande de viser.
                                VStack(spacing: 5) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                    Text(String(localized: "deux fois"))
                                        .font(HZ.Fonts.fig(12.5, .bold))
                                }
                                .foregroundStyle(.white.opacity(0.88))
                                .offset(y: 208 * 0.30)
                            }
                        }
                }
                .opacity(flip > 90 ? 0 : 1)
            }
            .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.42)
            .animation(.spring(duration: 0.85, bounce: 0.22), value: flip)

            Spacer(minLength: 10)

            // TapTap s'efface pendant que l'utilisateur essaie : c'est SON
            // moment, pas celui de la mascotte. Il revient à l'instant où il a
            // quelque chose à dire sur le résultat.
            //
            // Le composant reste dans l'arbre même invisible : il doit publier
            // une scène masquée, sinon le routeur laisserait TapTap à la
            // position de l'écran précédent.
            TapTapAside(text: String(localized: "Zéro réglage. Et c'était déjà ça."),
                        visible: speaks,
                        act: .celebrate,
                        mouth: .smile,
                        prop: .sparkles,
                        white: true,
                        accent: draft.accent,
                        mascotSize: MascotPlace.commentSize)
                .padding(.bottom, 16)

            if phase == .done {
                OnbButton(title: String(localized: "Il y a mieux encore"),
                          icon: "arrow.right",
                          fill: .white.opacity(0.22),
                          action: onNext)
                    .transition(.opacity)
            }
            // Rien d'autre tant que le geste n'est pas fait : l'écran n'a qu'une
            // seule issue, et c'est le geste. L'onde qui pulsait ici, sous le
            // téléphone, désignait une cible inexistante et concurrençait celle
            // du dos de l'appareil. Sa suppression libère aussi la hauteur qui
            // manquait au contenu final.
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 26)
    }

    private var phoneFront: some View {
        // Le téléphone se réduit dès que la réponse est là. Sans cela, la bulle
        // de TapTap et le bouton s'ajoutaient sous un contenu déjà à pleine
        // hauteur : le VStack débordait, la barre du haut sortait de l'écran, et
        // tout paraissait zoomé, flèche de retour comprise.
        PhoneFrame(width: phase == .done ? 168 : 208) {
            VStack(spacing: 0) {
                if phase != .waiting {
                    OnbIsland(phase: phase == .working ? .working : .ready,
                              reply: phase == .done ? reply : "",
                              accent: draft.accent,
                              mascotColor: draft.accent)
                        .scaleEffect(0.80)
                        .padding(.top, 5)
                }

                VStack(spacing: 8) {
                    MiniBubble(text: String(localized: "Salut ! On se voit toujours demain ?"),
                               accent: draft.accent)
                    MiniBubble(text: String(localized: "Oui, 18h ça marche"),
                               mine: true, accent: draft.accent)
                    MiniBubble(text: String(localized: "Parfait. Tu confirmes ?"),
                               accent: draft.accent)
                }
                .padding(.horizontal, 13)
                .padding(.top, 12)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text(phase == .done ? reply : String(localized: "Message"))
                        .font(HZ.Fonts.fig(11.5, phase == .done ? .medium : .regular))
                        .foregroundStyle(phase == .done ? HZ.Colors.ink : HZ.Colors.faint)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if phase == .done {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(draft.accent)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(phase == .done ? draft.accent.opacity(0.10) : HZ.Colors.card))
                .overlay(Capsule().strokeBorder(phase == .done ? draft.accent.opacity(0.5) : .clear, lineWidth: 1.4))
                .padding(.horizontal, 11)
                .padding(.bottom, 13)
            }
        }
    }

    /// Le rythme de la démonstration.
    ///
    /// Il est volontairement lent. Le retournement prend son temps, l'attente de
    /// génération dure assez longtemps pour être VUE comme un travail, et la
    /// réponse s'installe avant que TapTap commente. Trop rapide, l'utilisateur
    /// voyait un résultat sans voir le processus, donc sans comprendre ce que
    /// l'application venait de faire pour lui.
    private func trigger() {
        phase = .working
        flip = 180
        Task {
            // Le temps que le téléphone finisse de se retourner.
            try? await Task.sleep(for: .milliseconds(900))
            // Puis l'attente de génération, bien lisible.
            try? await Task.sleep(for: .milliseconds(1_900))
            withAnimation(.spring(duration: 0.55)) { phase = .done }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(duration: 0.45)) { speaks = true }
        }
    }
}

// MARK: - 6 · Le brouillon, la fonctionnalité que personne ne découvrait

/// ÉCRAN 6 — QUAND C'EST TOI QUI SAIS QUOI DIRE
///
/// L'écran répond à l'objection la plus fréquente, et la plus légitime : « et
/// si l'IA répond autre chose que ce que je voulais dire ? »
///
/// La version précédente posait un champ de saisie nu, avec trois suggestions
/// hors sol — « pizza », « non désolé », « ça marche » — sans montrer la moindre
/// conversation. On ne pouvait pas comprendre : un mot répondant à quelle
/// question ? Ici la conversation est VISIBLE, la question est posée, et la
/// réponse fabriquée vient s'afficher dedans comme un vrai message envoyé.
///
/// Le geste est appris une troisième fois, et sur la bonne cible : on double-tape
/// une vignette de dos d'iPhone avec sa pomme, pas un bouton rectangulaire. Le
/// geste de l'onboarding et le geste réel deviennent le même objet.
struct OnbDraftFeature: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    private enum Phase { case reading, typing, working, done }
    @State private var phase: Phase = .reading
    /// Le clavier occupe la moitié basse de l'écran. Tout ce qui compte doit
    /// tenir dans l'autre moitié, et surtout la pomme, qui EST l'action.
    @ObservedObject private var keyboard = HZKeyboard.shared

    /// La largeur du téléphone. Réduite clavier ouvert, mais jamais nulle.
    private var phoneWidth: CGFloat { keyboard.isVisible ? 62 : 76 }
    @State private var word = ""
    @State private var speaks = false
    @FocusState private var focused: Bool

    /// La question posée dans la conversation. Tout l'écran en découle : les
    /// suggestions y répondent, et la phrase produite aussi.
    private let question = String(localized: "On se fait un resto ce soir ?")

    /// Des amorces qui répondent VRAIMENT à la question affichée — et qui
    /// couvrent les trois intentions possibles : oui, non, et une contre-idée.
    private let seeds: [(word: String, reply: String)] = [
        (String(localized: "oui"),
         String(localized: "Oui avec plaisir ! Tu as un endroit en tête ?")),
        (String(localized: "trop cher"),
         String(localized: "Le resto c'est un peu cher pour moi ce soir. On ferait pas plutôt à la maison ?")),
        (String(localized: "demain"),
         String(localized: "Ce soir je peux pas, mais demain je suis totalement partant !")),
    ]

    /// La phrase produite. On reconnaît d'abord les amorces proposées, puis on
    /// retombe sur une formulation générique : la démonstration doit rester
    /// crédible quel que soit le mot tapé.
    private var produced: String {
        let w = word.lowercased().trimmingCharacters(in: .whitespaces)
        for seed in seeds where w.contains(seed.word) { return seed.reply }
        if w.contains("non") || w.contains("pas") {
            return String(localized: "Ce soir ça va pas être possible, désolé. On remet ça ?")
        }
        if w.isEmpty { return String(localized: "Oui, ça me va !") }
        return String(localized: "Alors : \(w). Ça te va comme ça ?")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── L'explication, en haut et en grand ──────────────────────
            // Clavier ouvert, le titre cède la place : c'est la pomme qui doit
            // rester visible, pas l'explication qu'on vient de lire.
            VStack(alignment: .leading, spacing: 8) {
                if !keyboard.isVisible {
                    Text(String(localized: "ET SI TU SAIS DÉJÀ QUOI RÉPONDRE ?"))
                        .font(HZ.Fonts.fig(12.5, .bold))
                        .tracking(1.3)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Text(headline)
                    .font(HZ.Fonts.fig(keyboard.isVisible ? 17 : 22, .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(keyboard.isVisible ? 2 : nil)
                    .id(phase == .done)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)

            Spacer(minLength: 10)

            // ── LA CONVERSATION ────────────────────────────────────────
            //
            // Elle est présentée comme un vrai fil de discussion : un en-tête
            // avec le prénom de l'interlocutrice, son message à GAUCHE, et la
            // place de la réponse à DROITE. Sans cet encadrement, on ne
            // comprenait pas que le haut était reçu et le bas à écrire — deux
            // bulles empilées peuvent tout aussi bien être deux messages reçus.
            //
            // La carte blanche revient donc, mais elle ne fait plus doublon
            // avec les bulles : elle joue le rôle de la fenêtre de messagerie,
            // avec un en-tête qui la nomme.
            VStack(spacing: 0) {
                if !keyboard.isVisible {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(draft.accent.opacity(0.16))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Text(verbatim: "M")
                                    .font(HZ.Fonts.fig(12.5, .bold))
                                    .foregroundStyle(draft.accent)
                            )
                        Text(String(localized: "Marie"))
                            .font(HZ.Fonts.fig(14.5, .bold))
                            .foregroundStyle(HZ.Colors.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HZ.Colors.faint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }

                if !keyboard.isVisible {
                    Divider().overlay(HZ.Colors.line)
                }

                VStack(spacing: 9) {
                    MiniBubble(text: question, accent: draft.accent)

                    if phase == .done {
                        MiniBubble(text: produced, mine: true, accent: draft.accent)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing)
                                    .combined(with: .scale(scale: 0.9, anchor: .bottomTrailing))
                                    .combined(with: .opacity),
                                removal: .opacity))
                    } else if phase == .working {
                        // Les trois points d'écriture : la même attente que dans
                        // une vraie messagerie, donc lisible sans explication.
                        HStack {
                            Spacer(minLength: 40)
                            TypingDots(accent: draft.accent)
                        }
                        .transition(.opacity)
                    } else if !keyboard.isVisible {
                        // La place de TA réponse, en pointillé et alignée à
                        // droite : c'est ce vide qui dit ce qu'on attend.
                        HStack {
                            Spacer(minLength: 46)
                            Text(String(localized: "ta réponse arrive ici"))
                                .font(HZ.Fonts.fig(12.5, .medium))
                                .foregroundStyle(HZ.Colors.faint)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(HZ.Colors.dash,
                                                      style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                                )
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 11)
                .padding(.bottom, 13)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
            )
            .animation(.spring(duration: 0.5), value: phase)

            Spacer(minLength: 12)

            // ── LE MOT QU'ON GLISSE ────────────────────────────────────
            if phase != .done {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Ce que tu veux lui dire, en un mot :"))
                        .font(HZ.Fonts.fig(14, .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 8) {
                        TextField("", text: $word, prompt:
                            Text(String(localized: "ex. trop cher"))
                                .foregroundColor(HZ.Colors.faint))
                            .font(HZ.Fonts.fig(18, .semibold))
                            .foregroundStyle(HZ.Colors.ink)
                            .tint(draft.accent)
                            .focused($focused)
                            .disabled(phase == .working)
                            .submitLabel(.done)
                            .onSubmit { focused = false }

                        if !word.isEmpty {
                            Button { word = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(HZ.Colors.faint)
                            }
                            .buttonStyle(.plain)
                        }
                        // Replier le clavier : le champ occupe toute la largeur,
                        // il n'existe donc aucune zone vide à toucher à côté.
                        if focused {
                            Button { focused = false } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(draft.accent)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 15)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white))

                    // Trois amorces qui répondent à la question affichée.
                    HStack(spacing: 7) {
                        ForEach(seeds, id: \.word) { seed in
                            Button {
                                word = seed.word
                                focused = false
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(seed.word)
                                    .font(HZ.Fonts.fig(13.5, .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 13)
                                    .frame(height: 32)
                                    .background(Capsule().fill(.white.opacity(0.20)))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .transition(.opacity)
            }

            Spacer(minLength: 12)

            // ── LE GESTE, SUR UNE POMME ────────────────────────────────
            if phase == .typing || phase == .reading {
                VStack(spacing: 9) {
                    DoubleTapZone(enabled: !word.isEmpty) { fabricate() } content: {
                        // HAUTEUR EXPLICITE ET `fixedSize`, et c'est la clé.
                        //
                        // Avec une seule contrainte de largeur, la hauteur reste
                        // négociable : dans un VStack sous pression — ce qui est
                        // exactement le cas quand le clavier occupe la moitié
                        // basse — SwiftUI écrasait l'image à zéro. Le halo et le
                        // texte, eux, ont des tailles fixes et survivaient : on
                        // voyait donc une onde et une légende désigner un
                        // téléphone invisible.
                        //
                        // En donnant les DEUX dimensions et en refusant toute
                        // compression, l'image ne peut plus disparaître.
                        Image("PhoneV2Back")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: phoneWidth,
                                   height: phoneWidth * PhoneMetrics.ratio)
                            .fixedSize()
                            .opacity(word.isEmpty ? 0.45 : 1)
                            .overlay {
                                if !word.isEmpty {
                                    DoubleTapPulse(accent: .white, size: phoneWidth)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    Text(word.isEmpty
                         ? String(localized: "Écris un mot, puis tape deux fois ici")
                         : String(localized: "Tape deux fois sur la pomme"))
                        .font(HZ.Fonts.fig(14.5, .bold))
                        .foregroundStyle(.white.opacity(word.isEmpty ? 0.6 : 0.95))
                        .multilineTextAlignment(.center)
                }
                .animation(.spring(duration: 0.4), value: word.isEmpty)
            }

            // ── TapTap commente le résultat ────────────────────────────
            TapTapAside(text: String(localized: "Ton mot, ma phrase. C'est toi qui décides du fond."),
                        visible: speaks,
                        act: .nod,
                        mouth: .smile,
                        white: true,
                        accent: draft.accent,
                        mascotSize: MascotPlace.commentSize)
                .padding(.top, 10)

            if phase == .done {
                OnbButton(title: String(localized: "J'ai compris, on continue"),
                          icon: "arrow.right",
                          fill: .white.opacity(0.22),
                          action: onNext)
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 22)
        .animation(.spring(duration: 0.5), value: phase)
        .animation(.easeOut(duration: 0.24), value: keyboard.isVisible)
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            phase = .typing
        }
    }

    private var headline: String {
        phase == .done
        ? String(localized: "Voilà. Tu donnes le fond, j'écris la forme.")
        : String(localized: "Marie attend une réponse. Donne-moi juste un mot, et j'écris la phrase à ta place.")
    }

    /// Le mot devient une phrase. On laisse un temps d'écriture visible : une
    /// réponse instantanée ne se lit pas comme un travail, mais comme un tour de
    /// passe-passe — et on ne croit pas les tours de passe-passe.
    private func fabricate() {
        guard phase == .typing || phase == .reading else { return }
        focused = false
        phase = .working
        Task {
            try? await Task.sleep(for: .milliseconds(1_150))
            phase = .done
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .milliseconds(420))
            speaks = true
        }
    }
}

/// Les trois points d'une messagerie en train d'écrire.
struct TypingDots: View {
    var accent: Color = HZ.Colors.blue
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(accent.opacity(phase == i ? 0.95 : 0.30))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(accent.opacity(0.12)))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                phase = (phase + 1) % 3
            }
        }
        .animation(.easeInOut(duration: 0.22), value: phase)
    }
}
