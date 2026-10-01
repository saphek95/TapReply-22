import SwiftUI

// =============================================================================
// ACTE I — LA RENCONTRE
// =============================================================================
//
// Objectif : donner envie et faire comprendre, sans demander un seul effort.
//
// LE CHANGEMENT DE FOND PAR RAPPORT À L'ANCIEN ONBOARDING : on ne part plus de
// la solution, on part de la SITUATION VÉCUE. « Tape deux fois au dos » en
// écran 2 se lisait comme un ordre immédiat — les gens croyaient devoir taper
// tout de suite, avant même que le raccourci existe.
//
// L'ordre est donc : je te reconnais (situation) → voilà ce que tu fais
// aujourd'hui (le contournement, chronométré) → maintenant regarde (2 secondes).
// C'est le contraste qui fait le travail, aucun impératif n'est adressé à
// l'utilisateur avant l'acte II.
// =============================================================================

// MARK: - 1 · L'éclosion

/// TapTap tombe, rebondit, fait coucou. Une demi-seconde de vide avant : c'est
/// long, et c'est voulu — le silence fait exister ce qui arrive après.
/// ÉCRAN 1 — LA RENCONTRE
///
/// Trois partis pris, dans l'ordre d'importance :
///
/// 1. TAPTAP ENTRE EN SCÈNE. Il traverse l'écran en sautillant depuis la
///    gauche, puis salue. Une mascotte déjà posée au centre au premier rendu
///    est un dessin ; une mascotte qui arrive est un personnage.
///
/// 2. IL N'Y A PAS DE BOUTON. On touche TapTap pour qu'il continue de parler,
///    et c'est lui qui fait avancer l'écran. Deux touchers, deux répliques,
///    puis on part. L'utilisateur mène la conversation à son rythme au lieu de
///    subir un minutage.
///
/// 3. LA PAROLE VIENT D'AU-DESSUS. La bulle est au-dessus de TapTap et sa
///    pointe le vise — la convention de tous les personnages qui parlent bien.
///
/// TapTap lui-même n'est PAS dans cet écran : il vit dans le routeur. On ne
/// réserve ici que sa place et sa zone tactile, pour qu'il puisse voler vers
/// l'écran suivant sans être détruit.
struct OnbHello: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    /// Les temps de la scène.
    private enum Beat: Int, Comparable {
        case hopping, firstLine, secondLine, leaving
        static func < (a: Beat, b: Beat) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var beat: Beat = .hopping
    @State private var acknowledging = false

    private var accent: Color { draft.accent }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            // ── La parole ────────────────────────────────────────────────
            // La hauteur est réservée dès le départ : sans elle, l'arrivée de
            // la bulle pousserait TapTap vers le bas au milieu de son saut.
            ZStack(alignment: .bottom) {
                Color.clear.frame(height: 128)

                if beat >= .firstLine {
                    TapTapBubble(text: line,
                                 accent: accent,
                                 tail: .bottomCenter,
                                 typing: true)
                        // L'identité suit la RÉPLIQUE, pas le temps de la
                        // scène. Avec l'identité du temps, le passage de
                        // « secondLine » à « leaving » — qui n'change pas le
                        // texte — recréait la bulle : elle se réécrivait
                        // lettre par lettre pendant la transition vers l'écran
                        // suivant, juste au moment où elle doit rester figée.
                        .id(lineIndex)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.86, anchor: .bottom)
                                .combined(with: .opacity),
                            removal: .opacity))
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 12)

            // ── Sa place, et sa zone tactile ────────────────────────────
            // TapTap garde SA couleur. En blanc plein il perd son dôme et se
            // lit comme une silhouette découpée ; c'est donc le fond qui
            // s'écarte de lui, en violet profond.
            MascotSlot(size: MascotPlace.heroSize,
                       act: mascotAct,
                       mouth: beat == .leaving ? .happy : .smile,
                       prop: beat == .leaving ? .sparkles : .none,
                       onTap: { touch() })

            Spacer(minLength: 8)

            // ── L'invitation, et la progression de la conversation ──────
            VStack(spacing: 14) {
                if beat >= .firstLine && beat != .leaving {
                    TouchHint(label: beat == .firstLine
                              ? String(localized: "Touche TapTap")
                              : String(localized: "Encore une fois"),
                              accent: accent)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))

                    // Deux pastilles : combien de fois il reste à toucher. Une
                    // jauge de formulaire serait déplacée ici, deux points
                    // suffisent à dire « c'est court ».
                    HStack(spacing: 7) {
                        ForEach(0..<2, id: \.self) { i in
                            Capsule()
                                .fill(i < beat.rawValue ? accent : accent.opacity(0.26))
                                .frame(width: i < beat.rawValue ? 22 : 8, height: 8)
                        }
                    }
                    .animation(.spring(duration: 0.4), value: beat)
                }
            }
            .frame(height: 96, alignment: .top)

            Spacer(minLength: 6)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .animation(.spring(duration: 0.45), value: beat)
        .task {
            // Le saut dure ~1,25 s. On attend un peu au-delà : il finit de se
            // stabiliser, PUIS il parle. Enchaîner sur la dernière image du
            // rebond donne l'impression qu'on lui coupe la parole.
            try? await Task.sleep(for: .milliseconds(1_700))
            beat = .firstLine
        }
    }

    private var mascotAct: MascotAct {
        if beat == .leaving { return .celebrate }
        if acknowledging { return .nod }
        switch beat {
        case .hopping:    return .hopIn
        case .firstLine:  return .wave
        default:          return .idle
        }
    }

    /// Laquelle des deux répliques est à l'écran. Deux temps distincts peuvent
    /// partager la même : c'est ce qui permet à la bulle de rester figée
    /// pendant que l'écran s'en va.
    private var lineIndex: Int { beat == .hopping || beat == .firstLine ? 0 : 1 }

    private var line: String {
        lineIndex == 0
        ? String(localized: "Coucou ! Moi, c'est TapTap.")
        : String(localized: "Je vais t'apprendre UN geste. Ensuite, répondre à un message ne te prendra plus qu'une seconde.")
    }

    /// Un toucher fait avancer la conversation. TapTap accuse réception d'un
    /// hochement avant de reprendre la parole : sans ce court accusé, on doute
    /// d'avoir été entendu.
    private func touch() {
        guard beat != .leaving else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if beat == .firstLine {
            acknowledging = true
            Task {
                try? await Task.sleep(for: .milliseconds(330))
                acknowledging = false
                beat = .secondLine
            }
        } else if beat == .secondLine {
            beat = .leaving
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                try? await Task.sleep(for: .milliseconds(760))
                onNext()
            }
        }
    }
}

struct OnbSituation: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var showBubbles = 0

    /// Trois messages choisis pour qu'on se dise « celui-là, j'aurais mis du
    /// temps à y répondre ». Un remerciement sincère auquel « de rien » ne
    /// suffit pas, une demande d'avis franc qui demande du tact, puis la
    /// relance qui met la pression. Des questions fermées du type « on se voit
    /// demain ? » n'illustraient rien : on y répond en un mot.
    private let received = [
        String(localized: "Merci d'avoir pris le temps hier, ça m'a vraiment aidé 🙏"),
        String(localized: "Du coup tu en penses quoi de ma proposition ? Sois honnête !"),
        String(localized: "Alors ? 😅")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // La douleur n'est pas « je ne sais pas quoi répondre » : la plupart
            // du temps on sait très bien quoi dire. Ce qui coince, c'est de
            // trouver la formulation juste, et l'énergie de bien l'écrire.
            OnbTypewriter(text: String(localized: "Tu sais quoi répondre.\nMais pas comment l'écrire."),
                          font: HZ.Fonts.fig(28, .bold))
                .padding(.top, 14)

            // Trois messages qui arrivent l'un après l'autre, et un curseur qui
            // clignote dans le vide : l'attente est le sujet de l'écran.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(received.enumerated()), id: \.offset) { i, text in
                    if i < showBubbles {
                        HStack {
                            Text(text)
                                .font(HZ.Fonts.fig(14.5, .medium))
                                .foregroundStyle(HZ.Colors.ink)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 11)
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 18, bottomLeadingRadius: 5,
                                        bottomTrailingRadius: 18, topTrailingRadius: 18,
                                        style: .continuous
                                    ).fill(.white)
                                )
                                .shadow(color: HZ.Colors.ink.opacity(0.05), radius: 8, y: 3)
                            Spacer(minLength: 30)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }

                // Le champ de saisie, VIDE, avec son curseur qui clignote dans
                // le vide et le temps qui passe au-dessus.
                //
                // La version précédente mettait « toi, qui cherches tes mots »
                // en italique gris dans un cadre pointillé : on ne savait pas
                // si c'était une légende, une bulle ou une barre de saisie. Un
                // champ dessiné comme un vrai champ — fond blanc, bouton
                // d'envoi éteint, curseur qui bat — se reconnaît sans légende,
                // et le compteur dit tout le reste.
                if showBubbles >= received.count {
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(String(localized: "40 secondes plus tard, toujours rien d'envoyé. Pas faute d'idée : tu cherches la bonne formulation."))
                            .font(HZ.Fonts.fig(14.5, .semibold))
                            .foregroundStyle(HZ.Colors.sub)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)

                        // Une barre de saisie se reconnaît à trois choses : un
                        // texte d'invite, un curseur, et un bouton d'envoi.
                        // Il n'y avait que le curseur, et le bouton était si
                        // pâle qu'on ne le voyait pas : on ne comprenait donc
                        // pas qu'on regardait un champ de message.
                        HStack(spacing: 10) {
                            HStack(spacing: 3) {
                                Capsule()
                                    .fill(draft.accent)
                                    .frame(width: 2.5, height: 18)
                                    .modifier(BlinkingCursor())
                                Text(String(localized: "Écrire un message…"))
                                    .font(HZ.Fonts.fig(15, .regular))
                                    .foregroundStyle(HZ.Colors.faint)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)

                            // Le bouton d'envoi, à sa couleur, mais éteint :
                            // il est bien là, il n'a simplement rien à envoyer.
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(draft.accent.opacity(0.45))
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .strokeBorder(HZ.Colors.line, lineWidth: 1)
                        )
                        // Raturé EN ROUGE, d'un trait qui se tire de gauche à
                        // droite : le champ est là pour raconter l'échec, pas
                        // pour être utilisé. Sans ce signal, on hésitait entre
                        // écrire dedans et toucher le bouton du bas.
                        // La rature couvre le TEXTE, pas le bouton d'envoi :
                        // barrer le bouton laisserait croire qu'il est cassé,
                        // alors que le problème est qu'on n'a rien écrit.
                        .overlay(alignment: .leading) {
                            StrikeThrough(color: HZ.Colors.mRed, thickness: 2.5, delay: 0.55)
                                .frame(width: 196)
                                .padding(.leading, 18)
                        }
                        .opacity(0.78)
                        .allowsHitTesting(false)
                    }
                    .padding(.top, 6)
                    .transition(.opacity)
                }
            }
            .padding(.top, 30)

            Spacer()

            TapTapAside(text: String(localized: "Moi, écrire, c'est tout ce que je sais faire."),
                        mouth: .neutral,
                        accent: draft.accent,
                        mascotSize: MascotPlace.asideSize)
            .padding(.bottom, 22)

            // La direction est portée par le bouton lui-même, pas par une
            // flèche flottante au-dessus : deux repères pour une seule action,
            // c'est un repère de trop.
            OnbButton(title: String(localized: "Et aujourd'hui, tu fais comment ?"),
                      icon: "arrow.right",
                      fill: draft.accent, action: onNext)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 26)
        .task {
            for i in 1...received.count {
                try? await Task.sleep(for: .seconds(i == 1 ? 0.7 : 0.75))
                withAnimation(.spring(duration: 0.4)) { showBubbles = i }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }
}

private struct BlinkingCursor: ViewModifier {
    @State private var on = true
    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0.15)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: on)
            .onAppear { on = false }
    }
}

// MARK: - 3 · L'ancienne façon de faire

/// On montre le contournement actuel, avec son coût en secondes. RIEN n'est
/// barré ni rayé : l'ancien onboarding barrait ses lignes, on ne pouvait plus
/// les lire, et on ne comprenait donc pas ce qu'on gagnait. Ici on laisse
/// lire, et c'est le CHRONOMÈTRE qui fait l'argument.
struct OnbOldWay: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var revealed = 0
    @State private var seconds = 0

    /// Chaque étape se lit SEULE, sans avoir mémorisé la précédente : « la
    /// réponse » devient « la réponse de ChatGPT », « l'image » devient « cette
    /// photo ». C'est plus long à lire, et c'est le prix de la compréhension —
    /// l'écran doit se laisser lire par quelqu'un qui n'a jamais fait ça.
    private let steps: [(icon: String, text: String, cost: Int)] = [
        ("camera.viewfinder",
         String(localized: "Tu prends une photo de l'écran de la conversation"), 5),
        ("arrow.up.forward.app",
         String(localized: "Tu quittes la discussion et tu ouvres une autre app"), 8),
        ("photo.on.rectangle",
         String(localized: "Tu envoies cette capture à une IA, et tu lui expliques quoi répondre"), 15),
        ("doc.on.doc",
         String(localized: "Tu attends, puis tu copies la réponse qu'il propose"), 4),
        ("arrow.uturn.backward",
         String(localized: "Tu retournes dans la discussion"), 5),
        ("text.cursor",
         String(localized: "Tu colles la réponse, tu la corriges, tu envoies"), 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poser la SCÈNE avant la liste : sans elle, « aujourd'hui tu fais
            // ça » ne dit pas de quoi on parle, et les six étapes arrivent sans
            // sujet.
            // Même nuance que l'écran précédent : le problème n'est pas de
            // trouver quoi dire, c'est d'écrire correctement sans y passer
            // l'après-midi. Le titre dit donc l'objectif, la liste dit le prix.
            OnbTypewriter(text: String(localized: "Pour écrire une belle réponse, aujourd'hui, tu fais ça."),
                          font: HZ.Fonts.fig(26, .bold))
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    if i < revealed {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(HZ.Colors.card)
                                    .frame(width: 34, height: 34)
                                Image(systemName: s.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(HZ.Colors.sub)
                            }
                            Text(s.text)
                                .font(HZ.Fonts.fig(14.5, .medium))
                                .foregroundStyle(HZ.Colors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Text(verbatim: "+\(s.cost)s")
                                .font(HZ.Fonts.fig(12.5, .bold))
                                .foregroundStyle(HZ.Colors.faint)
                                .monospacedDigit()
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(.top, 24)

            // Le compteur. C'est LUI l'argument : il grossit à mesure que la
            // liste s'allonge, et il restera à l'écran suivant pour le contraste.
            if revealed >= steps.count {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HZ.Colors.mRed)
                    Text(String(localized: "Environ \(seconds) secondes. Chaque fois."))
                        .font(HZ.Fonts.fig(17, .bold))
                        .foregroundStyle(HZ.Colors.mRed)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HZ.Colors.mRed.opacity(0.08))
                )
                .padding(.top, 22)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Spacer()

            if revealed >= steps.count {
                TapTapAside(text: String(localized: "Six étapes pour un message. On peut faire mieux."),
                            mouth: .neutral,
                            prop: .glasses,
                            accent: draft.accent,
                            mascotSize: MascotPlace.asideSize)
                .padding(.bottom, 22)
                .transition(.opacity)
            }

            OnbButton(title: String(localized: "Montre-moi mieux"),
                      icon: "sparkles",
                      fill: draft.accent,
                      enabled: revealed >= steps.count,
                      action: onNext)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 26)
        .task {
            for i in 1...steps.count {
                try? await Task.sleep(for: .seconds(0.42))
                withAnimation(.spring(duration: 0.35)) { revealed = i }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                // Le compteur monte en même temps que la liste : on VOIT le
                // coût s'accumuler, on ne le lit pas à la fin.
                withAnimation(.easeOut(duration: 0.3)) {
                    seconds += steps[i - 1].cost
                }
            }
        }
    }
}

// MARK: - 4 · La démonstration muette

/// L'ÉCRAN LE PLUS IMPORTANT DE TOUT L'ONBOARDING. C'est ici qu'on comprend
/// l'app — ou qu'on ne la comprend jamais.
///
/// Quatre temps de 1,5 s, en boucle, avec un sous-titre par temps. Trois choix
/// non négociables, tous issus des défauts constatés sur l'ancien écran :
///
///   · UN SEUL DOIGT, DERRIÈRE LE TÉLÉPHONE. On voit le DOS de l'appareil, pas
///     l'écran. C'était la confusion numéro un : les gens ne savaient pas où
///     taper.
///   · DEUX IMPULSIONS ESPACÉES DE 180 ms, distinctement visibles. On doit voir
///     DEUX coups, pas un flash.
///   · LENT — 6 secondes. Une démonstration qui va vite ne démontre rien. Et
///     un bouton « Revoir » toujours disponible.
///
/// Le bouton de sortie n'apparaît qu'APRÈS le premier cycle complet : on ne
/// peut pas sauter la démonstration sans l'avoir vue une fois.
struct OnbDemo: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    /// 0 = conversation · 1 = le geste · 2 = TapTap lit · 3 = la réponse
    @State private var beat = 0
    @State private var seenOnce = false
    @State private var flipped = false

    /// L'explication de l'étape en cours. Elle est EN HAUT ET EN GRAND, jamais
    /// en légende grise sous l'image : c'est le texte qui doit porter la
    /// compréhension, l'animation ne fait que l'illustrer. Chaque phrase se lit
    /// seule, sans supposer qu'on connaît déjà l'application.
    private var captions: [String] {
        [String(localized: "Quelqu'un t'écrit, et tu ne sais pas quoi répondre."),
         String(localized: "Tu tapes deux fois au dos de ton téléphone. Sans rien ouvrir, sans rien copier."),
         String(localized: "TapTap lit la conversation affichée à l'écran, tout seul."),
         String(localized: "Ta réponse est écrite, dans ton ton. Tu n'as plus qu'à l'envoyer.")]
    }

    /// Ce que TapTap joue selon le temps : il est perplexe devant le problème,
    /// concentré pendant la lecture, ravi à l'arrivée de la réponse.
    private var watching: MascotAct {
        switch beat {
        case 0:  return .think
        case 1:  return .surprise
        case 2:  return .think
        default: return .celebrate
        }
    }

    private var watchingMouth: MascotMouth {
        switch beat {
        case 0:  return .neutral
        case 1:  return .surprised
        case 2:  return .neutral
        default: return .happy
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "VOICI COMMENT ÇA MARCHE"))
                .font(HZ.Fonts.fig(12.5, .bold))
                .tracking(1.3)
                .foregroundStyle(draft.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            Text(captions[beat])
                .font(HZ.Fonts.fig(23, .bold))
                .foregroundStyle(HZ.Colors.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .padding(.top, 8)
                .id(beat)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity))

            Spacer(minLength: 8)

            // La scène. Le téléphone se retourne au temps 1 pour montrer le dos,
            // puis revient au temps 2 : le geste et son effet sont donc reliés
            // par un même objet, pas par deux illustrations séparées.
            ZStack {
                if beat == 1 {
                    backStage
                        .transition(.opacity)
                } else {
                    frontStage
                        .transition(.opacity)
                }
            }
            .frame(height: 380)

            Spacer(minLength: 8)

            // TapTap regarde la démonstration avec nous, et réagit à chaque
            // temps. Il est petit et en retrait : c'est le téléphone le sujet
            // de cet écran. Mais il ne DISPARAÎT pas — sans quoi la continuité
            // se romprait au milieu du récit, juste avant qu'on demande à
            // l'utilisateur d'essayer lui-même.
            // Les points sont CENTRÉS sur l'écran ; TapTap est posé par-dessus,
            // à gauche. Dans un HStack, sa présence décalait les points vers la
            // droite et on ne comprenait plus à quoi ils se rapportaient.
            ZStack {
                HStack(spacing: 6) {
                    ForEach(0..<captions.count, id: \.self) { i in
                        Capsule()
                            .fill(i == beat ? draft.accent : draft.accent.opacity(0.24))
                            .frame(width: i == beat ? 20 : 7, height: 7)
                    }
                }
                .animation(.spring(duration: 0.35), value: beat)

                HStack {
                    MascotSlot(size: MascotPlace.asideSize, act: watching, mouth: watchingMouth)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 62)
            .padding(.bottom, 8)

            if seenOnce {
                OnbButton(title: String(localized: "J'ai compris"),
                          fill: draft.accent, action: onNext)
                    .transition(.opacity)
                OnbLink(title: String(localized: "Revoir depuis le début")) { restart() }
                    .padding(.top, 12)
            } else {
                // L'invitation à glisser. Une flèche qui va et vient dit le
                // geste mieux qu'une phrase, et la phrase reste là pour ceux
                // qui ne lisent pas les flèches.
                SwipeOnward(label: String(localized: "Glisse vers la gauche pour voir la suite"),
                            accent: draft.accent,
                            action: advance)
                    .frame(height: 58)
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        // On NAVIGUE, on ne subit pas. La boucle automatique avançait plus vite
        // qu'on ne lit : on n'avait le temps ni de lire l'explication en haut,
        // ni de regarder la conversation. Chacun prend le rythme qu'il veut.
        //
        // `frame` + `contentShape` AVANT le geste : sans cette paire, la zone
        // sensible se limite aux pixels dessinés, et le glissement ne
        // fonctionnait que sur le téléphone.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { g in
                    if g.translation.width < -40 { advance() }
                    else if g.translation.width > 40 { back() }
                }
        )
    }

    // MARK: La face avant — conversation, île, réponse

    private var frontStage: some View {
        PhoneFrame(width: 186) {
            VStack(spacing: 0) {
                // L'île, au temps 2 et 3.
                if beat >= 2 {
                    OnbIsland(phase: beat == 2 ? .working : .ready,
                              reply: beat == 3 ? String(localized: "Oui carrément, 18h comme prévu !") : "",
                              accent: draft.accent,
                              mascotColor: draft.accent)
                        .scaleEffect(0.74)
                        .padding(.top, 4)
                        .transition(.scale(scale: 0.4, anchor: .top).combined(with: .opacity))
                }

                VStack(spacing: 7) {
                    MiniBubble(text: String(localized: "Salut ! On se voit toujours demain ?"),
                               accent: draft.accent)
                    MiniBubble(text: String(localized: "Oui, 18h ça marche"),
                               mine: true, accent: draft.accent)
                    MiniBubble(text: String(localized: "Parfait. Tu confirmes ?"),
                               accent: draft.accent)
                }
                .padding(.horizontal, 11)
                .padding(.top, beat >= 2 ? 8 : 34)

                Spacer(minLength: 0)

                // Le champ de saisie, où la réponse se colle au temps 3.
                HStack(spacing: 5) {
                    Text(beat == 3
                         ? String(localized: "Oui carrément, 18h comme prévu !")
                         : String(localized: "Message"))
                        .font(HZ.Fonts.fig(10.5, beat == 3 ? .medium : .regular))
                        .foregroundStyle(beat == 3 ? HZ.Colors.ink : HZ.Colors.faint)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if beat == 3 {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(draft.accent)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(beat == 3 ? draft.accent.opacity(0.09) : HZ.Colors.card)
                )
                .overlay(
                    Capsule().strokeBorder(beat == 3 ? draft.accent.opacity(0.5) : .clear,
                                           lineWidth: 1.3)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .animation(.spring(duration: 0.4), value: beat)
            }
        }
    }

    // MARK: Le dos — le geste

    private var backStage: some View {
        ZStack {
            PhoneBack(width: 186, accent: .white, pulsing: true)

            // Le doigt qui tape, DERRIÈRE l'appareil : c'est ce qui fait
            // comprendre qu'on tape le dos et non l'écran.
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 44))
                .foregroundStyle(HZ.Colors.ink.opacity(0.85))
                .rotationEffect(.degrees(-18))
                .offset(x: 52, y: 44)
                .modifier(TwoTapNudge())
        }
    }

    /// Deux impulsions espacées de 180 ms, puis une pause : la cadence exacte
    /// d'un double tap. C'est un métronome, pas une décoration.
    private struct TwoTapNudge: ViewModifier {
        @State private var phase = 0
        func body(content: Content) -> some View {
            content
                .offset(x: phase == 1 ? -7 : 0, y: phase == 1 ? -5 : 0)
                .scaleEffect(phase == 1 ? 0.92 : 1)
                .task {
                    while !Task.isCancelled {
                        for _ in 0..<2 {
                            withAnimation(.easeOut(duration: 0.07)) { phase = 1 }
                            try? await Task.sleep(for: .milliseconds(80))
                            withAnimation(.easeIn(duration: 0.10)) { phase = 0 }
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                        try? await Task.sleep(for: .milliseconds(900))
                    }
                }
        }
    }

    // MARK: Le séquenceur

    private func advance() {
        guard beat < captions.count - 1 else {
            if !seenOnce { withAnimation(.spring(duration: 0.45)) { seenOnce = true } }
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(duration: 0.45)) {
            beat += 1
            if beat == captions.count - 1 { seenOnce = true }
        }
    }

    private func back() {
        guard beat > 0 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(duration: 0.45)) { beat -= 1 }
    }

    private func restart() {
        beat = 0
    }
}
