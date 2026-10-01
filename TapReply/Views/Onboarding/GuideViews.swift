import SwiftUI

// MARK: - Guide : installer le raccourci (réutilisé dans l'onboarding, Home et Réglages)

/// Si un lien iCloud est configuré (Config.shortcutInstallURL), import en 1 tap
/// comme DoubleTap. Sinon, guide de création manuelle.
struct ShortcutGuideView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        if Config.shortcutInstallURL != nil {
            oneTapInstall
        } else {
            manualGuide
        }
    }

    private var oneTapInstall: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Button {
                if let url = Config.shortcutInstallURL {
                    openURL(url)
                }
            } label: {
                Text(String(localized: "Ajouter le raccourci TapReply"))
                    .font(DS.Fonts.body(17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DS.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous))
            }

            GuideStep(number: 1,
                      title: String(localized: "Appuie sur le bouton ci-dessus"),
                      detail: String(localized: "L'écran iOS du raccourci s'ouvre."))
            GuideStep(number: 2,
                      title: String(localized: "Appuie sur « Ajouter ce raccourci »"),
                      detail: String(localized: "Le raccourci est importé, prêt à l'emploi."))
            GuideStep(number: 3,
                      title: String(localized: "Reviens ici et confirme"),
                      detail: String(localized: "Touche le bouton en bas de cet écran, puis on active le Back Tap."))
        }
    }

    private var manualGuide: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            GuideStep(number: 1,
                      title: String(localized: "Ouvre l'app Raccourcis"),
                      detail: String(localized: "Puis touche + pour créer un nouveau raccourci."))
            GuideStep(number: 2,
                      title: String(localized: "Ajoute l'action « Prendre une capture d'écran »"),
                      detail: String(localized: "Cherche « capture » dans la barre de recherche des actions."))
            GuideStep(number: 3,
                      title: String(localized: "Ajoute l'action « Analyser » de TapReply"),
                      detail: String(localized: "Cherche « TapReply ». La capture d'écran est utilisée automatiquement comme entrée."))
            GuideStep(number: 4,
                      title: String(localized: "Ajoute « Copier dans le presse-papiers »"),
                      detail: String(localized: "Sélectionne la variable « Analyser » (le résultat) comme contenu à copier."))
            GuideStep(number: 5,
                      title: String(localized: "Nomme le raccourci « TapReply »"),
                      detail: String(localized: "Touche la flèche en haut → Renommer."))

            Button {
                if let url = URL(string: "shortcuts://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(String(localized: "Ouvrir Raccourcis"), systemImage: "arrow.up.forward.app")
                    .font(DS.Fonts.body(16, weight: .semibold))
                    .foregroundColor(DS.Colors.primary)
            }
            .padding(.top, DS.Spacing.s)
        }
    }
}

// MARK: - Guide : configurer le Back Tap

struct BackTapGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // Le chemin complet, rejoué en boucle (aucune API iOS ne permet
            // d'ouvrir directement la page Accessibilité).
            BackTapAnimationView()
                .frame(maxWidth: .infinity)

            GuideStep(number: 1,
                      title: String(localized: "Ouvre Réglages"),
                      detail: String(localized: "Puis va dans Accessibilité → Toucher, comme dans l'animation."))
            GuideStep(number: 2,
                      title: String(localized: "Touche « Toucher le dos de l'appareil »"),
                      detail: String(localized: "Tout en bas de la page."))
            GuideStep(number: 3,
                      title: String(localized: "Choisis « Toucher deux fois »"),
                      detail: String(localized: "Puis sélectionne le raccourci « TapReply » dans la liste."))
            GuideStep(number: 4,
                      title: String(localized: "Teste le geste"),
                      detail: String(localized: "Deux taps fermes au dos de l'iPhone, près de la pomme. Retire les coques épaisses si ça ne réagit pas."))

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(String(localized: "Ouvrir Réglages"), systemImage: "gear")
                    .font(DS.Fonts.body(16, weight: .semibold))
                    .foregroundColor(DS.Colors.primary)
            }
            .padding(.top, DS.Spacing.s)
        }
    }
}

// MARK: - Composant étape

struct GuideStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Text("\(number)")
                .font(DS.Fonts.body(15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(DS.Colors.ink)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.Fonts.body(16, weight: .semibold))
                    .foregroundColor(DS.Colors.ink)
                Text(detail)
                    .font(DS.Fonts.body(14))
                    .foregroundColor(DS.Colors.grayText)
            }
        }
    }
}

// MARK: - Sheet réutilisable

struct GuideSheet<Content: View>: View {
    let title: String

    /// Clé UserDefaults que l'UTILISATEUR coche lui-même en confirmant avoir
    /// fait la manipulation.
    ///
    /// Pourquoi déclaratif : iOS n'expose AUCUNE API permettant de savoir si un
    /// raccourci existe dans l'app Raccourcis, ni si le Back Tap est associé à
    /// ce raccourci. La seule source de vérité honnête, c'est la personne
    /// devant l'écran. Avant, l'app affichait donc une erreur perpétuelle même
    /// après une installation réussie : la seule sortie était de replonger dans
    /// l'onboarding. Désormais, on lui demande.
    var confirmKey: String? = nil
    /// Libellé de la confirmation — précisé par l'appelant selon l'étape.
    var confirmLabel: String? = nil

    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(DS.Spacing.l)
                    // Pas de padding bas manuel : safeAreaInset réserve
                    // déjà la hauteur de la barre de confirmation.
            }
            .background(DS.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let key = confirmKey {
                    confirmBar(key: key)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Fermer")) { dismiss() }
                }
            }
        }
    }

    private func confirmBar(key: String) -> some View {
        VStack(spacing: 8) {
            Button {
                UserDefaults.standard.set(true, forKey: key)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            } label: {
                Text(confirmLabel ?? String(localized: "C'est fait"))
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HZ.Colors.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(String(localized: "iOS ne permet pas de le vérifier tout seul : dis-nous quand c'est en place."))
                .font(HZ.Fonts.caption)
                .foregroundStyle(HZ.Colors.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}
