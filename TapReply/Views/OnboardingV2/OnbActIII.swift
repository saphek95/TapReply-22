import SwiftUI

// =============================================================================
// ACTE III — FAIRE CONNAISSANCE
// =============================================================================
//
// C'est le premier moment où on DEMANDE quelque chose. Il n'arrive qu'après que
// l'utilisateur ait produit un résultat deux fois : on ne réclame un effort
// qu'à quelqu'un à qui on a déjà rendu service.
//
// DEUX questions, et une règle pour chacune : la réponse doit rendre quelque
// chose IMMÉDIATEMENT. Le prénom s'inscrit sur un badge à son nom, la couleur
// repeint TapTap sous les yeux.
//
// Il y en avait quatre. « Où réponds-tu » et « combien de messages par jour »
// ont été retirés : ils demandaient un effort pour un bénéfice différé, juste
// avant le passage le plus difficile du parcours. Le volume est désormais
// estimé, pas demandé — et ajustable dans les réglages. Une question dont la
// réponse ne change rien à l'écran est un formulaire, et un formulaire placé
// avant l'activation coûte des utilisateurs.
// =============================================================================

// MARK: - 7 · Le prénom

struct OnbName: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @FocusState private var focused: Bool
    @State private var speaks = false
    @ObservedObject private var keyboard = HZKeyboard.shared

    private var trimmed: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// L'initiale du badge. Un point tant qu'on n'a rien tapé : une lettre
    /// inventée par défaut donnerait l'impression que le champ est déjà rempli.
    private var initial: String {
        guard let c = trimmed.first else { return "·" }
        return String(c).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbTypewriter(text: String(localized: "On se tutoie ?\nComment tu t'appelles ?"),
                          font: HZ.Fonts.fig(27, .bold))
                .padding(.top, 12)

            Text(String(localized: "Juste pour que je sache comment t'appeler. Rien ne sort de ton téléphone."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            // Une CARTE DE MEMBRE, pas un champ de formulaire.
            //
            // Tout y est centré — badge, prénom, mention — parce qu'une carte
            // nominative se lit au centre : alignée à gauche, elle redevenait
            // un formulaire avec une pastille décorative devant.
            VStack(spacing: 0) {
                ZStack {
                    // Une lueur derrière le badge, pour que la carte ait de la
                    // profondeur sans qu'on ajoute une image.
                    Circle()
                        .fill(RadialGradient(colors: [draft.accent.opacity(0.22), .clear],
                                             center: .center,
                                             startRadius: 4, endRadius: 66))
                        .frame(width: 132, height: 132)

                    Circle()
                        .fill(draft.accent)
                        .frame(width: 62, height: 62)
                        .overlay(
                            Text(initial)
                                .font(HZ.Fonts.fig(27, .heavy))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: draft.accent.opacity(0.32), radius: 12, y: 5)
                }
                .frame(height: 96)

                TextField("", text: $draft.name, prompt:
                    Text(String(localized: "ton prénom"))
                        .foregroundColor(HZ.Colors.faint))
                    .font(HZ.Fonts.fig(24, .heavy))
                    .foregroundStyle(HZ.Colors.ink)
                    .tint(draft.accent)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit { focused = false }
                    .padding(.horizontal, 20)

                Text(String(localized: "membre depuis aujourd'hui"))
                    .font(HZ.Fonts.fig(12.5, .semibold))
                    .foregroundStyle(HZ.Colors.faint)
                    .padding(.top, 5)
                    .padding(.bottom, 18)

                Rectangle()
                    .fill(HZ.Colors.line)
                    .frame(height: 1)

                // Le pied : la marque, comme sur une vraie carte de membre.
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(draft.accent)
                    Text(verbatim: "TapReply")
                        .font(HZ.Fonts.fig(12.5, .bold))
                        .foregroundStyle(HZ.Colors.sub)
                    Spacer(minLength: 0)
                    Text(String(localized: "carte de membre"))
                        .font(HZ.Fonts.fig(11.5, .semibold))
                        .foregroundStyle(HZ.Colors.faint)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.white, draft.accent.opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(focused ? draft.accent : HZ.Colors.line,
                              lineWidth: focused ? 1.8 : 1))
            .shadow(color: draft.accent.opacity(focused ? 0.18 : 0.07),
                    radius: focused ? 18 : 9, y: 6)
            .padding(.top, 20)

            Spacer(minLength: 12)

            // CLAVIER OUVERT : le bouton se range à DROITE de TapTap, en
            // version compacte. Un bouton pleine largeur sous la mascotte
            // passait sous le clavier, et il fallait replier celui-ci pour
            // valider — deux gestes là où un seul devrait suffire.
            if keyboard.isVisible {
                HStack(alignment: .bottom, spacing: 12) {
                    MascotSlot(size: 74,
                               act: speaks && !trimmed.isEmpty ? .nod : .idle,
                               mouth: .smile)

                    Spacer(minLength: 0)

                    Button {
                        focused = false
                        onNext()
                    } label: {
                        HStack(spacing: 7) {
                            Text(trimmed.isEmpty
                                 ? String(localized: "Passer")
                                 : String(localized: "Enchanté"))
                                .font(HZ.Fonts.fig(16, .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 50)
                        .background(Capsule().fill(draft.accent))
                        .shadow(color: draft.accent.opacity(0.32), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }
            } else {
                // TapTap répète le prénom dès qu'il le connaît : c'est la preuve
                // immédiate que la réponse a servi à quelque chose.
                TapTapAside(text: speaks && !trimmed.isEmpty
                            ? String(localized: "Enchanté, \(trimmed) !")
                            : String(localized: "Moi c'est TapTap. Enfin, tu le sais déjà."),
                            visible: true,
                            act: speaks && !trimmed.isEmpty ? .nod : .idle,
                            mouth: .smile,
                            accent: draft.accent)
                    .padding(.bottom, 18)

                OnbButton(title: trimmed.isEmpty
                          ? String(localized: "Je préfère rester anonyme")
                          : String(localized: "Enchanté"),
                          icon: "arrow.right",
                          fill: draft.accent) {
                    focused = false
                    onNext()
                }
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .animation(.spring(duration: 0.4), value: focused)
        .animation(.spring(duration: 0.4), value: speaks)
        .animation(.easeOut(duration: 0.24), value: keyboard.isVisible)
        .onChange(of: trimmed) { _, new in
            // On ne salue qu'à partir de deux lettres : réagir dès la première
            // donne l'impression d'être épié pendant qu'on tape.
            speaks = new.count >= 2
        }
        .task {
            try? await Task.sleep(for: .milliseconds(560))
            focused = true
        }
    }
}

// MARK: - 8 · La couleur

/// L'écran le plus gratifiant de l'acte : la couleur choisie repeint TapTap
/// SOUS LES YEUX de l'utilisateur, et vaudra pour toute l'application.
///
/// C'est le seul réglage de l'onboarding dont l'effet est instantané et total.
/// On le place ici volontairement : juste après avoir donné son prénom, on
/// reçoit quelque chose en échange.
struct OnbColor: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    /// Une réplique par couleur, dans l'ordre exact de `HZTheme.presets`.
    ///
    /// C'est ce qui transforme une palette en conversation : TapTap a un avis
    /// sur chaque teinte, il n'approuve pas mécaniquement. On essaie les
    /// couleurs pour l'entendre réagir, et l'écran devient un jeu au lieu d'un
    /// sélecteur.
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

    private var remark: String {
        remarks.indices.contains(draft.colorIndex)
        ? remarks[draft.colorIndex]
        : String(localized: "Celle-là me va bien, non ?")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbTypewriter(text: String(localized: "Choisis ma couleur.\nCe sera celle de l'app."),
                          font: HZ.Fonts.fig(27, .bold))
                .padding(.top, 12)

            Spacer(minLength: 10)

            TapTapAside(text: remark,
                        visible: true,
                        act: .nod,
                        mouth: .happy,
                        accent: draft.accent,
                        mascotSize: 118,
                        // Sans machine à écrire : la réplique change à chaque
                        // pastille touchée, et la voir se réécrire lettre par
                        // lettre à chaque essai devient pénible.
                        typing: false)
                .padding(.bottom, 16)
                .id(draft.colorIndex)
                .transition(.opacity)

            // La palette. Les pastilles sont grandes et espacées : on doit
            // pouvoir en essayer plusieurs sans viser.
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 14), count: 5),
                      spacing: 14) {
                ForEach(Array(HZTheme.presets.enumerated()), id: \.offset) { i, hex in
                    let color = Color(hex: UInt(hex))
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(duration: 0.45)) { draft.colorIndex = i }
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(height: 46)
                            .overlay {
                                if draft.colorIndex == i {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                        .padding(4)
                                }
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(color.opacity(draft.colorIndex == i ? 1 : 0),
                                                  lineWidth: 2.5)
                                    .padding(-5)
                            }
                            .shadow(color: color.opacity(draft.colorIndex == i ? 0.45 : 0),
                                    radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 22)

            OnbButton(title: String(localized: "Elle est parfaite"),
                      icon: "arrow.right",
                      fill: draft.accent, action: onNext)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
    }
}

// MARK: - 9 · La confiance (acte IV)

/// L'écran le plus important pour la confiance, et le plus court.
///
/// Il dit trois choses vraies, sans enrobage, et il en dit une qui coûte : la
/// conversation part sur un serveur. Cacher ce point derrière une formule
/// vague est ce qui détruit la confiance quand l'utilisateur le découvre seul.
struct OnbPrivacy: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    /// LE consentement de l'application. Sans lui, aucune réponse ne peut être
    /// générée, et l'accueil affiche un bandeau bloquant.
    ///
    /// Il était écrit par l'ANCIEN onboarding uniquement. Le nouveau ne
    /// l'accordait pas, donc tout utilisateur arrivait dans une application
    /// désactivée après un onboarding qu'il venait de terminer entièrement.
    /// C'est ici, et nulle part ailleurs, que l'accord se donne : cet écran est
    /// le seul qui explique ce à quoi on consent.
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false

    private var facts: [(icon: String, title: String, detail: String)] {
        [("photo.badge.checkmark",
          String(localized: "Ton écran n'est jamais envoyé"),
          String(localized: "La capture est lue sur ton téléphone. C'est le TEXTE seul qui part, jamais l'image.")),
         ("bolt.horizontal",
          String(localized: "Le texte part, puis il est oublié"),
          String(localized: "Il transite le temps d'écrire la réponse. Nous ne le stockons pas.")),
         ("hand.raised",
          String(localized: "Rien ne s'envoie sans toi"),
          String(localized: "La réponse arrive dans ton presse-papiers. C'est toi qui colles et qui envoies."))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbTypewriter(text: String(localized: "Avant d'aller plus loin,\nton accord."),
                          font: HZ.Fonts.fig(27, .bold))
                .padding(.top, 12)

            Text(String(localized: "Pour écrire tes réponses, j'ai besoin de lire la conversation affichée. Voilà exactement ce que ça implique."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 12) {
                ForEach(Array(facts.enumerated()), id: \.offset) { _, f in
                    HStack(alignment: .top, spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(draft.accent.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: f.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(draft.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(f.title)
                                .font(HZ.Fonts.fig(15.5, .bold))
                                .foregroundStyle(HZ.Colors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(f.detail)
                                .font(HZ.Fonts.fig(13.5, .medium))
                                .foregroundStyle(HZ.Colors.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 24)

            Spacer(minLength: 14)

            TapTapAside(text: String(localized: "Je préfère te le dire maintenant que tu le découvres après."),
                        visible: true,
                        act: .idle,
                        mouth: .neutral,
                        accent: draft.accent)
                .padding(.bottom, 16)

            // Le libellé DIT ce qu'on accepte. « On continue » ne serait pas un
            // consentement éclairé : on ne peut pas accorder l'analyse par IA
            // derrière un bouton qui promet seulement de passer à la suite.
            OnbButton(title: String(localized: "J'accepte, on continue"),
                      icon: "checkmark",
                      fill: draft.accent) {
                consentAccepted = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onNext()
            }

            OnbLink(title: String(localized: "Je refuse pour l'instant")) {
                // On avance quand même : refuser ne doit pas enfermer. Le
                // bandeau de l'accueil proposera de revenir sur ce choix.
                consentAccepted = false
                onNext()
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
    }
}
