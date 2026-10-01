import SwiftUI
import UserNotifications

// =============================================================================
// ACTES V ET VI — L'ACTIVATION, PUIS LA RÉCOMPENSE
// =============================================================================
//
// C'est le passage le plus fragile de tout l'onboarding : on demande à
// l'utilisateur de sortir de l'application pour aller dans les Réglages iOS,
// deux fois. Chaque écran qui échoue à être limpide ici coûte un utilisateur.
//
// Trois partis pris :
//
// 1. ON ANNONCE LE COÛT AVANT. Deux étapes, une minute. Quelqu'un qui sait
//    combien ça va prendre accepte ; quelqu'un qui découvre une troisième étape
//    abandonne.
//
// 2. ON REDESSINE LES ÉCRANS SYSTÈME. Une capture d'écran ne se traduit pas,
//    vieillit à chaque version d'iOS, et ne peut pas clignoter pour désigner la
//    bonne ligne. Les lignes de Réglages sont donc redessinées en SwiftUI, et
//    celle qu'il faut toucher respire.
//
// 3. ON NE MENT PAS SUR LA VÉRIFICATION. iOS ne permet pas de savoir si un
//    raccourci existe ni si le Back Tap est réglé. On DEMANDE donc à
//    l'utilisateur de confirmer, au lieu d'afficher une fausse coche verte.
// =============================================================================

// MARK: - 12 · L'annonce

struct OnbSetupIntro: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbTypewriter(text: String(localized: "Il reste deux réglages.\nUne minute, et c'est à toi."),
                          font: HZ.Fonts.fig(27, .bold))
                .padding(.top, 12)

            Text(String(localized: "Ce sont des réglages d'iOS, pas de l'application. Je ne peux pas les faire à ta place, mais je te montre exactement où aller."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 11) {
                stepCard(number: 1,
                         icon: "square.and.arrow.down",
                         title: String(localized: "Ajouter le raccourci"),
                         detail: String(localized: "Un appui. C'est lui qui réveille TapReply."),
                         cost: String(localized: "10 s"))
                stepCard(number: 2,
                         icon: "hand.tap",
                         title: String(localized: "Activer le double tap au dos"),
                         detail: String(localized: "Dans les Réglages d'iOS. Je te guide ligne par ligne."),
                         cost: String(localized: "15 s"))
            }
            .padding(.top, 22)

            Spacer(minLength: 14)

            TapTapAside(text: String(localized: "Après ça, je travaille tout seul. Tu n'ouvriras plus jamais l'app pour répondre."),
                        visible: true,
                        act: .idle,
                        mouth: .smile,
                        accent: draft.accent)
                .padding(.bottom, 16)

            OnbButton(title: String(localized: "On y va"),
                      icon: "arrow.right",
                      fill: draft.accent, action: onNext)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
    }

    private func stepCard(number: Int, icon: String, title: String,
                          detail: String, cost: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle()
                    .fill(draft.accent)
                    .frame(width: 30, height: 30)
                Text(verbatim: "\(number)")
                    .font(HZ.Fonts.fig(14.5, .heavy))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(HZ.Fonts.fig(15.5, .bold))
                        .foregroundStyle(HZ.Colors.ink)
                    Text(cost)
                        .font(HZ.Fonts.fig(11.5, .bold))
                        .foregroundStyle(draft.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(draft.accent.opacity(0.12)))
                }
                Text(detail)
                    .font(HZ.Fonts.fig(13.5, .medium))
                    .foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HZ.Colors.faint)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(HZ.Colors.line, lineWidth: 1))
    }
}

// MARK: - 13 · Le raccourci

struct OnbSetupShortcut: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @AppStorage(SettingsKeys.shortcutConfirmed) private var confirmed = false
    @State private var opened = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbStepBadge(text: String(localized: "ÉTAPE 1 SUR 2"), accent: draft.accent)
                .padding(.top, 8)

            Text(String(localized: "Ajoute le raccourci"))
                .font(HZ.Fonts.fig(27, .bold))
                .foregroundStyle(HZ.Colors.ink)
                .padding(.top, 10)

            Text(String(localized: "Le bouton ouvre l'app Raccourcis. Touche « Ajouter le raccourci », puis reviens ici. Ne le renomme pas."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 12)

            // L'ÉCRAN QU'ON VA VOIR, reconstitué.
            //
            // C'est la vraie icône de l'application, pas un éclair générique :
            // c'est exactement ce qui s'affichera dans l'app Raccourcis, donc
            // c'est ce qu'il faut reconnaître. Et le bouton bleu est dessiné
            // dessous, à sa place, pour que quelqu'un qui n'a jamais ouvert
            // Raccourcis sache où il devra appuyer avant d'y arriver.
            VStack(spacing: 0) {
                VStack(spacing: 11) {
                    Image("IconPreviewViolet")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 78, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: HZ.Colors.ink.opacity(0.16), radius: 12, y: 5)

                    // Le nom vient du modèle, pas d'une chaîne recopiée : c'est
                    // la MÊME source que le mini-onboarding des gestes
                    // secondaires (ToneTrigger.shortcutName). Deux endroits qui
                    // écrivent le nom d'un raccourci à la main finissent par se
                    // contredire, et on envoie alors chercher un raccourci qui
                    // n'existe pas.
                    Text(verbatim: ToneTrigger.doubleTap.shortcutName)
                        .font(HZ.Fonts.fig(16.5, .bold))
                        .foregroundStyle(HZ.Colors.ink)

                    Text(String(localized: "Raccourci"))
                        .font(HZ.Fonts.fig(12.5, .medium))
                        .foregroundStyle(HZ.Colors.faint)
                }
                .padding(.top, 22)
                .padding(.bottom, 18)

                // Le bouton du système, tel qu'il apparaît.
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
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(HZ.Colors.line, lineWidth: 1))
            // TOUTE la carte ouvre l'app Raccourcis, pas seulement le bouton du
            // bas. Quelqu'un qui voit un bouton bleu « Ajouter le raccourci »
            // dessiné au milieu de l'écran va le toucher — c'est exactement ce
            // qu'on lui dit de faire. Qu'il tombe sur une image inerte serait
            // une impasse absurde : les deux chemins mènent au même endroit.
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture { install() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "Ouvrir l'app Raccourcis"))

            Spacer(minLength: 12)

            TapTapAside(text: opened
                        ? String(localized: "Tu l'as ajouté ? Dis-le-moi, iOS ne me le dit pas.")
                        : String(localized: "C'est lui qui me réveille quand tu tapes au dos."),
                        visible: true,
                        act: opened ? .think : .idle,
                        mouth: opened ? .neutral : .smile,
                        accent: draft.accent)
                .padding(.bottom, 16)

            if opened {
                // « C'est ajouté » se lisait comme une affirmation de l'app, pas
                // comme une réponse de l'utilisateur : on ne comprenait pas
                // qu'il fallait le toucher pour confirmer.
                OnbButton(title: String(localized: "Oui, je l'ai ajouté"),
                          icon: "checkmark",
                          fill: draft.accent) {
                    confirmed = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onNext()
                }
                OnbLink(title: String(localized: "Rouvrir l'app Raccourcis")) { install() }
                    .padding(.top, 10)
            } else {
                OnbButton(title: String(localized: "Ouvrir l'app Raccourcis"),
                          icon: "arrow.up.forward",
                          fill: draft.accent) { install() }
                OnbLink(title: String(localized: "Je le ferai plus tard")) { onNext() }
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .animation(.spring(duration: 0.45), value: opened)
    }

    private func install() {
        if let url = Config.shortcutInstallURL { openURL(url) }
        // On n'affirme rien : on note seulement qu'il est SORTI de l'app, ce qui
        // autorise à lui demander de confirmer.
        opened = true
    }
}

// MARK: - 14 · Le double tap au dos

struct OnbSetupBackTap: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @AppStorage(SettingsKeys.backTapConfirmed) private var confirmed = false
    @State private var opened = false
    @State private var highlight = 0

    /// Le chemin exact, tel qu'il apparaît dans les Réglages. Redessiné plutôt
    /// que capturé : une capture ne se traduit pas et ne peut pas clignoter.
    /// Le chemin, avec les deux endroits où il faut FAIRE DÉFILER.
    ///
    /// Ces deux mentions ne sont pas cosmétiques : « Toucher le dos de
    /// l'appareil » est en bas de la page Toucher, et « TapReply » est en bas
    /// d'une longue liste d'actions. Sans le dire, on laisse quelqu'un chercher
    /// une ligne qu'il a sous les yeux mais hors de l'écran, et c'est là qu'on
    /// abandonne un réglage.
    private var path: [(icon: String, tint: Color, label: String, value: String?, hint: String?)] {
        [("accessibility", Color(hex: 0x0A84FF),
          String(localized: "Accessibilité"), nil, nil),
         ("hand.point.up.left.fill", Color(hex: 0x0A84FF),
          String(localized: "Toucher"), nil, nil),
         ("iphone.gen3", HZ.Colors.sub,
          String(localized: "Toucher le dos de l'appareil"), String(localized: "Désactivé"),
          String(localized: "tout en bas de la page")),
         ("hand.tap.fill", HZ.Colors.sub,
          String(localized: "Double toucher"), nil, nil),
         ("bolt.fill", draft.accent,
          String(localized: "TapReply"), nil,
          String(localized: "fais défiler jusqu'en bas de la liste"))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbStepBadge(text: String(localized: "ÉTAPE 2 SUR 2"), accent: draft.accent)
                .padding(.top, 8)

            Text(String(localized: "Active le double tap"))
                .font(HZ.Fonts.fig(27, .bold))
                .foregroundStyle(HZ.Colors.ink)
                .padding(.top, 10)

            Text(String(localized: "Dans les Réglages d'iOS, suis ce chemin. La dernière ligne, c'est TapReply : coche-la."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            // Le chemin, ligne par ligne. Celle en cours respire.
            VStack(spacing: 7) {
                ForEach(Array(path.enumerated()), id: \.offset) { i, row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 9) {
                            Text(verbatim: "\(i + 1)")
                                .font(HZ.Fonts.fig(12, .bold))
                                .foregroundStyle(i == highlight ? draft.accent : HZ.Colors.faint)
                                .frame(width: 14)
                            SettingsRow(icon: row.icon,
                                        iconTint: row.tint,
                                        label: row.label,
                                        value: row.value,
                                        highlighted: i == highlight)
                        }
                        if let hint = row.hint {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                Text(hint)
                                    .font(HZ.Fonts.fig(12, .semibold))
                            }
                            .foregroundStyle(draft.accent)
                            .padding(.leading, 23)
                        }
                    }
                }
            }
            .padding(.top, 18)

            Spacer(minLength: 12)

            TapTapAside(text: opened
                        ? String(localized: "Tu as coché TapReply ? iOS ne me permet pas de le vérifier tout seul.")
                        : String(localized: "Cinq lignes, et on a fini."),
                        visible: true,
                        act: opened ? .think : .idle,
                        mouth: opened ? .neutral : .smile,
                        accent: draft.accent)
                .padding(.bottom, 16)

            if opened {
                OnbButton(title: String(localized: "Oui, TapReply est coché"),
                          icon: "checkmark",
                          fill: draft.accent) {
                    confirmed = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onNext()
                }
                OnbLink(title: String(localized: "Rouvrir les Réglages")) { openSettings() }
                    .padding(.top, 10)
            } else {
                OnbButton(title: String(localized: "Ouvrir les Réglages"),
                          icon: "arrow.up.forward",
                          fill: draft.accent) { openSettings() }
                OnbLink(title: String(localized: "Je le ferai plus tard")) { onNext() }
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .animation(.spring(duration: 0.45), value: opened)
        .task {
            // Le chemin se parcourt tout seul, en boucle : on comprend qu'il
            // s'agit d'une SUITE de lignes, pas d'un écran unique.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_100))
                withAnimation(.easeInOut(duration: 0.35)) {
                    highlight = (highlight + 1) % path.count
                }
            }
        }
    }

    /// La SEULE API publique disponible ouvre la page de TapReply dans les
    /// Réglages. Le chemin ci-dessus montre la suite. Le scheme privé
    /// « App-Prefs: » est un motif de rejet App Store, et iOS l'ignore.
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        opened = true
    }
}

// MARK: - 14bis · « Toujours autoriser »
//
// POURQUOI CET ÉCRAN EXISTE
// Au tout premier double tap, iOS enchaîne deux ou trois demandes
// d'autorisation (le raccourci veut prendre une capture, puis lancer TapReply).
// Chacune propose « Autoriser une fois » ET « Toujours autoriser » — et
// « Autoriser une fois » est le premier bouton, donc celui qu'on touche par
// réflexe. Résultat : iOS redemande à CHAQUE réponse, et le produit perd
// exactement ce qui le rend magique, l'absence de friction.
//
// La consigne existait dans l'ancien onboarding (« iOS va demander 2-3
// autorisations (une seule fois) → Toujours autoriser ») et a disparu avec lui.
// Elle revient ici, à sa place : APRÈS le branchement, AVANT le premier geste.
//
// Même parti pris que les deux écrans précédents : on DESSINE la boîte de
// dialogue qu'on va voir, avec le bon bouton désigné, plutôt que de la décrire.
struct OnbPermissions: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    /// Le bouton à toucher pulse doucement — c'est la seule chose à retenir.
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbStepBadge(text: String(localized: "AVANT TON PREMIER TAP"), accent: draft.accent)
                .padding(.top, 8)

            Text(String(localized: "Réponds « Toujours autoriser »"))
                .font(HZ.Fonts.fig(27, .bold))
                .foregroundStyle(HZ.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Text(String(localized: "À ton premier double tap, iOS va demander deux ou trois autorisations. Choisis « Toujours autoriser » chaque fois."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 12)

            // LA BOÎTE DE DIALOGUE D'iOS, RECONSTITUÉE.
            // Le piège est visuel : « Autoriser une fois » arrive en premier,
            // donc c'est lui qu'on touche sans lire. On montre les deux, et on
            // désigne le bon.
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(HZ.Colors.sub)
                        .padding(.bottom, 2)
                    Text(String(localized: "« Raccourcis » souhaite utiliser TapReply"))
                        .font(HZ.Fonts.fig(15, .semibold))
                        .foregroundStyle(HZ.Colors.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(localized: "Pour lire la capture et écrire ta réponse."))
                        .font(HZ.Fonts.fig(12.5, .medium))
                        .foregroundStyle(HZ.Colors.faint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle().fill(HZ.Colors.line).frame(height: 1)

                // Le mauvais réflexe, en gris.
                Text(String(localized: "Autoriser une fois"))
                    .font(HZ.Fonts.fig(15.5, .regular))
                    .foregroundStyle(HZ.Colors.faint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)

                Rectangle().fill(HZ.Colors.line).frame(height: 1)

                // LE BON, mis en avant et désigné.
                ZStack {
                    Text(String(localized: "Toujours autoriser"))
                        .font(HZ.Fonts.fig(16, .bold))
                        .foregroundStyle(draft.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(draft.accent.opacity(pulse ? 0.16 : 0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .strokeBorder(draft.accent.opacity(pulse ? 0.85 : 0.35), lineWidth: 2)
                        )
                    HStack {
                        Spacer()
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(HZ.Colors.ink.opacity(0.75))
                            .offset(x: 18, y: 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(HZ.Colors.line, lineWidth: 1))

            // LA CONSÉQUENCE, dite franchement : c'est elle qui motive le choix.
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(draft.accent)
                Text(String(localized: "« Autoriser une fois » et iOS te reposera la question à chaque réponse."))
                    .font(HZ.Fonts.fig(13.5, .medium))
                    .foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 14)

            Spacer(minLength: 12)

            TapTapAside(text: String(localized: "C'est la seule étape où je ne peux rien faire à ta place."),
                        visible: true,
                        act: .idle,
                        mouth: .smile,
                        accent: draft.accent)
                .padding(.bottom, 16)

            OnbButton(title: String(localized: "Compris, toujours autoriser"),
                      icon: "checkmark",
                      fill: draft.accent) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onNext()
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .task {
            // Pulsation lente : elle désigne sans clignoter.
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.9)) { pulse.toggle() }
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
    }
}

// MARK: - 15 · Les notifications

struct OnbNotifications: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbTypewriter(text: String(localized: "Je peux te prévenir\nquand ta réponse est prête ?"),
                          font: HZ.Fonts.fig(27, .bold))
                .padding(.top, 12)

            Text(String(localized: "Uniquement quand TU as demandé une réponse. Jamais de promotion, jamais de rappel, jamais rien d'autre."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Spacer(minLength: 12)

            // La notification telle qu'elle arrivera. Montrer l'objet exact
            // qu'on demande d'autoriser vaut mieux que le décrire.
            OnbIsland(phase: .ready,
                      reply: String(localized: "Oui carrément, 18h comme prévu !"),
                      accent: draft.accent,
                      mascotColor: draft.accent)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            TapTapAside(text: String(localized: "Une par réponse. Pas une de plus."),
                        visible: true,
                        act: .idle,
                        mouth: .smile,
                        accent: draft.accent)
                .padding(.bottom, 16)

            OnbButton(title: String(localized: "D'accord, prévenez-moi"),
                      icon: "bell.fill",
                      fill: draft.accent) {
                Task {
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])
                    await MainActor.run { onNext() }
                }
            }
            OnbLink(title: String(localized: "Non merci")) { onNext() }
                .padding(.top, 10)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
    }
}

// MARK: - 16 · La récompense (acte VI)

/// Le seul écran de tout l'onboarding qui ne demande rien.
///
/// Il récapitule ce que l'utilisateur a construit — son prénom, sa couleur, ses
/// heures — et le lui rend sous forme de bilan. C'est aussi le moment où TapTap
/// reprend toute la place : il a été discret pendant l'activation, il revient
/// pour féliciter.
struct OnbReward: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var revealed = false

    private var greeting: String {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty
            ? String(localized: "C'est prêt.")
            : String(localized: "C'est prêt, \(name).")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            Text(greeting)
                .font(HZ.Fonts.fig(31, .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: "Tu n'as plus qu'à taper deux fois au dos de ton téléphone, dans n'importe quelle conversation."))
                .font(HZ.Fonts.fig(15.5, .medium))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.horizontal, 6)

            Spacer(minLength: 10)

            MascotSlot(size: 168, act: .celebrate, mouth: .happy,
                       prop: .sparkles, white: true)

            Spacer(minLength: 10)

            // Le bilan, en trois chiffres. C'est la promesse de l'acte III,
            // rendue à la fin de l'acte VI.
            HStack(spacing: 10) {
                rewardTile(value: "\(draft.hoursPerYear)",
                           label: String(localized: "heures par an"))
                rewardTile(value: "1", label: String(localized: "geste à retenir"))
                rewardTile(value: "0", label: String(localized: "app à ouvrir"))
            }
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)

            Spacer(minLength: 14)

            OnbButton(title: String(localized: "Utiliser TapReply"),
                      icon: "arrow.right",
                      fill: .white.opacity(0.22), action: onNext)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 26)
        .task {
            try? await Task.sleep(for: .milliseconds(620))
            withAnimation(.spring(duration: 0.6)) { revealed = true }
        }
    }

    private func rewardTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(verbatim: value)
                .font(HZ.Fonts.fig(26, .heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(HZ.Fonts.fig(11.5, .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.14)))
    }
}

// MARK: - Le badge d'étape

struct OnbStepBadge: View {
    let text: String
    var accent: Color = HZ.Colors.blue

    var body: some View {
        Text(text)
            .font(HZ.Fonts.fig(11.5, .bold))
            .tracking(1.2)
            .foregroundStyle(accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(accent.opacity(0.12)))
    }
}
