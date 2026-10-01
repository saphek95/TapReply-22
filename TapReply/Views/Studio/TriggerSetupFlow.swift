import SwiftUI

// =============================================================================
// MINI-ONBOARDING D'UN GESTE SECONDAIRE (Triple Tap · bouton Action)
// =============================================================================
//
// LE PROBLÈME QU'IL RÉSOUT
// Assigner un ton à un geste ne suffit pas : sans son raccourci et sans
// l'association côté Réglages iOS, le geste ne répond pas. Une petite carte
// discrète sous les emplacements ne suffisait pas — on pouvait l'ignorer, puis
// triple-taper dans le vide et conclure « ça ne marche pas ».
//
// Ce plein écran s'impose donc à la PREMIÈRE assignation, et il déroule les
// trois temps dans l'ordre : installer, associer, ÉPROUVER.
//
// LA TROISIÈME ÉTAPE EST UNE VRAIE PREUVE, PAS UNE DÉCLARATION
// Contrairement au raccourci du double tap (que iOS ne permet pas de vérifier),
// ici on sait : chaque action « Analyser » horodate son passage dans une clé qui
// lui est propre — `trigger.runGuardKey`, posée pour l'anti-rebond. Si cette clé
// bouge, c'est que CE raccourci-là, et lui seul, vient de s'exécuter. Le geste
// est donc constaté, pas cru sur parole.
//
// Un seul essai ici, là où l'onboarding en compte deux : le premier sert à
// obtenir les autorisations iOS, déjà accordées à ce stade.
struct TriggerSetupFlow: View {
    let trigger: ToneTrigger
    /// Appelé quand tout est validé (le raccourci est marqué confirmé).
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var theme = HZTheme.shared

    private enum Step: Int { case install, associate, test, done }
    @State private var step: Step = .install
    /// Horodatage d'entrée dans l'étape de test — tout marqueur postérieur
    /// prouve que le geste vient d'être fait MAINTENANT.
    @State private var testStartedAt = Date().timeIntervalSince1970
    @State private var gestureSeen = false
    @State private var replySeen = false
    /// Échappatoire : après 45 s sans geste détecté, on laisse sortir. Personne
    /// ne doit rester prisonnier d'un écran à cause d'une coque trop épaisse.
    @State private var canSkip = false
    /// Le texte généré, affiché à l'écran une fois arrivé.
    @State private var replyText = ""
    @State private var islandDismissed = false
    @State private var copied = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case .install:   installStep
                    case .associate: associateStep
                    case .test:      testStep
                    case .done:      doneStep
                    }
                }
                .padding(.horizontal, HZ.Spacing.gutter)
                .padding(.bottom, 24)
            }

            footer
        }
        .background(HZ.Colors.page.ignoresSafeArea())
        // ÎLE SIMULÉE — indispensable ici : la VRAIE Live Activity ne s'affiche
        // pas de façon fiable quand TapReply est au premier plan. C'est déjà la
        // raison de son existence dans l'onboarding et le terrain d'essai ; cet
        // écran l'avait oubliée, d'où un essai qui réussissait sans que rien
        // n'apparaisse à l'écran.
        .overlay(alignment: .top) {
            if step == .test, gestureSeen, !islandDismissed {
                FakeIslandView(state: replySeen ? .ready : .generating,
                               reply: replyText)
                    .padding(.top, 4)
                    .transition(.scale(scale: 0.3, anchor: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { islandDismissed = true } }
            }
        }
        .onReceive(timer) { _ in tick() }
    }

    // MARK: - En-tête : progression + sortie

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Activer le \(trigger.label)"))
                        .font(HZ.Fonts.fig(22, .bold))
                        .foregroundStyle(HZ.Colors.ink)
                    Text(stepCaption)
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                }
                Spacer(minLength: 0)
                // On peut TOUJOURS sortir. La petite carte du Studio reprendra
                // le relais : on ne piège personne dans un écran.
                HZCloseButton { dismiss() }
            }

            // Trois segments de progression
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i <= min(step.rawValue, 2) ? HZ.Colors.blue : HZ.Colors.cardDeep)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private var stepCaption: String {
        switch step {
        case .install:   return String(localized: "Étape 1 sur 3 · le raccourci")
        case .associate: return String(localized: "Étape 2 sur 3 · le geste")
        case .test:      return String(localized: "Étape 3 sur 3 · l'essai")
        case .done:      return String(localized: "C'est prêt")
        }
    }

    // MARK: - Étape 1 · installer le raccourci

    private var installStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            explainer(icon: "info.circle.fill",
                      text: String(localized: "iOS ne dit pas à TapReply quel geste tu viens de faire. Le \(trigger.label) a donc besoin de SON raccourci, sinon il jouerait le ton du double tap."))

            if trigger.installURL != nil {
                // L'ÉCRAN QU'ON VA VOIR, RECONSTITUÉ — même parti pris que
                // l'onboarding : on montre la fiche Raccourcis telle qu'elle
                // s'affichera, avec le NOM EXACT de ce raccourci-ci et le
                // bouton bleu du système dessiné à sa place. Quelqu'un qui n'a
                // jamais ouvert l'app Raccourcis sait ainsi où il devra
                // appuyer AVANT d'y arriver.
                //
                // Cet écran n'avait qu'une liste de puces et un grand vide en
                // dessous : on lisait des consignes sans savoir à quoi
                // ressemblerait la destination.
                ShortcutCardPreview(shortcutName: trigger.shortcutName,
                                    accent: HZ.Colors.blue) { install() }

                numbered(1, String(localized: "Touche la carte ci-dessus"),
                         String(localized: "L'app Raccourcis s'ouvre sur la fiche du raccourci."))
                numbered(2, String(localized: "Appuie sur « Ajouter ce raccourci »"),
                         String(localized: "Garde son nom : tu le chercheras sous « \(trigger.shortcutName) »."))
                numbered(3, String(localized: "Reviens ici"),
                         String(localized: "On passe à l'association au geste."))
            } else {
                // Repli : lien iCloud non publié → création manuelle.
                TriggerShortcutGuideView(trigger: trigger)
            }
        }
    }

    private func install() {
        if let url = trigger.installURL { openURL(url) }
    }

    // MARK: - Étape 2 · associer au geste, côté iOS

    private var associateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            explainer(icon: "gearshape.fill",
                      text: String(localized: "Cette association se fait dans les Réglages d'iOS : aucune app ne peut la faire à ta place."))

            // LE CHEMIN REDESSINÉ, LIGNE PAR LIGNE, QUI SE PARCOURT TOUT SEUL.
            //
            // Il remplace la seule phrase « Réglages → Accessibilité → … » :
            // une flèche entre deux mots ne dit pas qu'il faut ENTRER dans une
            // page, puis dans une autre. Les lignes reconstituées, elles, se
            // reconnaissent à l'écran, et la surbrillance qui avance montre
            // qu'il s'agit d'une SUITE d'écrans.
            //
            // Redessiné plutôt que capturé : une capture ne se traduit pas, ne
            // clignote pas, et vieillit à chaque version d'iOS.
            //
            // Et le chemin n'est PAS le même selon le geste — c'est justement
            // ce que cet écran devait cesser d'ignorer.
            TriggerSettingsPath(trigger: trigger, accent: HZ.Colors.blue)

            numbered(1, String(localized: "Ouvre les Réglages iOS"),
                     String(localized: "Le bouton en bas t'y emmène directement."))
            numbered(2, String(localized: "Suis le chemin ci-dessus"),
                     trigger == .actionButton
                     ? String(localized: "Fais défiler les options du bouton jusqu'à « Raccourci ».")
                     : String(localized: "« Toucher le dos de l'appareil » est tout en bas de la page « Toucher »."))
            numbered(3, String(localized: "Sélectionne « \(trigger.shortcutName) »"),
                     trigger == .actionButton
                     ? String(localized: "Dans la liste des raccourcis. Puis reviens : on teste tout de suite.")
                     : String(localized: "Tout en bas de la liste des actions. Puis reviens : on teste tout de suite."))

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Label(String(localized: "Ouvrir Réglages"), systemImage: "arrow.up.forward.app")
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Étape 3 · l'essai, constaté et non déclaré

    private var testStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Consigne en carte d'accent — le geste est la seule action possible.
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.18))
                    Image(systemName: trigger.systemIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(testHeadline)
                        .font(HZ.Fonts.fig(16.5, .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(testDetail)
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(replySeen ? HZ.Colors.green : HZ.Colors.blue,
                        in: RoundedRectangle(cornerRadius: HZ.Radius.row, style: .continuous))
            .hzFloating()

            // LA RÉPONSE, une fois arrivée. Sans elle, l'écran annonçait la
            // réussite sans jamais montrer le résultat — on ne pouvait ni le
            // lire, ni vérifier que le bon ton avait été employé.
            if replySeen, !replyText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(HZ.Colors.green)
                        Text(String(localized: "Réponse générée : déjà dans ton presse-papiers"))
                            .font(HZ.Fonts.fig(13.5, .semibold))
                            .foregroundStyle(HZ.Colors.green)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(replyText)
                        .font(HZ.Fonts.body)
                        .foregroundStyle(HZ.Colors.ink)
                        // Sans fixedSize, SwiftUI tronque un Text multi-lignes
                        // dans un ScrollView — piège déjà payé deux fois.
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        UIPasteboard.general.string = replyText
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.snappy) { copied = true }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                            Text(copied ? String(localized: "Copié")
                                        : String(localized: "Copier à nouveau"))
                                .font(HZ.Fonts.fig(14, .semibold))
                        }
                        .foregroundStyle(HZ.Colors.blue)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(HZ.Colors.tint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hzCard(radius: HZ.Radius.card)
                .hzSoft()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Une conversation à analyser — c'est CET écran que le raccourci
            // capture, il lui faut donc de quoi lire.
            VStack(alignment: .leading, spacing: 9) {
                HZChatBubble(text: String(localized: "Tu es dispo pour un appel demain matin ?"), kind: .incoming)
                HZChatBubble(text: String(localized: "Je regarde et je te confirme."), kind: .outgoing)
                HZChatBubble(text: String(localized: "Super, tiens-moi au courant avant ce soir si possible !"), kind: .incoming)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(radius: HZ.Radius.card)
            .hzSoft()
        }
    }

    private var testHeadline: String {
        if replySeen { return String(localized: "Réussi : le \(trigger.label) fonctionne") }
        if gestureSeen { return String(localized: "Geste reçu, génération en cours…") }
        return String(localized: "Fais le geste maintenant, ici")
    }

    private var testDetail: String {
        if replySeen { return String(localized: "La réponse est dans ton presse-papiers.") }
        if gestureSeen { return String(localized: "Le génie lit la conversation.") }
        return trigger == .actionButton
            ? String(localized: "Presse le bouton Action sur le côté de l'iPhone.")
            : String(localized: "Trois tapes fermes au dos de l'iPhone.")
    }

    // MARK: - Étape 4 · c'est prêt

    private var doneStep: some View {
        VStack(spacing: 18) {
            MascotAvatarView(index: UserDefaults.standard.integer(forKey: SettingsKeys.avatarColorIndex),
                             size: 120, crowned: true)
                .padding(.top, 20)
            Text(String(localized: "Le \(trigger.label) est opérationnel"))
                .font(HZ.Fonts.section)
                .foregroundStyle(HZ.Colors.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "Tu as maintenant deux tons sous la main, chacun sur son geste. Change-les quand tu veux depuis le Studio."))
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pied

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            switch step {
            case .install:
                HZPrimaryButton(title: String(localized: "Le raccourci est ajouté"),
                                fill: HZ.Colors.blue) {
                    withAnimation(.snappy) { step = .associate }
                }
            case .associate:
                HZPrimaryButton(title: String(localized: "C'est associé, on teste"),
                                fill: HZ.Colors.blue) {
                    testStartedAt = Date().timeIntervalSince1970
                    gestureSeen = false
                    replySeen = false
                    canSkip = false
                    replyText = ""
                    copied = false
                    islandDismissed = false
                    withAnimation(.snappy) { step = .test }
                }
                Button(String(localized: "Revenir au raccourci")) {
                    withAnimation(.snappy) { step = .install }
                }
                .font(HZ.Fonts.strong)
                .foregroundStyle(HZ.Colors.sub)
            case .test:
                if replySeen {
                    HZPrimaryButton(title: String(localized: "Terminer"),
                                    fill: HZ.Colors.green) {
                        withAnimation(.snappy) { step = .done }
                    }
                } else {
                    // Aucun bouton pour « valider » soi-même : ici la preuve
                    // vient du geste, pas d'une case à cocher.
                    Text(String(localized: "En attente de ton \(trigger.label)…"))
                        .font(HZ.Fonts.strong)
                        .foregroundStyle(HZ.Colors.sub)
                    if canSkip {
                        Button(String(localized: "Le geste ne répond pas : voir l'aide")) {
                            withAnimation(.snappy) { step = .associate }
                        }
                        .font(HZ.Fonts.strong)
                        .foregroundStyle(HZ.Colors.blue)
                    }
                }
            case .done:
                HZPrimaryButton(title: String(localized: "Parfait"),
                                fill: HZ.Colors.blue) {
                    UserDefaults.standard.set(true, forKey: trigger.shortcutConfirmedKey)
                    onFinished()
                    dismiss()
                }
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(HZ.Colors.page)
    }

    // MARK: - Briques de présentation
    //
    // ⚠️ Ces deux helpers étaient APPELÉS sans être définis : 8 erreurs
    // « Cannot find in scope » au build. Même faute que le helper `field` de
    // l'éditeur de ton. Règle retenue : après avoir écrit une vue, relire la
    // liste de ses appels internes et vérifier que chacun existe.

    /// Le bandeau d'explication teinté, en tête d'étape : il porte le POURQUOI
    /// avant le comment.
    private func explainer(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HZ.Colors.blue)
            Text(text)
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HZ.Colors.tint,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Une étape numérotée : pastille à la couleur de l'app, titre, détail.
    private func numbered(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(HZ.Fonts.fig(13, .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(HZ.Colors.blue, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HZ.Fonts.headline)
                    .foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Détection du geste (la preuve)

    private func tick() {
        guard step == .test else { return }

        // ① LE BON RACCOURCI A-T-IL TOURNÉ ? runGuardKey est propre à ce geste :
        //    si son horodatage est postérieur à l'entrée dans l'étape, c'est
        //    bien CE raccourci — et aucun autre — qui vient de s'exécuter.
        if !gestureSeen {
            let stamp = UserDefaults.standard.double(forKey: trigger.runGuardKey)
            if stamp > testStartedAt {
                withAnimation(.spring(duration: 0.4)) { gestureSeen = true }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        // ② LA RÉPONSE EST-ELLE ARRIVÉE ? (chaîne complète validée)
        if gestureSeen, !replySeen,
           let last = AppSettings.lastReplyAt,
           last.timeIntervalSince1970 > testStartedAt {
            replyText = AppSettings.lastReplyText
            withAnimation(.spring(duration: 0.45)) { replySeen = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        if !canSkip, Date().timeIntervalSince1970 - testStartedAt > 45 {
            withAnimation { canSkip = true }
        }
    }
}

// =============================================================================
// LA FICHE RACCOURCIS, RECONSTITUÉE
// =============================================================================
//
// Reprise du parti pris de l'onboarding (OnbSetupShortcut) : plutôt que
// d'écrire « touche Ajouter le raccourci », on DESSINE l'écran où il faudra le
// faire. La différence avec l'onboarding est le nom : celui-ci est paramétré,
// parce qu'un geste secondaire n'installe pas « TapReply » mais
// « TapReply (Triple Tap) » ou « TapReply (Action Button) ». Afficher le nom
// générique ici enverrait chercher un raccourci qui n'existe pas.
private struct ShortcutCardPreview: View {
    let shortcutName: String
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 11) {
                Image("IconPreviewViolet")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: HZ.Colors.ink.opacity(0.16), radius: 12, y: 5)

                // Le nom EXACT du raccourci à chercher, pas le nom de l'app.
                Text(verbatim: shortcutName)
                    .font(HZ.Fonts.fig(16.5, .bold))
                    .foregroundStyle(HZ.Colors.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "Raccourci"))
                    .font(HZ.Fonts.fig(12.5, .medium))
                    .foregroundStyle(HZ.Colors.faint)
            }
            .padding(.top, 22)
            .padding(.bottom, 18)
            .padding(.horizontal, 16)

            // Le bouton du système, tel qu'il apparaît dans l'app Raccourcis.
            // Bleu iOS volontairement — c'est la couleur qu'il aura là-bas,
            // pas celle du thème de l'utilisateur.
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(String(localized: "Ajouter le raccourci"))
                    .font(HZ.Fonts.fig(15.5, .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 46)
            .background(Capsule().fill(Color(hex: 0x0A84FF)))
            .overlay(alignment: .trailing) {
                // Le doigt qui désigne le bouton à toucher, une fois là-bas.
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(HZ.Colors.ink.opacity(0.75))
                    .offset(x: 26, y: 14)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(HZ.Colors.line, lineWidth: 1))
        // TOUTE la carte ouvre l'app Raccourcis, pas seulement le bouton dessiné.
        // Quelqu'un qui voit un bouton bleu « Ajouter le raccourci » au milieu de
        // l'écran va le toucher : qu'il tombe sur une image inerte serait une
        // impasse absurde.
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { onTap() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(localized: "Ouvrir l'app Raccourcis"))
    }
}

// =============================================================================
// LE CHEMIN DANS LES RÉGLAGES, PAR GESTE
// =============================================================================
//
// Une ligne de texte « Réglages → Accessibilité → Toucher → … » se lit comme
// une adresse, pas comme une suite d'écrans à traverser. Les lignes
// reconstituées se reconnaissent à l'œil quand on y arrive, et la surbrillance
// qui avance en boucle dit qu'il y a plusieurs étapes.
//
// ⚠️ Les chemins sont RÉELLEMENT différents :
//   • Triple Tap     → Accessibilité › Toucher › Toucher le dos › Toucher trois fois
//   • Bouton Action  → Bouton Action › (défiler jusqu'au mode « Raccourci »)
// Le bouton Action ne passe pas du tout par l'Accessibilité, et son mode se
// choisit en faisant défiler un carrousel — ce qu'aucun texte ne laissait
// deviner.
private struct TriggerSettingsPath: View {
    let trigger: ToneTrigger
    let accent: Color

    @State private var highlight = 0

    private struct Row {
        let icon: String
        let tint: Color
        let label: String
        var value: String? = nil
        var hint: String? = nil
    }

    private var rows: [Row] {
        let iosBlue = Color(hex: 0x0A84FF)
        switch trigger {
        case .actionButton:
            return [
                Row(icon: "button.vertical.left.press.fill", tint: iosBlue,
                    label: String(localized: "Bouton Action")),
                Row(icon: "arrow.left.and.right", tint: HZ.Colors.sub,
                    label: String(localized: "Raccourci"),
                    hint: String(localized: "fais défiler les modes jusqu'à « Raccourci »")),
                Row(icon: "bolt.fill", tint: accent,
                    label: trigger.shortcutName,
                    hint: String(localized: "touche « Choisir un raccourci »"))
            ]
        case .tripleTap, .doubleTap:
            return [
                Row(icon: "accessibility", tint: iosBlue,
                    label: String(localized: "Accessibilité")),
                Row(icon: "hand.point.up.left.fill", tint: iosBlue,
                    label: String(localized: "Toucher")),
                Row(icon: "iphone.gen3", tint: HZ.Colors.sub,
                    label: String(localized: "Toucher le dos de l'appareil"),
                    value: String(localized: "Désactivé"),
                    hint: String(localized: "tout en bas de la page")),
                Row(icon: trigger == .tripleTap ? "hand.tap" : "hand.tap.fill",
                    tint: HZ.Colors.sub,
                    label: trigger == .tripleTap
                        ? String(localized: "Toucher trois fois")
                        : String(localized: "Toucher deux fois")),
                Row(icon: "bolt.fill", tint: accent,
                    label: trigger.shortcutName,
                    hint: String(localized: "fais défiler jusqu'en bas de la liste"))
            ]
        }
    }

    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 9) {
                        Text(verbatim: "\(i + 1)")
                            .font(HZ.Fonts.fig(12, .bold))
                            .foregroundStyle(i == highlight ? accent : HZ.Colors.faint)
                            .frame(width: 14)
                        SettingsRow(icon: row.icon,
                                    iconTint: row.tint,
                                    label: row.label,
                                    value: row.value,
                                    highlighted: i == highlight,
                                    accent: accent)
                    }
                    if let hint = row.hint {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(hint)
                                .font(HZ.Fonts.fig(12, .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(accent)
                        .padding(.leading, 23)
                    }
                }
            }
        }
        .task(id: trigger) {
            // Le chemin se parcourt tout seul, en boucle : on comprend qu'il
            // s'agit d'une SUITE de lignes, pas d'un écran unique.
            highlight = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_100))
                withAnimation(.easeInOut(duration: 0.35)) {
                    highlight = (highlight + 1) % rows.count
                }
            }
        }
    }
}
