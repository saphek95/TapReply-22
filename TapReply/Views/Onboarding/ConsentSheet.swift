import SwiftUI

/// La feuille de consentement, atteignable depuis l'accueil et les réglages.
///
/// Elle existe parce que « Réparer » relançait l'onboarding entier pour
/// récupérer une case à cocher : l'utilisateur venait de le terminer et se
/// retrouvait renvoyé à l'écran de la mascotte sans comprendre ce qu'on lui
/// redemandait.
///
/// Le contenu reprend mot pour mot l'écran de confidentialité de l'onboarding.
/// Deux formulations différentes pour un même accord, c'est une occasion de se
/// contredire.
struct ConsentSheet: View {
    @Binding var accepted: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = HZTheme.shared

    private var accent: Color { Color(hex: UInt(theme.accentHex)) }

    private var facts: [ConsentFacts.Fact] { ConsentFacts.all }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Ton accord"))
                .font(HZ.Fonts.fig(26, .heavy))
                .foregroundStyle(HZ.Colors.ink)
                .padding(.top, 26)

            Text(String(localized: "Pour écrire tes réponses, TapReply a besoin de lire la conversation affichée. Voilà exactement ce que ça implique."))
                .font(HZ.Fonts.fig(15, .medium))
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 14) {
                ForEach(Array(facts.enumerated()), id: \.offset) { _, f in
                    HStack(alignment: .top, spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: f.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accent)
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
            .padding(.top, 22)

            ConsentFacts.policyLink(accent: accent)
                .padding(.top, 14)

            Spacer(minLength: 24)

            Button {
                accepted = true
                Analytics.track("consent", ["value": "accepted", "where": "sheet"])
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } label: {
                HStack(spacing: 9) {
                    Text(String(localized: "J'accepte l'envoi du texte à l'IA"))
                        .font(HZ.Fonts.fig(17.5, .bold))
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { dismiss() } label: {
                Text(String(localized: "Plus tard"))
                    .font(HZ.Fonts.fig(15.5, .semibold))
                    .foregroundStyle(HZ.Colors.sub)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(HZ.Colors.page.ignoresSafeArea())
        .presentationDetents([.large])
    }
}

/// Le contenu du consentement, UNIQUE pour l'onboarding, la feuille de l'accueil et les Réglages.
/// Guideline 5.1.2(i) : dire clairement quelles données partent, vers quels tiers d'IA, et obtenir un accord explicite.
enum ConsentFacts {
    struct Fact { let icon: String; let title: String; let detail: String }

    static var all: [Fact] {
        [Fact(icon: "photo.badge.checkmark",
              title: String(localized: "Ton écran n'est jamais envoyé"),
              detail: String(localized: "La capture est lue sur ton téléphone. Seul le TEXTE de la conversation visible part : les messages affichés (y compris ceux de ton interlocuteur et son prénom s'il apparaît) et ton brouillon.")),
         Fact(icon: "server.rack",
              title: String(localized: "Il est envoyé à une IA tierce"),
              detail: String(localized: "Le texte passe par notre serveur puis par OpenRouter, qui le transmet à un modèle d'IA de Google (Gemini) ou d'Anthropic (Claude) pour rédiger ta réponse.")),
         Fact(icon: "bolt.horizontal",
              title: String(localized: "TapReply ne le conserve pas"),
              detail: String(localized: "Nous ne stockons ni le texte ni la réponse sur nos serveurs. Les fournisseurs d'IA le traitent en temps réel, sans le conserver ni l'utiliser pour entraîner leurs modèles.")),
         Fact(icon: "hand.raised",
              title: String(localized: "Tu gardes la main"),
              detail: String(localized: "Rien ne part sans ton geste, et c'est toi qui colles et envoies la réponse. Tu peux retirer ton accord à tout moment dans Réglages, Partage avec l'IA."))]
    }

    static func policyLink(accent: Color) -> some View {
        Link(destination: Config.privacyPolicyURL) {
            Label(String(localized: "Lire la politique de confidentialité"), systemImage: "doc.text")
                .font(HZ.Fonts.fig(14, .semibold))
        }
        .foregroundStyle(accent)
    }
}
