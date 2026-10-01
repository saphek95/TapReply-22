import SwiftUI
import UIKit

// ============================================================================
// DESIGN SYSTEM TAPREPLY — FICHIER UNIQUE
// ============================================================================
//
// Il n'y a plus qu'UN endroit où vivent les jetons et les composants.
// Deux couches, et une seule fait autorité.
//
// ── COUCHE CANONIQUE : « HORIZON » (HZ.*) ──────────────────────────────────
// C'est LA direction artistique de l'app. Tout écran neuf, toute retouche,
// tout composant nouveau s'écrit en HZ.*. Point.
//
// ── COUCHE HÉRITÉE : « WELLNESS » (DS.*, W*) — GELÉE ──────────────────────
// L'ancienne DA. Elle n'est PAS supprimée, et c'est délibéré : ses valeurs ne
// sont pas les mêmes que celles d'Horizon. DS.Colors.ink est un anthracite
// CHAUD (#3B3937), HZ.Colors.ink est un gris FROID (#32333E) ; DS.Colors.page
// est blanc pur, HZ.Colors.page est un gris clair. Réécrire mécaniquement
// DS.* en HZ.* ne « nettoierait » donc rien : ça changerait l'apparence des
// écrans concernés, sans que personne l'ait demandé.
//
// Règle de travail, sans ambiguïté :
//   • INTERDIT d'introduire un nouvel usage de DS.* ou W*.
//   • Quand on retouche un écran hérité, on le migre ENTIÈREMENT vers HZ.*,
//     et on le regarde sur un appareil : l'aspect va changer, c'est normal,
//     c'est le but. Migration écran par écran, jamais par rechercher-remplacer.
//   • Quand le dernier consommateur d'un jeton hérité disparaît, on supprime
//     le jeton dans la foulée.
//
// Écrans encore sur la couche héritée (15 au 30/08/2026) :
//   RootView · HomeView · HistoryView · PlaygroundView · SettingsView
//   LanguagePickerView · StudioView · ToneDetailView · GuideViews
//   BackTapAnimationView · AppIconPickerSheet · AvatarColorPicker
//   FakeIslandView · TriggerShortcutGuideView · AppSettings
//
// Ce fichier a remplacé Tokens.swift, Components.swift et
// WellnessComponents.swift le 30/08/2026. 36 composants hérités devenus sans
// consommateur ont été supprimés à cette occasion (Card, WCard, WSettingRow,
// WToggle, LogoMark, ConfettiBurst, etc.) : seuls les 4 encore réellement
// utilisés survivent, tout en bas.
// ============================================================================


// ############################################################################
// #  COUCHE CANONIQUE — DA « HORIZON »
// ############################################################################


/// DA « HORIZON » — refonte 1.2.0.
/// Inspiration : grandes néo-banques nordiques (gradient bleu → blanc en tête
/// d'écran, cartes verre dépoli à grands rayons, lignes gris perle, pilules
/// sombres, typographie système SF Pro très contrastée).
///
/// Règles :
/// - Mode clair UNIQUEMENT (inchangé).
/// - SF Pro système partout dans la nouvelle DA (Hanken Grotesk reste chargée
///   pour l'onboarding, non redessiné).
/// - Les 4 onglets (Accueil, Studio, Réglages, Essai) utilisent HZ.
///   L'onboarding continue d'utiliser DS — les deux coexistent.
/// LE CLAVIER, observable. Une barre d'onglets FLOTTANTE n'a rien à faire
/// au-dessus d'un clavier : elle recouvrait le champ de saisie du terrain
/// d'essai, qui devenait inatteignable. La racine s'abonne et l'escamote.
final class HZKeyboard: ObservableObject {
    static let shared = HZKeyboard()
    @Published var isVisible = false

    private init() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                           object: nil, queue: .main) { [weak self] _ in
            self?.isVisible = true
        }
        center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                           object: nil, queue: .main) { [weak self] _ in
            self?.isVisible = false
        }
    }
}

/// THÈME DYNAMIQUE — la couleur primaire de l'app est modifiable depuis les
/// Réglages (nuancier de préréglages). Les vues racines observent cet objet :
/// tout ce qui est « cobalt » se repeint instantanément.
final class HZTheme: ObservableObject {
    static let shared = HZTheme()
    /// Nuancier des Réglages — couleurs classiques variées, DÉFAUT = le
    /// violet de la mascotte. L'ORDRE est contractuel : il correspond aux
    /// assets AvatarM0…AvatarM8 (variantes de couleur de la mascotte).
    static let presets: [Int] = [
        0x5B5FE9, // violet mascotte (défaut)
        0x0073EA, // bleu
        0x66CCFF, // ciel
        0x00C875, // vert
        0xFFCB00, // jaune
        0xFDAB3D, // orange
        0xE2445C, // corail
        0xFF7BAC, // rose
        0x32333E, // encre
    ]
    static let defaultAccent = 0x5B5FE9
    @Published var accentHex: Int {
        didSet { UserDefaults.standard.set(accentHex, forKey: "accentColorHex") }
    }
    /// La couleur de TAPTAP (index dans `presets`) — indépendante de celle de l'app depuis le 25/09 : l'onboarding
    /// applique la même aux deux, les Réglages permettent de les dépareiller. Stockée sous la clé historique
    /// `avatarColorIndex` (lue aussi par la Live Activity, la notification, la carte de partage).
    @Published var mascotIndex: Int {
        didSet { UserDefaults.standard.set(mascotIndex, forKey: "avatarColorIndex") }
    }
    var mascotHex: Int { Self.presets[max(0, min(mascotIndex, Self.presets.count - 1))] }
    private init() {
        let stored = UserDefaults.standard.integer(forKey: "accentColorHex")
        accentHex = stored == 0 ? Self.defaultAccent : stored
        mascotIndex = UserDefaults.standard.integer(forKey: "avatarColorIndex")
    }
}

enum HZ {

    // MARK: - Couleurs — langage « board » (réf. monday.com iOS)
    enum Colors {
        /// CANEVAS de page : gris-lavande très clair. Les cartes sont
        /// BLANCHES et posées dessus, sans bordure — c'est lui qui les révèle.
        static let page       = Color(hex: 0xF0F1F6)
        /// Fond des sheets (toujours blanc, comme les modales monday)
        static let sheet      = Color.white
        /// Texte principal — encre douce (pas de noir pur)
        static let ink        = Color(hex: 0x32333E)
        /// Texte secondaire
        static let sub        = Color(hex: 0x676879)
        /// Texte tertiaire / placeholders
        static let faint      = Color(hex: 0x9BA0AC)
        /// Surface posée SUR une carte blanche (champs, chips au repos)
        static let card       = Color(hex: 0xF5F6F8)
        /// Surface secondaire un cran plus marquée
        static let cardDeep   = Color(hex: 0xECEDF3)
        /// Hairline
        static let line       = Color(hex: 0xE6E9EF)
        /// Pointillés des emplacements vides
        static let dash       = Color(hex: 0xC9CBD9)
        // ---- Couleur primaire DYNAMIQUE (Réglages → Couleur de l'app) ----
        // ⚠️ Color(hex:) attend un UInt (Tokens.swift) → conversion explicite.
        /// La primaire (CTA, liens, sélection, bulle Essai, grand container)
        static var blue: Color { Color(hex: UInt(HZTheme.shared.accentHex)) }
        /// Primaire assombrie (états pressés, bas de dégradé, texte teinté)
        static var blueDeep: Color { Color(hex: UInt(scale(HZTheme.shared.accentHex, 0.74))) }
        /// Remplissage teinté très clair dérivé de la primaire (chips, boutons doux)
        static var tint: Color { Color(hex: UInt(towardWhite(HZTheme.shared.accentHex, 0.88))) }
        /// Primaire éclaircie (haut du dégradé de la bulle Essai)
        static var blueLight: Color { Color(hex: UInt(towardWhite(HZTheme.shared.accentHex, 0.22))) }

        /// hex × facteur (assombrir)
        static func scale(_ hex: Int, _ f: Double) -> Int {
            let r = Int(Double((hex >> 16) & 0xFF) * f)
            let g = Int(Double((hex >> 8) & 0xFF) * f)
            let b = Int(Double(hex & 0xFF) * f)
            return (min(r, 255) << 16) | (min(g, 255) << 8) | min(b, 255)
        }
        /// mélange vers le blanc (t = proportion de blanc)
        static func towardWhite(_ hex: Int, _ t: Double) -> Int {
            let r = Int(Double((hex >> 16) & 0xFF) * (1 - t) + 255 * t)
            let g = Int(Double((hex >> 8) & 0xFF) * (1 - t) + 255 * t)
            let b = Int(Double(hex & 0xFF) * (1 - t) + 255 * t)
            return (min(r, 255) << 16) | (min(g, 255) << 8) | min(b, 255)
        }
        /// Pilule sombre (réservée aux rares contrastes forts)
        static let pillDark   = Color(hex: 0x111114)
        /// Or « Pro » — le traitement premium (badge, couronne, marqueur)
        static let gold       = Color(hex: 0xE8A317)
        static let goldDeep   = Color(hex: 0xC77E00)
        /// LA PALETTE DE STATUTS — la joie signature des boards
        static let mGreen     = Color(hex: 0x00C875)
        static let mYellow    = Color(hex: 0xFFCB00)
        static let mOrange    = Color(hex: 0xFDAB3D)
        static let mRed       = Color(hex: 0xE2445C)
        static let mSky       = Color(hex: 0x66CCFF)
        static let mPurple    = Color(hex: 0xA25DDC)
        /// Vert accompli (textes de succès)
        static let green      = Color(hex: 0x00A25B)
        /// Rouge destructif / alerte bloquante
        static let alarm      = Color(hex: 0xE2445C)

        // ── LA MASCOTTE (TapTap) ──────────────────────────────────────────
        // Teintes relevées au pixel sur l'asset officiel AvatarM0.png. Le dôme
        // et les bras, eux, prennent la couleur CHOISIE par l'utilisateur —
        // ils ne sont donc pas ici.
        /// Corps bas
        static let mascotCream     = Color(hex: 0xFCF6EA)
        /// Pieds et ombre interne du corps
        static let mascotCreamDeep = Color(hex: 0xE8DBD6)
        /// Yeux et contour de bouche
        static let mascotInk       = Color(hex: 0x2F2855)
        /// Joues et langue
        static let mascotCoral     = Color(hex: 0xF7757E)
        /// Ombre portée au sol
        static let shadowSoft      = Color(hex: 0xEDEBF7)
    }

    // MARK: - Typographie : FIGTREE (la fonte open source de monday.com)
    // Embarquée en 5 graisses (Info.plist). Font.custom retombe sur SF Pro
    // si la fonte manquait — l'app ne casse jamais.
    enum Fonts {
        /// Résolution graisse → fichier Figtree
        static func fig(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
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

        /// 34 · extrabold — chiffre héros des cartes de stats
        static var hero: Font      { fig(34, .heavy) }
        /// 28 · bold — titre d'écran
        static var title: Font     { fig(28, .bold) }
        /// 22 · bold — titre de section (« Historique », « Vos tons favoris »)
        static var section: Font   { fig(22, .bold) }
        /// 17 · semibold — libellés forts, titres de lignes
        static var headline: Font  { fig(17, .semibold) }
        /// 16 · regular — corps
        static var body: Font      { fig(16, .regular) }
        /// 15 · semibold — boutons compacts, liens
        static var strong: Font    { fig(15, .semibold) }
        /// 14 · regular — sous-titres, méta
        static var sub: Font       { fig(14, .regular) }
        /// 12.5 · regular — légendes
        static var caption: Font   { fig(12.5, .regular) }
        /// 12 · semibold, à utiliser avec .kerning(0.8) + .textCase(.uppercase)
        static var kicker: Font    { fig(12, .semibold) }
    }

    // MARK: - Rayons
    enum Radius {
        static let hero: CGFloat   = 32   // grands containers (palmarès, historique)
        static let card: CGFloat   = 28   // grandes cartes
        static let row: CGFloat    = 20   // lignes d'historique, petites cartes
        static let tile: CGFloat   = 16   // vignettes de tons
        static let field: CGFloat  = 16   // champs de saisie
        static let full: CGFloat   = 999
    }

    // MARK: - Espacement
    enum Spacing {
        static let gutter: CGFloat = 20
        /// Hauteur réservée au-dessus de la barre flottante — généreuse pour
        /// qu'aucun contenu tapable ne frôle la barre (les doigts rippaient).
        static let tabBarClearance: CGFloat = 118
    }

    // MARK: - Gradients
    enum Gradients {
        /// Or « Pro » — badge premium, couronne
        static var gold: LinearGradient {
            LinearGradient(colors: [Color(hex: 0xF3B33C), Color(hex: 0xD98A0F)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        /// Pastille / logo Essai — dérivé de la couleur primaire dynamique
        static var spark: LinearGradient {
            LinearGradient(colors: [Colors.blueLight, Colors.blueDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Ombres

extension View {
    /// Ombre flottante des grandes cartes et de la barre de navigation.
    func hzFloating() -> some View {
        shadow(color: HZ.Colors.ink.opacity(0.10), radius: 18, y: 10)
    }
    /// Ombre discrète des lignes et vignettes — quasi plate, façon board.
    func hzSoft() -> some View {
        shadow(color: HZ.Colors.ink.opacity(0.05), radius: 7, y: 2)
    }
}

// MARK: - Surfaces

/// Carte blanche posée (lignes de liste, cartes de contenu).
struct HZCard: ViewModifier {
    var fill: Color = .white
    var radius: CGFloat = HZ.Radius.row
    var bordered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(HZ.Colors.line, lineWidth: 1)
                }
            }
    }
}

extension View {
    func hzCard(fill: Color = .white,
                radius: CGFloat = HZ.Radius.row,
                bordered: Bool = false) -> some View {
        modifier(HZCard(fill: fill, radius: radius, bordered: bordered))
    }
    /// Carte de VERRE — posée sur le gradient d'en-tête (stats de l'Accueil).
    /// Blanc translucide + voile dégradé, comme du verre dépoli au soleil.
    func hzGlass(radius: CGFloat = HZ.Radius.card) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.white.opacity(0.42))
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.65), lineWidth: 1)
                )
        )
        .hzFloating()
    }
}

// MARK: - Boutons

/// CTA principal — pilule encre, texte blanc (registre « Upgrade » sombre).
struct HZPrimaryButton: View {
    let title: String
    var systemIcon: String? = nil
    var enabled: Bool = true
    var fill: Color = HZ.Colors.blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon).font(.system(size: 16, weight: .semibold))
                }
                Text(title).font(HZ.Fonts.fig(17, .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(enabled ? fill : HZ.Colors.faint, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Bouton secondaire — pilule gris perle, texte encre.
struct HZSecondaryButton: View {
    let title: String
    var systemIcon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon).font(.system(size: 16, weight: .semibold))
                }
                Text(title).font(HZ.Fonts.fig(17, .semibold))
            }
            .foregroundStyle(enabled ? HZ.Colors.ink : HZ.Colors.faint)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(HZ.Colors.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Lien de section (« Voir tout ») — bleu, sans chrome.
struct HZLink: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HZ.Fonts.strong)
                .foregroundStyle(HZ.Colors.blue)
        }
        .buttonStyle(.plain)
    }
}

/// Bouton rond de fermeture des sheets (gris perle, croix encre).
struct HZCloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HZ.Colors.ink)
                .frame(width: 34, height: 34)
                .background(HZ.Colors.card, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Petits composants

/// Pilule horaire des lignes d'historique — DISCRÈTE (gris doux, jamais de
/// fond sombre : les « points noirs » fatiguaient l'œil sur l'Accueil).
struct HZTimePill: View {
    let text: String
    var systemIcon: String = "clock"
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemIcon).font(.system(size: 9, weight: .semibold))
            Text(text).font(HZ.Fonts.fig(11.5, .medium))
        }
        .foregroundStyle(HZ.Colors.sub)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(HZ.Colors.card, in: Capsule())
    }
}

/// Chip de filtre (barre horizontale de l'Historique).
struct HZFilterChip: View {
    let label: String
    var emoji: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji { Text(emoji).font(HZ.Fonts.fig(13)) }
                Text(label).font(HZ.Fonts.fig(14.5, .semibold))
            }
            .foregroundStyle(selected ? HZ.Colors.blueDeep : HZ.Colors.sub)
            .padding(.horizontal, 15)
            .frame(height: 36)
            .background(selected ? HZ.Colors.tint : .white, in: Capsule())
            .overlay {
                Capsule().strokeBorder(selected ? HZ.Colors.blue : HZ.Colors.line,
                                       lineWidth: selected ? 1.6 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Titre de section avec action optionnelle à droite.
struct HZSectionHeader: View {
    let title: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(HZ.Fonts.section)
                .foregroundStyle(HZ.Colors.ink)
            Spacer()
            if let actionLabel, let action {
                HZLink(title: actionLabel, action: action)
            }
        }
    }
}

/// Kicker en capitales (« VOTRE ACTIVITÉ »).
struct HZKicker: View {
    let text: String
    var color: Color = HZ.Colors.sub
    var body: some View {
        Text(text)
            .font(HZ.Fonts.kicker)
            .kerning(0.9)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// Ligne de réglage HORIZON — icône, titre, sous-titre, accessoire.
struct HZRow<Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemIcon: String? = nil
    var titleColor: Color = HZ.Colors.ink
    @ViewBuilder var accessory: () -> Accessory
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 14) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(titleColor)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HZ.Fonts.headline)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            accessory()
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Chevron discret des lignes.
struct HZChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(HZ.Colors.faint)
    }
}

/// Hairline pleine largeur.
struct HZHairline: View {
    var body: some View {
        Rectangle().fill(HZ.Colors.line).frame(height: 1)
    }
}

/// Marqueur de fin de liste (« Tu as tout vu »).
struct HZEndMarker: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(HZ.Fonts.strong)
                .foregroundStyle(HZ.Colors.ink)
            Text(subtitle)
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

// MARK: - Bulles de chat (fiche de ton, mode test)

struct HZChatBubble: View {
    enum Kind { case incoming, outgoing }
    let text: String
    let kind: Kind

    var body: some View {
        HStack {
            if kind == .outgoing { Spacer(minLength: 48) }
            Text(text)
                .font(HZ.Fonts.body)
                .foregroundStyle(kind == .outgoing ? .white : HZ.Colors.ink)
                // ⚠️ SANS fixedSize, SwiftUI tronque le texte dans un
                // ScrollView (bug constaté : réponses coupées en plein mot).
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(
                    kind == .outgoing ? HZ.Colors.blue : HZ.Colors.card,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: kind == .outgoing ? 20 : 6,
                        bottomTrailingRadius: kind == .outgoing ? 6 : 20,
                        topTrailingRadius: 20,
                        style: .continuous)
                )
            if kind == .incoming { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Composants « board » (réf. monday)

/// Tuile d'icône colorée : carré arrondi plein, glyphe blanc — la façon
/// monday de poser une icône (jamais de glyphe gris flottant).
struct HZIconTile: View {
    let color: Color
    let icon: String
    var size: CGFloat = 44
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// Bouton doux « lavande » : remplissage teinté + libellé cobalt
/// (le « Preview template » de monday).
struct HZTintButton: View {
    let title: String
    var systemIcon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(HZ.Fonts.fig(17, .semibold))
            }
            .foregroundStyle(HZ.Colors.blueDeep)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(HZ.Colors.tint, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Le motif « mini-board » : trois lignes de board avec leurs pastilles de
/// statut vert / jaune / rouge — le clin d'œil signature.
struct HZBoardMotif: View {
    var width: CGFloat = 46
    var body: some View {
        VStack(alignment: .leading, spacing: width * 0.13) {
            row(status: HZ.Colors.mGreen)
            row(status: HZ.Colors.mYellow)
            row(status: HZ.Colors.mRed)
        }
        .frame(width: width)
    }
    private func row(status: Color) -> some View {
        HStack(spacing: width * 0.1) {
            Capsule().fill(HZ.Colors.cardDeep)
                .frame(width: width * 0.52, height: width * 0.16)
            Capsule().fill(status)
                .frame(width: width * 0.38, height: width * 0.16)
        }
    }
}

/// Cercle-flèche « voir tout » (les ronds fléchés des containers monday).
struct HZArrowButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HZ.Colors.ink)
                .frame(width: 36, height: 36)
                .background(HZ.Colors.card, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trait de marqueur « à main levée »

/// Soulignement or tracé à la main : une ondulation irrégulière en deux
/// passages de crayon — LA signature décalée de la DA (avec la couronne
/// et l'infini). À poser sous un titre.
struct HZScribble: View {
    var width: CGFloat = 104
    var color: Color = HZ.Colors.gold
    var body: some View {
        ZStack {
            ScribbleStroke()
                .stroke(color, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            ScribbleStroke()
                .stroke(color.opacity(0.38), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .offset(x: 2.5, y: 2)
                .rotationEffect(.degrees(0.8))
        }
        .frame(width: width, height: 8)
    }
}

struct ScribbleStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, midY = rect.midY
        p.move(to: CGPoint(x: 0, y: midY + 1))
        p.addQuadCurve(to: CGPoint(x: w * 0.34, y: midY - 1.5),
                       control: CGPoint(x: w * 0.16, y: midY - 3.5))
        p.addQuadCurve(to: CGPoint(x: w * 0.68, y: midY + 1.5),
                       control: CGPoint(x: w * 0.52, y: midY + 3.5))
        p.addQuadCurve(to: CGPoint(x: w, y: midY - 1),
                       control: CGPoint(x: w * 0.86, y: midY - 3))
        return p
    }
}

// MARK: - Traitement « Pro » (badge doré + couronne à main levée)

/// Badge premium « fait main » : pilule blanche, INFINI tracé au trait or
/// (même langage que la couronne), « Illimité » en encre, double contour or
/// légèrement décalé comme deux passages de crayon — et la petite couronne
/// posée de travers sur le coin. Atypique, précieux, zéro aplat criard.
struct HZProBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            HZInfinityMark(width: 24)
            Text(String(localized: "Illimité"))
                .font(HZ.Fonts.fig(14.5, .bold))
                .foregroundStyle(HZ.Colors.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .fixedSize()
        .padding(.horizontal, 15)
        .frame(height: 40)
        .background(.white, in: Capsule())
        // Deux passages de « crayon » or, imparfaitement superposés
        .overlay(Capsule().strokeBorder(HZ.Colors.gold, lineWidth: 1.5))
        .overlay(
            Capsule()
                .strokeBorder(HZ.Colors.gold.opacity(0.4), lineWidth: 1.2)
                .rotationEffect(.degrees(1.4))
                .scaleEffect(x: 1.015, y: 1.08)
        )
        // La couronne perchée sur le coin, comme posée à la main. Elle doit
        // CHEVAUCHER le liseré de la pilule : à y = -8 elle flottait détachée
        // au-dessus, comme un élément orphelin.
        .overlay(alignment: .topTrailing) {
            // Couronne de 13 pt → 10,7 pt de haut. À y = -3 elle ne dépasse
            // que de 3 pt : les 7,7 pt restants reposent DANS la pilule, sur
            // son liseré or. Et x = -1 la ramène à l'intérieur du bord droit
            // arrondi — à x = +3 elle débordait dans le vide, à droite de la
            // capsule, et se lisait comme un élément orphelin.
            HZCrownMark(size: 13)
                .offset(x: -1, y: -3)
        }
        .hzSoft()
    }
}

/// Le symbole infini tracé « à la main » : lemniscate au trait or, bouts
/// ronds, légèrement incliné — le jumeau de la couronne.
struct HZInfinityMark: View {
    var width: CGFloat = 24
    var body: some View {
        InfinityOutline()
            .stroke(HZ.Colors.gold,
                    style: StrokeStyle(lineWidth: max(1.8, width * 0.09),
                                       lineCap: .round, lineJoin: .round))
            .frame(width: width, height: width * 0.46)
            .rotationEffect(.degrees(-4))
    }
}

struct InfinityOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let n = 72
        var first = true
        for i in 0...n {
            let t = Double(i) / Double(n) * 2 * .pi
            let d = 1 + sin(t) * sin(t)
            // Lemniscate de Bernoulli, normalisée : x ∈ [-1,1], y ∈ [-0.354, 0.354]
            let x = cos(t) / d
            let y = sin(t) * cos(t) / d
            let pt = CGPoint(x: rect.midX + CGFloat(x) * rect.width / 2,
                             y: rect.midY + CGFloat(y / 0.354) * rect.height / 2)
            if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Couronne stylisée « dessinée à la main » : uniquement le CONTOUR, or,
/// traits arrondis légèrement irréguliers — l'intérieur reste vide.
struct HZCrownMark: View {
    var size: CGFloat = 16
    var body: some View {
        CrownOutline()
            .stroke(HZ.Colors.gold,
                    style: StrokeStyle(lineWidth: max(1.6, size * 0.11),
                                       lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size * 0.82)
            .rotationEffect(.degrees(-6)) // le petit air posé de travers, fait main
    }
}

struct CrownOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Base légèrement incurvée
        p.move(to: CGPoint(x: 0.10 * w, y: 0.92 * h))
        p.addQuadCurve(to: CGPoint(x: 0.90 * w, y: 0.90 * h),
                       control: CGPoint(x: 0.50 * w, y: 0.99 * h))
        // Flanc droit → pointe droite
        p.addLine(to: CGPoint(x: 0.97 * w, y: 0.22 * h))
        // Creux droit (courbes douces = coup de crayon)
        p.addQuadCurve(to: CGPoint(x: 0.66 * w, y: 0.46 * h),
                       control: CGPoint(x: 0.80 * w, y: 0.52 * h))
        // Pointe centrale
        p.addQuadCurve(to: CGPoint(x: 0.50 * w, y: 0.06 * h),
                       control: CGPoint(x: 0.56 * w, y: 0.18 * h))
        p.addQuadCurve(to: CGPoint(x: 0.34 * w, y: 0.46 * h),
                       control: CGPoint(x: 0.44 * w, y: 0.18 * h))
        // Creux gauche → pointe gauche
        p.addQuadCurve(to: CGPoint(x: 0.03 * w, y: 0.24 * h),
                       control: CGPoint(x: 0.20 * w, y: 0.52 * h))
        p.closeSubpath()
        return p
    }
}

/// Cadenas or tracé « à la main » : anse en arc + corps arrondi, contour
/// seul, légèrement incliné — le jumeau de la couronne, pour marquer ce qui
/// est réservé aux abonnés.
struct HZLockMark: View {
    var size: CGFloat = 16
    var color: Color = HZ.Colors.gold
    var body: some View {
        LockOutline()
            .stroke(color, style: StrokeStyle(lineWidth: max(1.5, size * 0.10),
                                             lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.78, height: size)
            .rotationEffect(.degrees(-5)) // posé de travers, fait main
    }
}

struct LockOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Anse : arc ouvert vers le bas
        p.move(to: CGPoint(x: 0.22 * w, y: 0.46 * h))
        p.addLine(to: CGPoint(x: 0.22 * w, y: 0.30 * h))
        p.addQuadCurve(to: CGPoint(x: 0.78 * w, y: 0.30 * h),
                       control: CGPoint(x: 0.50 * w, y: -0.08 * h))
        p.addLine(to: CGPoint(x: 0.78 * w, y: 0.46 * h))
        // Corps : rectangle arrondi dessiné à la main
        p.move(to: CGPoint(x: 0.10 * w, y: 0.52 * h))
        p.addQuadCurve(to: CGPoint(x: 0.90 * w, y: 0.52 * h),
                       control: CGPoint(x: 0.50 * w, y: 0.46 * h))
        p.addLine(to: CGPoint(x: 0.90 * w, y: 0.92 * h))
        p.addQuadCurve(to: CGPoint(x: 0.10 * w, y: 0.92 * h),
                       control: CGPoint(x: 0.50 * w, y: 1.0 * h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Logo « Essai » (bulle de droite de la barre de navigation)

/// Éclair d'essai : le logo deux-bulles TapReply en blanc sur disque dégradé.
struct HZSparkBadge: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            Circle().fill(HZ.Gradients.spark)
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

extension Color {
    /// Une version nettement plus profonde de la couleur, pour poser un fond
    /// derrière un élément de la MÊME famille chromatique sans qu'il s'y noie.
    ///
    /// L'écart est volontairement large (assombrissement d'environ 40 % et
    /// saturation poussée) : un simple `opacity` ou dix pour cent de
    /// luminosité en moins laisse les deux teintes se confondre dès que
    /// l'affichage baisse en luminosité.
    /// Une version très claire et très désaturée de la couleur, pour poser un
    /// fond derrière un élément de la MÊME famille chromatique.
    ///
    /// Le contraste vient de la SATURATION, pas de la luminosité : le fond
    /// tombe à un quart de saturation tandis que l'élément garde la sienne à
    /// plein. C'est ce qui permet d'accueillir sur une teinte de marque sans que
    /// le personnage s'y dissolve, et sans assombrir l'écran.
    func lightened() -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &sat, brightness: &b, alpha: &a) else { return self }
        return Color(hue: h,
                     saturation: max(sat * 0.26, 0.10),
                     brightness: min(b * 1.34, 0.99),
                     opacity: a)
    }

    func deepened() -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &sat, brightness: &b, alpha: &a) else { return self }
        return Color(hue: h,
                     saturation: min(sat * 1.12, 1),
                     brightness: max(b * 0.58, 0.14),
                     opacity: a)
    }
}


// ############################################################################
// #  COUCHE HÉRITÉE — DA « WELLNESS » · GELÉE, NE PAS ÉTENDRE
// #
// #  Ne subsiste ici que ce qui a encore un consommateur vivant :
// #  les jetons DS.*, l'initialiseur Color(hex:), les modificateurs de bord,
// #  et 4 composants (ToastView, WPrimaryButton, AvatarPalette, WToneArt)
// #  plus les 2 formes dont WToneArt dépend.
// ############################################################################


// ── (ex-Tokens.swift) ─────────────────────────────────────────────────

/// Design tokens — DA « Wellness Chaleureux ».
/// Mode clair uniquement. La page est BLANCHE, les cartes sont CRÈME.
/// L'encre est un anthracite CHAUD (#3B3937) — jamais du noir.
enum DS {

    // MARK: - Couleurs : neutres
    enum Colors {
        static let page          = Color(hex: 0xFFFFFF)  // fond de TOUS les écrans
        static let surface       = Color(hex: 0xF9F5F2)  // cartes, champs, vignettes
        static let surfaceWarm   = Color(hex: 0xFEF7F7)  // variante rosée
        static let ink           = Color(hex: 0x3B3937)  // TOUT le texte, icônes actives
        static let iconInactive  = Color(hex: 0xAAA6A0)  // tab bar inactive
        static let divider       = Color(hex: 0xE8E8E6)  // hairline 1 pt
        static let disabledFill  = Color(hex: 0xE9E7E6)
        static let radioOff      = Color(hex: 0xECE8E5)
        static let trackOff      = Color(hex: 0xD7D5D3)  // piste de toggle éteint
        static let cardEdge      = Color(hex: 0xD3D3D1)  // ARÊTE BASSE des cartes
        static let dotInactive   = Color(hex: 0xC1BDBA)
        static let dash          = Color(hex: 0xE1DEDA)  // pointillé de timeline
        static let ring          = Color(hex: 0x959595)  // anneau « à venir »

        // MARK: Marque — orange (identité, énergie, « maintenant »)
        static let orangeDeep    = Color(hex: 0xFE6700)
        static let orange        = Color(hex: 0xFF7E1D)
        static let orangeMid     = Color(hex: 0xEE7B30)
        static let orangeWarm    = Color(hex: 0xF19E36)
        static let orangeLight   = Color(hex: 0xFFA541)

        // MARK: Marque — jaune (joie, récompense)
        static let yellow        = Color(hex: 0xFECE00)
        static let yellowDeep    = Color(hex: 0xFDD201)
        static let yellowBrand   = Color(hex: 0xFEB800)

        // MARK: Marque — bleu (ACTION : tous les CTA)
        static let blue          = Color(hex: 0x0C70FB)
        /// Lavis bleu très clair — surfaces d'accent sobres (carte abonnement…)
        static let blueWash      = Color(hex: 0xEAF2FE)
        static let blueSession   = Color(hex: 0x316DF1)
        static let blueDeep      = Color(hex: 0x1940E2)
        static let blueSky       = Color(hex: 0x2BABFF)

        // MARK: Marque — vert (ACCOMPLI)
        static let green         = Color(hex: 0x048840)
        static let greenBright   = Color(hex: 0x01A452)
        static let greenSoft     = Color(hex: 0x49A25B)
        static let greenScene    = Color(hex: 0x1E8A4B)

        // MARK: Marque — secondaires
        static let purple        = Color(hex: 0x9567BF)
        static let pink          = Color(hex: 0xFEACD6)

        // MARK: Pastels d'illustration (JAMAIS en surface d'interface)
        static let illusLilac    = Color(hex: 0xD6C6FF)
        static let illusSky      = Color(hex: 0xC8E7FA)
        static let illusPink     = Color(hex: 0xFEDEEB)
        static let illusPeach    = Color(hex: 0xFFC9A6)
        static let tileBlue      = Color(hex: 0x9FC7E9)
        static let tileGreen     = Color(hex: 0xA5F1A3)
        static let tilePeach     = Color(hex: 0xFDB691)

        /// ÉCART ASSUMÉ à la charte : la DA d'origine n'a pas de rouge.
        /// Rouge d'alarme réservé À L'UNIQUE état bloquant de l'Accueil,
        /// calé sur la famille orange pour rester harmonieux.
        static let alarm         = Color(hex: 0xE23B2E)

        // MARK: Alias de compatibilité — NE PLUS UTILISER dans du code neuf.
        // Présents uniquement pour que les écrans non encore migrés compilent.
        static let background    = page
        static let inkSecondary  = ink
        static let inkTertiary   = iconInactive
        static let border        = divider
        static let accent        = blue
        static let accentWash    = surface
        static let danger        = alarm
        static let sun           = yellow
        static let disabled      = disabledFill
        static let primary       = ink
        static let primaryLight  = surface
        static let grayText      = ink
        static let grayBorder    = divider
        static let success       = green
        static let error         = alarm
    }

    // MARK: - Espacement (échelle 4 pt stricte)
    enum Spacing {
        static let s1:  CGFloat = 4
        static let s2:  CGFloat = 8
        static let s3:  CGFloat = 12
        static let s4:  CGFloat = 16
        static let s5:  CGFloat = 20
        static let s6:  CGFloat = 24
        static let s7:  CGFloat = 32
        static let s8:  CGFloat = 40
        static let s9:  CGFloat = 56
        static let s10: CGFloat = 72
        /// Gouttière latérale de TOUS les écrans
        static let gutter: CGFloat = 20

        // Alias de compatibilité
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 16
        static let l:  CGFloat = 20
        static let xl: CGFloat = 32
    }

    // MARK: - Rayons
    enum Radius {
        static let card:     CGFloat = 24
        static let cardLg:   CGFloat = 28
        static let thumb:    CGFloat = 16
        static let tile:     CGFloat = 12
        static let checkbox: CGFloat = 8
        /// Pilule
        static let full:     CGFloat = 999

        // Alias de compatibilité
        static let mockup:   CGFloat = 16
        static let button:   CGFloat = 999
        static let chip:     CGFloat = 999
    }

    // MARK: - Dimensions de composants (valeurs EXACTES de la maquette)
    enum Size {
        static let button:      CGFloat = 60   // hauteur du CTA primaire
        static let chip:        CGFloat = 72
        static let field:       CGFloat = 64
        static let row:         CGFloat = 72
        static let tabBar:      CGFloat = 84
        static let roundBtn:    CGFloat = 56   // bouton rond sur média
        static let secBtn:      CGFloat = 44   // bouton rond d'action de section
        static let statusDot:   CGFloat = 32   // pastille de timeline
        static let titleTile:   CGFloat = 46   // tuile d'icône de titre de page
        static let toggleW:     CGFloat = 64
        static let toggleH:     CGFloat = 36
        static let radio:       CGFloat = 40
        static let thumbW:      CGFloat = 72   // vignette de ton
        static let thumbH:      CGFloat = 56
        static let avatarHeader: CGFloat = 52
        static let avatarHero:  CGFloat = 96
        static let copyBtn:     CGFloat = 40
        static let creditPill:  CGFloat = 44
    }

    // MARK: - Typographie
    //
    // HANKEN GROTESK embarquée (4 graisses, PostScript names vérifiés :
    // HankenGrotesk-Regular / -Medium / -SemiBold / -Bold), déclarée dans
    // UIAppFonts des deux cibles. Le fallback système est un filet de sécurité.
    enum Fonts {
        private static func hk(_ size: CGFloat, _ weight: Font.Weight) -> Font {
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "HankenGrotesk-Bold"
            case .semibold:             name = "HankenGrotesk-SemiBold"
            case .medium:               name = "HankenGrotesk-Medium"
            default:                    name = "HankenGrotesk-Regular"
            }
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight)   // filet de sécurité
        }

        /// 34 / 40 · 700 — titre d'écran d'accueil, chiffre héros
        static var display: Font { hk(34, .bold) }
        /// 30 / 36 · 700 — titre de page (Studio, Essai, nom de profil)
        static var title1:  Font { hk(30, .bold) }
        /// 28 / 34 · 700 — titre de section importante
        static var title2:  Font { hk(28, .bold) }
        /// 24 / 30 · 700 — sous-titre de section
        static var title3:  Font { hk(24, .bold) }
        /// 20 / 26 · 700 — libellé de ligne, titre de carte
        static var headline: Font { hk(20, .bold) }
        /// 19 / 26 · 600 — libellé de bouton
        static var bodyStrong: Font { hk(19, .semibold) }
        /// 19 / 26 · 400 — corps, salutation, contenu utilisateur
        static var body:    Font { hk(19, .regular) }
        /// 17 / 24 · 400 — sous-titre, méta
        static var sub:     Font { hk(17, .regular) }
        /// 15 / 20 · 400 — légende, label de tab bar
        static var caption: Font { hk(15, .regular) }
        /// 15 / 20 · 600 + tracking — kicker EN CAPITALES (seul usage de majuscules)
        static var kicker:  Font { hk(15, .semibold) }

        // Alias de compatibilité (anciens écrans)
        static func title(_ size: CGFloat = 30) -> Font { hk(size, .bold) }
        static func display(_ size: CGFloat) -> Font { hk(size, .bold) }
        static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
            hk(size, weight)
        }
    }

    // MARK: - Interlignes (à appliquer avec .lineSpacing)
    enum LineSpacing {
        static let display: CGFloat = 2   // 34 → 40
        static let title1:  CGFloat = 2   // 30 → 36
        static let title2:  CGFloat = 2   // 28 → 34
        static let headline: CGFloat = 2  // 20 → 26
        static let body:    CGFloat = 3   // 19 → 26
        static let sub:     CGFloat = 3   // 17 → 24
    }

    // MARK: - Motion
    enum Motion {
        static let fast   = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.22)
        static let base   = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)
        static let slow   = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.44)
        /// Un LÉGER rebond est autorisé et souhaitable (ton bienveillant),
        /// uniquement sur les apparitions d'illustration et les validations.
        static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.68)
    }
}

// ── (ex-Tokens.swift) ─────────────────────────────────────────────────

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8)  & 0xff) / 255,
                  blue:  Double( hex        & 0xff) / 255,
                  opacity: alpha)
    }
}

// MARK: - L'arête basse — signature visuelle de la DA (§2.5)

// ── (ex-Tokens.swift) ─────────────────────────────────────────────────

struct CardEdgeBackground: ViewModifier {
    var fill: Color = DS.Colors.surface
    var radius: CGFloat = DS.Radius.card

    func body(content: Content) -> some View {
        content.background(
            ZStack(alignment: .bottom) {
                // L'arête : même forme, décalée de 1,5 pt vers le bas
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DS.Colors.cardEdge)
                    .offset(y: 1.5)
                // La carte par-dessus
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            }
        )
    }
}

// ── (ex-Tokens.swift) ─────────────────────────────────────────────────

extension View {
    /// Arête basse signature — à appliquer à TOUTE carte crème.
    func cardEdge(fill: Color = DS.Colors.surface,
                  radius: CGFloat = DS.Radius.card) -> some View {
        modifier(CardEdgeBackground(fill: fill, radius: radius))
    }
    /// Relief léger des boutons et badges (fond blanc + arête).
    func buttonEdge(radius: CGFloat = DS.Radius.full) -> some View {
        background(
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(hex: 0x3B3937, alpha: 0.14)).offset(y: 1.5)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white)
            }
        )
    }
}

// ── (ex-Components.swift) ─────────────────────────────────────────────────

// MARK: - Toast (pill sombre)
struct ToastView: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? DS.Colors.alarm : DS.Colors.greenBright)
            Text(message).font(DS.Fonts.body(15, weight: .medium)).foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(DS.Colors.ink.opacity(0.94))
        .clipShape(Capsule())
    }
}

// MARK: - Mini confettis (célébration — UNIQUEMENT essai 2 / design.md §8)

// ── (ex-WellnessComponents.swift) ─────────────────────────────────────────────────

/// CTA primaire — pilule BLEUE, hauteur 60, pleine largeur.
struct WPrimaryButton: View {
    let title: String
    var systemIcon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemIcon {
                    Image(systemName: systemIcon).font(.system(size: 20, weight: .semibold))
                }
                Text(title).font(DS.Fonts.bodyStrong)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: DS.Size.button)
            .background(DS.Colors.blue.opacity(enabled ? 1 : 0.4), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Bouton secondaire — pilule CRÈME.

// ── (ex-WellnessComponents.swift) ─────────────────────────────────────────────────

/// Palette de couleurs d'avatar proposées à l'utilisateur.
enum AvatarPalette {
    /// MÊME palette que la couleur de l'app (HZTheme.presets) : Pierre teste
    /// une direction artistique complète avec une seule et même teinte.
    static var hexes: [Int] { HZTheme.presets }
    static var colors: [Color] { hexes.map { Color(hex: UInt($0)) } }
    static func color(at index: Int) -> Color {
        let c = colors
        return c[max(0, min(index, c.count - 1))]
    }
    /// Luminance approximative (0…1) — pour le contraste des yeux.
    static func luminance(at index: Int) -> Double {
        let hex = hexes[max(0, min(index, hexes.count - 1))]
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255
    }
}

// ── (ex-WellnessComponents.swift) ─────────────────────────────────────────────────

enum WToneArt {
    /// CLASSIQUE — bulle équilibrée, deux lignes régulières, ciel.
    @ViewBuilder
    static func classique() -> some View {
        ZStack {
            DS.Colors.illusSky
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(DS.Colors.blueDeep.opacity(0.38)).frame(width: 26, height: 4)
                Capsule().fill(DS.Colors.blueDeep.opacity(0.38)).frame(width: 17, height: 4)
            }
            .padding(11)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(width: DS.Size.thumbW, height: DS.Size.thumbH)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
    }

    /// PROFESSIONNEL — document net à coin plié, bleu profond.
    @ViewBuilder
    static func professionnel() -> some View {
        ZStack {
            DS.Colors.blueDeep
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.white)
                Triangle().fill(DS.Colors.illusSky).frame(width: 11, height: 11)
            }
            .frame(width: 32, height: 40)
            .overlay(alignment: .center) {
                VStack(spacing: 4) {
                    Capsule().fill(DS.Colors.blueDeep.opacity(0.3)).frame(width: 18, height: 3)
                    Capsule().fill(DS.Colors.blueDeep.opacity(0.3)).frame(width: 18, height: 3)
                    Capsule().fill(DS.Colors.blueDeep.opacity(0.3)).frame(width: 11, height: 3)
                }
                .offset(y: 6)
            }
        }
        .frame(width: DS.Size.thumbW, height: DS.Size.thumbH)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
    }

    /// RIGOLO — confettis dispersés, rythme irrégulier, jaune.
    @ViewBuilder
    static func rigolo() -> some View {
        ZStack {
            DS.Colors.yellow
            FourPointStar().fill(.white).frame(width: 20, height: 20).offset(x: 8, y: -10)
            Circle().fill(DS.Colors.orangeDeep).frame(width: 12).offset(x: -16, y: -11)
            RoundedRectangle(cornerRadius: 3).fill(DS.Colors.illusPink)
                .frame(width: 12, height: 12).rotationEffect(.degrees(-18)).offset(x: -15, y: 11)
            Circle().fill(.white).frame(width: 8).offset(x: 24, y: 16)
        }
        .frame(width: DS.Size.thumbW, height: DS.Size.thumbH)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
    }

    /// CHARMEUR (ex-Sans filtre, rawValue « direct » inchangé) — un cœur
    /// blanc franc sur fond rose, une étincelle : l'énergie séduction.
    @ViewBuilder
    static func direct() -> some View {
        ZStack {
            DS.Colors.pink
            Image(systemName: "heart.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-8))
            FourPointStar().fill(DS.Colors.ink.opacity(0.85))
                .frame(width: 11, height: 11).offset(x: 22, y: -12)
            Circle().fill(.white.opacity(0.8)).frame(width: 7).offset(x: -24, y: 14)
        }
        .frame(width: DS.Size.thumbW, height: DS.Size.thumbH)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
    }

    /// TON PERSONNALISÉ — un segment court dans beaucoup de vide.
    /// La teinte tourne selon l'index pour différencier les tons créés.
    @ViewBuilder
    static func custom(index: Int) -> some View {
        let palette: [(Color, Color)] = [
            (DS.Colors.tileGreen, DS.Colors.green),
            (DS.Colors.illusLilac, DS.Colors.purple),
            (DS.Colors.tilePeach, DS.Colors.orangeDeep),
            (DS.Colors.illusSky, DS.Colors.blueDeep)
        ]
        let pair = palette[abs(index) % palette.count]
        ZStack {
            pair.0
            Capsule().fill(pair.1).frame(width: 20, height: 6)
        }
        .frame(width: DS.Size.thumbW, height: DS.Size.thumbH)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
    }
}

// ── (ex-WellnessComponents.swift) ─────────────────────────────────────────────────

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// ── (ex-WellnessComponents.swift) ─────────────────────────────────────────────────

struct FourPointStar: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let R = r.width / 2
        let i = R * 0.32
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - R))
        p.addLine(to: CGPoint(x: c.x + i, y: c.y - i)); p.addLine(to: CGPoint(x: c.x + R, y: c.y))
        p.addLine(to: CGPoint(x: c.x + i, y: c.y + i)); p.addLine(to: CGPoint(x: c.x, y: c.y + R))
        p.addLine(to: CGPoint(x: c.x - i, y: c.y + i)); p.addLine(to: CGPoint(x: c.x - R, y: c.y))
        p.addLine(to: CGPoint(x: c.x - i, y: c.y - i)); p.closeSubpath()
        return p
    }
}

// MARK: - Forme de bulle — rayons DIFFÉRENTS par coin (tracé exact §5.3)

/// Coins : [hautGauche, hautDroit, basDroit, basGauche]
