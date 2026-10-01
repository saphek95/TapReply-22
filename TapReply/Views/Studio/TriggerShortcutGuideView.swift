import SwiftUI

/// GUIDE D'INSTALLATION D'UN RACCOURCI SECONDAIRE (Triple Tap, bouton Action).
///
/// Pourquoi un raccourci de plus, alors qu'il en existe déjà un : iOS ne
/// transmet jamais l'origine d'un raccourci. Le Back Tap double, le Back Tap
/// triple et le bouton Action arrivent tous comme une invocation nue. Réutiliser
/// le raccourci du double tap donnerait donc le MÊME ton pour les deux gestes —
/// l'app n'aurait aucun moyen de savoir lequel a été fait. D'où : un raccourci
/// par geste, chacun appelant une action différente de TapReply.
///
/// Cet écran l'explique en une phrase, puis déroule les étapes — import en un
/// tap si le lien iCloud est publié, création manuelle sinon. Il n'apparaît
/// JAMAIS pendant l'onboarding : il se déclenche au moment où quelqu'un assigne
/// un ton à un geste secondaire, et uniquement à ce moment-là.
struct TriggerShortcutGuideView: View {
    let trigger: ToneTrigger
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {

            // Le POURQUOI, avant le comment.
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HZ.Colors.blue)
                Text(String(localized: "iOS ne dit pas à TapReply quel geste tu viens de faire. Chaque geste a donc besoin de son propre raccourci, sinon le \(trigger.label) jouerait le ton du double tap."))
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HZ.Colors.tint,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let url = trigger.installURL {
                oneTapInstall(url)
            } else {
                manualGuide
            }

            HZHairline()

            // ÉTAPE 2 — l'association côté iOS, que nous ne pouvons pas faire
            // à sa place (aucune API n'y donne accès).
            Text(String(localized: "Puis associe-le au geste"))
                .font(HZ.Fonts.headline)
                .foregroundStyle(HZ.Colors.ink)

            Text(trigger.systemSetupPath)
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HZ.Colors.card,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(String(localized: "Choisis « \(trigger.shortcutName) » dans la liste."))
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Label(String(localized: "Ouvrir Réglages"), systemImage: "gear")
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Import en un tap (lien iCloud publié)

    private func oneTapInstall(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Button { openURL(url) } label: {
                Text(String(localized: "Ajouter le raccourci « \(trigger.shortcutName) »"))
                    .font(HZ.Fonts.fig(17, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HZ.Colors.blue,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            GuideStep(number: 1,
                      title: String(localized: "Touche le bouton ci-dessus"),
                      detail: String(localized: "L'écran iOS du raccourci s'ouvre."))
            GuideStep(number: 2,
                      title: String(localized: "Appuie sur « Ajouter ce raccourci »"),
                      detail: String(localized: "Il s'appelle « \(trigger.shortcutName) ». Ne le renomme pas, tu le chercheras sous ce nom."))
        }
    }

    // MARK: - Création manuelle (repli si le lien n'est pas publié)

    private var manualGuide: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            GuideStep(number: 1,
                      title: String(localized: "Ouvre l'app Raccourcis"),
                      detail: String(localized: "Puis touche + pour créer un nouveau raccourci."))
            GuideStep(number: 2,
                      title: String(localized: "Ajoute « Prendre une capture d'écran »"),
                      detail: String(localized: "Cherche « capture » dans la barre de recherche des actions."))
            GuideStep(number: 3,
                      title: String(localized: "Ajoute l'action « \(trigger.intentActionName) »"),
                      detail: String(localized: "Cherche « TapReply » : c'est bien CELLE-LÀ qu'il faut, pas « Analyser » tout court : c'est elle qui identifie le geste."))
            GuideStep(number: 4,
                      title: String(localized: "Ajoute « Copier dans le presse-papiers »"),
                      detail: String(localized: "Sélectionne le résultat de l'action précédente comme contenu à copier."))
            GuideStep(number: 5,
                      title: String(localized: "Nomme-le « \(trigger.shortcutName) »"),
                      detail: String(localized: "Touche la flèche en haut → Renommer."))

            Button {
                if let url = URL(string: "shortcuts://") {
                    openURL(url)
                }
            } label: {
                Label(String(localized: "Ouvrir Raccourcis"), systemImage: "arrow.up.forward.app")
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.blue)
            }
            .buttonStyle(.plain)
        }
    }
}
