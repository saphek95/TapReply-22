import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity TapReply — « l'île du génie » (refonte Horizon 1.2.0).
///
/// La MASCOTTE de l'utilisateur (sa couleur choisie, AvatarM0…AvatarM8) sort
/// du téléphone quand la réponse est prête — le génie qu'on invoque d'un
/// double tap. La couleur d'ACCENT choisie dans les Réglages voyage dans le
/// ContentState et peint la coche, le liseré de l'île et les accents.
///
/// CE QUI NE CHANGE PAS (règles gravées) :
/// — départ direct en « ready » + alerte, clôture 8 s, aucune trace ;
/// — île étendue : chaque région dans un Link explicite ;
/// — présentations compacte/minimale : UN SEUL widgetURL.
///
/// La pilule NOIRE de l'île est système (non modifiable) — on peint le
/// contenu. La carte d'ÉCRAN VERROUILLÉ, elle, passe en DA claire : carte
/// blanche, texte encre, accents à la couleur de l'app.
struct ReplyLiveActivity: Widget {

    private static let inkLight = Color(hexInt: 0x32333E)      // encre (carte claire)
    private static let subLight = Color(hexInt: 0x676879)      // gris texte secondaire
    private static let softWhite = Color(hexInt: 0xE8E8E8)     // texte sur île noire
    private static let historyURL = URL(string: "tapreply://history")!
    private static let homeURL = URL(string: "tapreply://home")!
    private static let paywallURL = URL(string: "tapreply://paywall")!

    /// Tap sur l'île : réponse prête → Historique ; erreur → Accueil (pour
    /// corriger) ; crédits épuisés → PAYWALL directement.
    private static func destination(_ status: String) -> URL {
        switch status {
        case "error": return homeURL
        case "no_credits": return paywallURL
        default: return historyURL
        }
    }

    /// La couleur d'accent du run (défaut : violet mascotte).
    private static func accent(_ state: ReplyActivityAttributes.ContentState) -> Color {
        Color(hexInt: state.accentHex ?? 0x5B5FE9)
    }

    /// La mascotte à afficher : celle DU TON du run si fournie, sinon
    /// l'avatar de l'utilisateur (défaut : violette).
    private static func mascotAsset(_ state: ReplyActivityAttributes.ContentState) -> String {
        state.mascotAsset ?? "AvatarM\(max(0, min(state.avatarIndex ?? 0, 8)))"
    }

    /// Figtree (déclarée dans l'Info.plist de l'extension) — SF en repli.
    private static func fig(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "Figtree-ExtraBold"
        case .bold:          name = "Figtree-Bold"
        case .semibold:      name = "Figtree-SemiBold"
        case .medium:        name = "Figtree-Medium"
        default:             name = "Figtree-Regular"
        }
        return .custom(name, size: size)
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReplyActivityAttributes.self) { context in
            // ÉCRAN VERROUILLÉ / bannière — DA CLAIRE : carte blanche, encre,
            // accents à la couleur de l'app (en StandBy, iOS étend ce fond).
            LockScreenView(state: context.state, startedAt: context.attributes.startedAt)
                .activityBackgroundTint(.white)
                .activitySystemActionForegroundColor(Self.inkLight)
                .widgetURL(Self.destination(context.state.status))
        } dynamicIsland: { context in
            let dest = Self.destination(context.state.status)
            let accent = Self.accent(context.state)
            let mascot = Self.mascotAsset(context.state)
            return DynamicIsland {
                // ÎLE ÉTENDUE — tout est cliquable via Link
                DynamicIslandExpandedRegion(.leading) {
                    Link(destination: dest) {
                        MascotBadge(asset: mascot, size: 38)
                    }
                    .padding(.leading, 4)
                    .padding(.top, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.toneLabel.isEmpty && context.state.status != "error" {
                        Link(destination: dest) {
                            Text(context.state.toneLabel)
                                .font(Self.fig(11, .medium))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(.trailing, 6)
                        .padding(.top, 2)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Link(destination: dest) {
                        HStack(spacing: 6) {
                            if context.state.status == "ready" {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(accent)
                            }
                            Text(title(context.state.status))
                                .font(Self.fig(14, .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: dest) {
                        if context.state.status == "no_credits" {
                            VStack(spacing: 4) {
                                Text(context.state.reply)
                                    .font(Self.fig(13))
                                    .foregroundColor(Self.softWhite)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                HStack(spacing: 5) {
                                    Image(systemName: "infinity")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(accent)
                                    Text("Touche pour ouvrir TapReply")
                                        .font(Self.fig(12, .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                        } else if context.state.status == "generating" {
                            VStack(alignment: .center, spacing: 7) {
                                Text("Le génie s'active…")
                                    .font(Self.fig(13))
                                    .foregroundColor(.white.opacity(0.65))
                                    .frame(maxWidth: .infinity)
                                ProgressView(timerInterval: context.attributes.startedAt...context.attributes.startedAt.addingTimeInterval(8),
                                             countsDown: false,
                                             label: { EmptyView() },
                                             currentValueLabel: { EmptyView() })
                                    .progressViewStyle(.linear)
                                    .tint(accent)
                                    .scaleEffect(y: 0.6)
                            }
                            .padding(.top, 2)
                        } else if context.state.status == "error" {
                            VStack(spacing: 4) {
                                Text(context.state.reply)
                                    .font(Self.fig(13))
                                    .foregroundColor(Self.softWhite)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.center)
                                Text("Touche pour ouvrir TapReply et corriger")
                                    .font(Self.fig(12, .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                        } else {
                            Text(context.state.reply)
                                .font(Self.fig(14))
                                .foregroundColor(Self.softWhite)
                                .lineLimit(5)
                                .padding(.top, 2)
                        }
                    }
                }
            } compactLeading: {
                // UN SEUL widgetURL pour toute la présentation compacte (ici)
                MascotBadge(asset: mascot, size: 26)
                    .widgetURL(dest)
            } compactTrailing: {
                if context.state.status == "generating" {
                    ProgressView(timerInterval: context.attributes.startedAt...context.attributes.startedAt.addingTimeInterval(8),
                                 countsDown: false,
                                 label: { EmptyView() },
                                 currentValueLabel: { EmptyView() })
                        .progressViewStyle(.circular)
                        .tint(accent)
                        .frame(width: 20, height: 20)
                } else if context.state.status == "ready" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accent)
                } else if context.state.status == "no_credits" {
                    Image(systemName: "infinity.circle.fill")
                        .foregroundColor(accent)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            } minimal: {
                // Le génie en pastille — la coche prend le dessus quand c'est prêt
                if context.state.status == "ready" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accent)
                        .widgetURL(dest)
                } else {
                    MascotBadge(asset: mascot, size: 22)
                        .widgetURL(dest)
                }
            }
            .keylineTint(accent)
        }
    }

    private func title(_ status: String) -> String {
        switch status {
        case "ready": return String(localized: "Réponse prête · copiée")
        case "error": return String(localized: "Oups")
        case "no_credits": return String(localized: "Plus de réponses gratuites")
        default: return "TapReply"
        }
    }
}

// MARK: - Badge mascotte — sticker DÉTOURÉ, aucun fond

/// La mascotte telle quelle : image à fond transparent, affichée en entier.
/// Aucun cadre, aucun disque — elle se pose directement sur l'île.
struct MascotBadge: View {
    let asset: String
    let size: CGFloat
    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Carte d'écran verrouillé — DA CLAIRE (Horizon)

private struct LockScreenView: View {
    let state: ReplyActivityAttributes.ContentState
    let startedAt: Date

    private var accent: Color { Color(hexInt: state.accentHex ?? 0x5B5FE9) }
    private var mascot: String {
        state.mascotAsset ?? "AvatarM\(max(0, min(state.avatarIndex ?? 0, 8)))"
    }

    private func fig(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "Figtree-ExtraBold"
        case .bold:          name = "Figtree-Bold"
        case .semibold:      name = "Figtree-SemiBold"
        case .medium:        name = "Figtree-Medium"
        default:             name = "Figtree-Regular"
        }
        return .custom(name, size: size)
    }

    /// Le libellé de statut, court : c'est un SURTITRE, pas le message.
    private var kicker: String {
        switch state.status {
        case "ready":      return String(localized: "Réponse prête · copiée")
        case "error":      return String(localized: "Oups")
        case "no_credits": return String(localized: "Plus de réponses gratuites")
        default:           return String(localized: "Le génie s'active…")
        }
    }

    // BANNIÈRE ET ÉCRAN VERROUILLÉ — LA MÊME VUE, DEUX USAGES
    //
    // Sur un iPhone SANS Dynamic Island, c'est CETTE vue que le système affiche
    // en bannière quand la mise à jour porte un alertConfiguration. Autrement
    // dit : pour un iPhone 13 ou un SE, c'est le SEUL visuel de TapReply qu'ils
    // verront de leur réponse. Elle était dessinée comme une carte d'écran
    // verrouillé — statut en gros, réponse en petit dessous — alors que le
    // besoin est l'inverse : la RÉPONSE est ce qu'on vient lire.
    //
    // Redessinée en conséquence : filet d'accent à gauche pour la reconnaître
    // d'un coup d'œil, surtitre discret, et la réponse en corps principal.
    // Hauteur contenue (3 lignes) parce qu'une bannière est courte, là où une
    // carte d'écran verrouillé pouvait respirer sur quatre.
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            // Le filet d'accent : à la couleur choisie par l'utilisateur, il
            // identifie TapReply avant même la lecture.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            MascotBadge(asset: mascot, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if state.status == "ready" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(accent)
                    }
                    Text(kicker)
                        .font(fig(11.5, .semibold))
                        .foregroundColor(state.status == "error"
                                         ? Color(hexInt: 0xE2445C)
                                         : Color(hexInt: 0x676879))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if !state.toneLabel.isEmpty && state.status != "error" {
                        Text(state.toneLabel)
                            .font(fig(10.5, .medium))
                            .foregroundColor(Color(hexInt: 0x676879))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(accent.opacity(0.12)))
                    }
                }

                if state.status == "generating" {
                    ProgressView(timerInterval: startedAt...startedAt.addingTimeInterval(8),
                                 countsDown: false,
                                 label: { EmptyView() },
                                 currentValueLabel: { EmptyView() })
                        .progressViewStyle(.linear)
                        .tint(accent)
                        .scaleEffect(y: 0.6)
                        .padding(.top, 4)
                } else {
                    // LA RÉPONSE, en corps principal. C'est elle qu'on vient
                    // lire : elle passe devant le statut, et non l'inverse.
                    Text(state.reply)
                        .font(fig(15, .medium))
                        .foregroundColor(state.status == "error"
                                         ? Color(hexInt: 0xE2445C)
                                         : Color(hexInt: 0x32333E))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Crédits épuisés : l'infini, comme sur l'île — c'est
                // l'argument, pas une simple mention d'erreur.
                if state.status == "no_credits" {
                    HStack(spacing: 5) {
                        Image(systemName: "infinity")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(localized: "Passer Pro"))
                            .font(fig(11.5, .semibold))
                    }
                    .foregroundColor(accent)
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Couleur depuis un hex (l'extension widgets n'a pas les tokens de l'app)

private extension Color {
    init(hexInt: Int) {
        self.init(red: Double((hexInt >> 16) & 0xFF) / 255,
                  green: Double((hexInt >> 8) & 0xFF) / 255,
                  blue: Double(hexInt & 0xFF) / 255)
    }
}
