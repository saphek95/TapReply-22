import SwiftUI

// =============================================================================
// MODÈLES DU SYSTÈME DE TONS — refonte Horizon 1.2.0
// - ToneItem : abstraction commune ton prédéfini / ton personnalisé
// - ToneTriggers : assignation ton ↔ déclencheur (Double Tap / Triple Tap /
//   Action Button). Le Double Tap reste stocké dans SettingsKeys.defaultTone :
//   c'est LA clé que lisent GenerationClient et ReplyPipeline — compatibilité
//   totale avec le pipeline réel, zéro migration.
// - ToneArtworkView : la « pochette » visuelle d'un ton (dégradé + onde + emoji)
// =============================================================================

// MARK: - Clés additionnelles (extension de l'enum existante, non modifiée)

extension SettingsKeys {
    /// Prénom affiché sur l'Accueil (« Salut, Pierre »)
    static let userName = "userName"
    /// Tons assignés aux déclencheurs secondaires (UI prête ; le pipeline réel
    /// reste piloté par le Double Tap = defaultTone)
    static let triggerTripleTap = "trigger.tripleTap"
    static let triggerActionButton = "trigger.actionButton"
    /// IDs des tons marqués favoris (cœur) — [String]
    static let favoriteToneIds = "favoriteToneIds"
    /// Marqueur d'amorçage : le Double Tap a déjà reçu son ton par défaut
    /// (Classique) au premier lancement. Sans ce marqueur, un Double Tap vidé
    /// volontairement serait réassigné à chaque ouverture de l'app.
    static let defaultToneSeeded = "defaultToneSeeded"
}

// MARK: - Item de ton unifié

/// Un ton affichable dans le Studio : soit un préréglage figé, soit un ton
/// personnalisé. `id` = Tone.rawValue OU UUID (même convention que le reste
/// de l'app : SettingsKeys.defaultTone, ReplyRecord.tone).
enum ToneItem: Identifiable, Equatable {
    case preset(Tone)
    case custom(CustomTone)

    var id: String {
        switch self {
        case .preset(let t): return t.rawValue
        case .custom(let c): return c.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .preset(let t): return t.label
        case .custom(let c): return c.title
        }
    }

    var isPreset: Bool {
        if case .preset = self { return true }
        return false
    }

    var emoji: String {
        switch self {
        case .preset(let t):
            switch t {
            case .auto: return "💬"
            case .pro: return "💼"
            case .friendly: return "😄"
            case .direct: return "😏"
            case .fact: return "🔎"
            }
        case .custom(let c):
            return c.emoji ?? "🎨"
        }
    }

    /// Description courte de la fiche.
    var about: String {
        switch self {
        case .preset(let t):
            switch t {
            case .auto:
                return String(localized: "Le ton invisible : il épouse le registre de la conversation et répond exactement comme toi, un jour normal.")
            case .pro:
                return String(localized: "Impeccable au travail : vouvoiement, phrases complètes, zéro emoji. Clair, courtois, orienté solution.")
            case .friendly:
                return String(localized: "L'humour d'abord : punchlines, autodérision et emojis bien placés. La réponse fait sourire, et répond quand même.")
            case .direct:
                return String(localized: "L'énergie des apps de rencontre : taquin, joueur, un compliment sincère, et toujours une question pour continuer.")
            case .fact:
                return String(localized: "Il ne répond pas : il vérifie. Ce qui est affiché à l'écran passe au crible, et il tranche en deux ou trois phrases (vrai, faux ou à nuancer), puis il explique. Vérification générée par une IA : elle peut se tromper et ne remplace pas un avis médical, juridique ou financier.")
            }
        case .custom(let c):
            let trimmed = c.about?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty
                ? String(localized: "Ton ton personnel, écrit avec tes mots.")
                : trimmed
        }
    }

    /// Exemple statique de la fiche (bulle reçue → bulle envoyée).
    /// Prédéfinis : figé. Personnalisés : dernier échange du mode Test, mis en
    /// cache — sinon nil (la fiche invite à Tester).
    var example: (them: String, me: String)? {
        switch self {
        case .preset(let t):
            switch t {
            case .auto:
                return (String(localized: "On se voit toujours demain ?"),
                        String(localized: "Oui carrément, 18h comme prévu. Hâte !"))
            case .pro:
                return (String(localized: "Pouvez-vous m'envoyer le devis ?"),
                        String(localized: "Bonjour, bien sûr : je vous le transmets d'ici la fin de journée. N'hésitez pas si vous avez la moindre question."))
            case .friendly:
                return (String(localized: "T'as vu le match hier ?"),
                        String(localized: "Vu ?? J'ai failli réveiller tout l'immeuble au 3e but 😂 On en parle autour d'une pizza ?"))
            case .direct:
                return (String(localized: "Alors comme ça tu cours le dimanche ?"),
                        String(localized: "Seulement si un café m'attend à l'arrivée… je cours beaucoup plus vite motivé 😏 Tu viens dimanche ?"))
            case .fact:
                return (String(localized: "La tour Eiffel a été construite pour l'Exposition universelle de 1900."),
                        String(localized: "FAUX. Elle a été inaugurée en 1889, pour l'Exposition universelle qui célébrait le centenaire de la Révolution. En 1900, c'est le Grand Palais qui a été construit."))
            }
        case .custom(let c):
            if let them = c.exampleThem, let me = c.exampleMe,
               !them.isEmpty, !me.isEmpty {
                return (them, me)
            }
            return nil
        }
    }

    /// L'illustration MASCOTTE d'un ton prédéfini (asset généré : la mascotte
    /// costumée selon le ton). nil pour un ton personnalisé (couleur + emoji).
    var artworkAsset: String? {
        switch self {
        case .preset(let t):
            switch t {
            case .auto:     return "ToneClassique"
            case .pro:      return "TonePro"
            case .friendly: return "ToneRigolo"
            case .direct:   return "ToneCharmeur"
            case .fact:     return "ToneFact"
            }
        case .custom:
            return nil
        }
    }

    /// Instruction envoyée au backend pour un ton personnalisé (nil = préréglage).
    var customInstruction: String? {
        if case .custom(let c) = self { return c.instruction }
        return nil
    }

    /// Le préréglage sous-jacent envoyé au backend (`tone`).
    var backendTone: Tone {
        if case .preset(let t) = self { return t }
        return .auto // ton perso : tone=auto + customToneInstruction (convention existante)
    }

    /// Dégradé de la pochette.
    var gradientColors: [Color] {
        switch self {
        case .preset(let t):
            switch t {
            case .auto:     return [Color(hex: 0x5EA2FF), Color(hex: 0x1F5EDB)]
            case .pro:      return [Color(hex: 0x44506A), Color(hex: 0x131A2A)]
            case .friendly: return [Color(hex: 0xFFB13B), Color(hex: 0xFF5E7E)]
            case .direct:   return [Color(hex: 0xC06CF7), Color(hex: 0xF3477E)]
            case .fact:     return [Color(hex: 0x2FBF8F), Color(hex: 0x0E7C66)]
            }
        case .custom(let c):
            return ToneArtPalette.colors(at: c.artIndex)
        }
    }

    /// Résolution depuis un id stocké (rawValue ou UUID). nil si le ton
    /// personnalisé a été supprimé.
    static func resolve(id: String) -> ToneItem? {
        if let preset = Tone(rawValue: id) { return .preset(preset) }
        if let custom = CustomToneStore.tone(withID: id) { return .custom(custom) }
        return nil
    }

    static var presets: [ToneItem] { Tone.allCases.map { .preset($0) } }
    static var customs: [ToneItem] { CustomToneStore.all.map { .custom($0) } }
}

// MARK: - Palette des tons personnalisés

enum ToneArtPalette {
    /// 6 duos harmonisés avec la DA Horizon — rotation par artIndex.
    static let all: [[Color]] = [
        [Color(hex: 0x36C2A2), Color(hex: 0x0E7A66)],   // lagon
        [Color(hex: 0xFF9A5A), Color(hex: 0xE1462C)],   // braise
        [Color(hex: 0x7B8CFF), Color(hex: 0x3A3FBF)],   // iris
        [Color(hex: 0xFF7BAC), Color(hex: 0xC22E6F)],   // rose vif
        [Color(hex: 0xFFD34D), Color(hex: 0xE18700)],   // soleil
        [Color(hex: 0x58C9F3), Color(hex: 0x1D6FD1)],   // ciel
        // Brume — LE fond uni bleu très clair des tons prédéfinis : pour
        // garder exactement la même direction artistique sur un ton créé.
        [Color(hex: 0xEBEDFB), Color(hex: 0xE4E7F9)],
    ]
    static func colors(at index: Int) -> [Color] {
        all[abs(index) % all.count]
    }
}

// MARK: - Favoris (cœurs)

enum ToneFavorites {
    /// Les favoris de la PREMIÈRE ouverture : Classique, Professionnel,
    /// Charmeur. Trois, et non quatre.
    ///
    /// La quatrième tuile de la grille est réservée à « crée ton propre ton » :
    /// c'est la fonctionnalité la plus différenciante de l'application, et
    /// personne ne la découvrait derrière « Voir tout ». Lui donner une place
    /// dans la grille d'accueil du studio la rend visible dès la première
    /// seconde, au prix d'un seul préréglage retiré des favoris.
    ///
    /// Rigolo n'est pas supprimé pour autant : il reste dans la bibliothèque,
    /// simplement pas en favori. Et ce défaut ne s'applique qu'aux nouvelles
    /// installations — on ne retire jamais un favori que quelqu'un a choisi.
    static let firstRunFavorites: [Tone] = [.auto, .pro, .direct]

    static var ids: [String] {
        if let stored = UserDefaults.standard.stringArray(forKey: SettingsKeys.favoriteToneIds) {
            return stored
        }
        return firstRunFavorites.map(\.rawValue)
    }

    static func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    static func toggle(_ id: String) {
        var current = ids
        if let i = current.firstIndex(of: id) {
            current.remove(at: i)
        } else {
            current.append(id)
        }
        UserDefaults.standard.set(current, forKey: SettingsKeys.favoriteToneIds)
    }

    static func remove(_ id: String) {
        UserDefaults.standard.set(ids.filter { $0 != id }, forKey: SettingsKeys.favoriteToneIds)
    }
}

// MARK: - Déclencheurs (Double Tap / Triple Tap / Action Button)

enum ToneTrigger: String, CaseIterable, Identifiable {
    case doubleTap, tripleTap, actionButton
    var id: String { rawValue }

    /// Les déclencheurs AFFICHABLES sur cet appareil : le slot Action Button
    /// n'apparaît que sur les iPhone qui ont le bouton (15 Pro et plus).
    static var available: [ToneTrigger] {
        DeviceCapabilities.hasActionButton
            ? allCases
            : [.doubleTap, .tripleTap]
    }

    var label: String {
        switch self {
        case .doubleTap: return String(localized: "Double Tap")
        case .tripleTap: return String(localized: "Triple Tap")
        case .actionButton: return String(localized: "Action Button")
        }
    }

    var systemIcon: String {
        switch self {
        case .doubleTap: return "hand.tap.fill"
        case .tripleTap: return "hand.tap"
        case .actionButton: return "button.vertical.left.press.fill"
        }
    }

    // MARK: - Ce que chaque geste sait de lui-même

    /// RÉSERVÉ AUX ABONNÉS ? Le Double Tap est le cœur de l'app, offert à tous.
    /// Les deux gestes secondaires — un ton de plus chacun, dégainé sans
    /// réfléchir — sont le bonus Pro. Ce qu'on vend n'est pas le geste (il
    /// appartient à iOS) mais le fait d'avoir PLUSIEURS tons sous la main.
    var isPremium: Bool { self != .doubleTap }

    /// Le nom de l'action telle qu'elle apparaît dans l'app Raccourcis.
    /// Doit rester synchronisé avec le `title` des App Intents.
    var intentActionName: String {
        switch self {
        case .doubleTap: return String(localized: "Analyser")
        case .tripleTap: return String(localized: "Analyser (triple tap)")
        case .actionButton: return String(localized: "Analyser (bouton Action)")
        }
    }

    /// Le nom suggéré pour le raccourci lui-même.
    var shortcutName: String {
        switch self {
        case .doubleTap: return "TapReply"
        case .tripleTap: return "TapReply (Triple Tap)"
        case .actionButton: return "TapReply (Action Button)"
        }
    }

    /// Lien iCloud d'import en 1 tap. nil → guide de création manuelle.
    var installURL: URL? {
        switch self {
        case .doubleTap: return Config.shortcutInstallURL
        case .tripleTap: return Config.shortcutInstallURLTripleTap
        case .actionButton: return Config.shortcutInstallURLActionButton
        }
    }

    /// Clé de la confirmation « ce raccourci est installé » (déclaratif : iOS
    /// ne permet pas de vérifier l'existence d'un raccourci).
    var shortcutConfirmedKey: String {
        switch self {
        case .doubleTap: return SettingsKeys.shortcutConfirmed
        case .tripleTap: return SettingsKeys.shortcutConfirmedTripleTap
        case .actionButton: return SettingsKeys.shortcutConfirmedActionButton
        }
    }

    var isShortcutConfirmed: Bool {
        UserDefaults.standard.bool(forKey: shortcutConfirmedKey)
    }

    /// Où l'utilisateur associe ce raccourci à ce geste, côté iOS.
    var systemSetupPath: String {
        switch self {
        case .doubleTap:
            return String(localized: "Réglages → Accessibilité → Toucher → Toucher le dos de l'appareil → Toucher deux fois")
        case .tripleTap:
            return String(localized: "Réglages → Accessibilité → Toucher → Toucher le dos de l'appareil → Toucher trois fois")
        case .actionButton:
            return String(localized: "Réglages → Bouton Action → Raccourci")
        }
    }

    /// Clé de l'ANTI-REBOND, propre à chaque geste. Un garde-fou commun ferait
    /// qu'un triple tap suivant un double tap de moins de 5 s serait ignoré —
    /// et renverrait silencieusement la réponse du geste précédent.
    var runGuardKey: String { "lastRunStartedAt.\(rawValue)" }
}

enum ToneTriggers {
    /// L'id du ton assigné à un déclencheur.
    /// ⚠️ Double Tap = SettingsKeys.defaultTone : la clé HISTORIQUE que lisent
    /// GenerationClient / ReplyPipeline. Toujours non-nil (défaut « auto »).
    static func assignedToneId(for trigger: ToneTrigger) -> String? {
        switch trigger {
        case .doubleTap:
            // nil = emplacement VIDE (le pipeline utilisera le Classique)
            return UserDefaults.standard.string(forKey: SettingsKeys.defaultTone)
        case .tripleTap:
            return UserDefaults.standard.string(forKey: SettingsKeys.triggerTripleTap)
        case .actionButton:
            return UserDefaults.standard.string(forKey: SettingsKeys.triggerActionButton)
        }
    }

    static func assignedTone(for trigger: ToneTrigger) -> ToneItem? {
        guard let id = assignedToneId(for: trigger) else { return nil }
        return ToneItem.resolve(id: id)
    }

    static func assign(_ toneId: String, to trigger: ToneTrigger) {
        switch trigger {
        case .doubleTap:
            UserDefaults.standard.set(toneId, forKey: SettingsKeys.defaultTone)
        case .tripleTap:
            UserDefaults.standard.set(toneId, forKey: SettingsKeys.triggerTripleTap)
        case .actionButton:
            UserDefaults.standard.set(toneId, forKey: SettingsKeys.triggerActionButton)
        }
        NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
        // object = le geste concerné : le Studio s'en sert pour lancer le
        // mini-onboarding du geste si son raccourci n'est pas encore confirmé.
        NotificationCenter.default.post(name: .tapReplyToneAssigned, object: trigger.rawValue)
    }

    /// Un déclencheur peut-il être vidé ? OUI pour tous depuis la 1.2.0 :
    /// vider le Double Tap signifie « aucun ton assigné » — le pipeline
    /// retombe alors sur le Classique (jamais de double tap sans réponse).
    static func clear(_ trigger: ToneTrigger) {
        switch trigger {
        case .doubleTap:
            // Emplacement VIDE : la clé est retirée. GenerationClient lit
            // alors « auto » par défaut → réponse en ton Classique.
            UserDefaults.standard.removeObject(forKey: SettingsKeys.defaultTone)
        case .tripleTap:
            UserDefaults.standard.removeObject(forKey: SettingsKeys.triggerTripleTap)
        case .actionButton:
            UserDefaults.standard.removeObject(forKey: SettingsKeys.triggerActionButton)
        }
        NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
    }

    /// Le ton supprimé était peut-être assigné quelque part : on nettoie.
    static func handleDeletedTone(id: UUID) {
        let raw = id.uuidString
        if UserDefaults.standard.string(forKey: SettingsKeys.defaultTone) == raw {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.defaultTone)
        }
        if UserDefaults.standard.string(forKey: SettingsKeys.triggerTripleTap) == raw {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.triggerTripleTap)
        }
        if UserDefaults.standard.string(forKey: SettingsKeys.triggerActionButton) == raw {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.triggerActionButton)
        }
        ToneFavorites.remove(raw)
        NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
    }

    /// Les déclencheurs auxquels un ton est actuellement assigné.
    static func triggers(for toneId: String) -> [ToneTrigger] {
        ToneTrigger.allCases.filter { assignedToneId(for: $0) == toneId }
    }
}

// MARK: - Capacités matérielles

enum DeviceCapabilities {
    /// L'app tourne-t-elle sur un iPAD (même en mode compatibilité iPhone, où userInterfaceIdiom renvoie .phone) ?
    /// On lit l'identifiant matériel (« iPad14,3 »…) ; au simulateur, le modèle simulé. Sert à proposer
    /// « Analyser une capture existante » UNIQUEMENT là où le Back Tap n'existe pas.
    static let isIPad: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        let model = (identifier.hasPrefix("iPhone") || identifier.hasPrefix("iPad"))
            ? identifier
            : (ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "")
        return model.hasPrefix("iPad")
    }()

    /// L'iPhone a-t-il le BOUTON ACTION ? (iPhone 15 Pro / Pro Max, puis
    /// toute la gamme à partir des iPhone 16.) Pas d'API publique : on lit
    /// l'identifiant matériel (« iPhone16,1 »…) — la génération 16,x
    /// correspond aux 15 Pro, et 17,x et au-delà aux iPhone 16+.
    static let hasActionButton: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        // Simulateur : l'identifiant est « arm64 » / « x86_64 » → on lit le
        // modèle simulé, sinon on affiche tout (confort de développement).
        let model = identifier.hasPrefix("iPhone")
            ? identifier
            : (ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "")
        guard model.hasPrefix("iPhone") else { return true }
        let generation = model.dropFirst("iPhone".count).split(separator: ",").first
        guard let major = Int(generation ?? "") else { return true }
        if major >= 17 { return true }                                  // iPhone 16 et suivants
        if major == 16 { return model == "iPhone16,1" || model == "iPhone16,2" } // 15 Pro / Pro Max
        return false
    }()

    /// L'iPhone a-t-il la DYNAMIC ISLAND ?
    ///
    /// POURQUOI CETTE QUESTION DÉCIDE DE TOUT LE RETOUR UTILISATEUR
    /// Une Live Activity sans Dynamic Island n'est visible que sur l'ÉCRAN
    /// VERROUILLÉ et dans le centre de notifications. Or le geste de TapReply
    /// se fait précisément l'écran déverrouillé, DANS une conversation : sur un
    /// iPhone sans île, l'activité se lance sans erreur, et l'utilisateur ne
    /// voit RIEN. C'est le bug que les testeurs contournaient à la main en
    /// désactivant les activités en direct pour forcer les notifications.
    ///
    /// Pas d'API publique : on lit l'identifiant matériel, même méthode que le
    /// bouton Action ci-dessus.
    ///   • iPhone15,2 / 15,3 → 14 Pro / Pro Max (première île)
    ///   • iPhone15,4 / 15,5 → 15 / 15 Plus
    ///   • iPhone16,1 / 16,2 → 15 Pro / Pro Max
    ///   • iPhone17,x et au-delà → toute la gamme 16 et suivantes
    ///   • iPhone14,x et en dessous → encoche ou bouton Home : PAS d'île
    ///     (dont l'iPhone 14 / 14 Plus, iPhone14,7 / 14,8, et le SE 3 iPhone14,6)
    static let hasDynamicIsland: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        let model = identifier.hasPrefix("iPhone")
            ? identifier
            : (ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "")
        // Modèle inconnu : on suppose l'île présente, donc on garde le
        // comportement historique. Un faux positif dégrade l'affichage ; un
        // faux négatif enverrait une notification à quelqu'un qui a une île,
        // ce qui ferait doublon avec elle.
        guard model.hasPrefix("iPhone") else { return true }
        let generation = model.dropFirst("iPhone".count).split(separator: ",")
        guard let major = Int(generation.first ?? ""),
              let minor = Int(generation.dropFirst().first ?? "") else { return true }
        if major >= 16 { return true }
        if major == 15 { return minor >= 2 }
        return false
    }()
}

extension Notification.Name {
    /// Posté à chaque changement de tons / assignations / favoris — les vues
    /// du Studio se rafraîchissent (les tons vivent dans UserDefaults, pas
    /// dans un store observable).
    static let tapReplyTonesChanged = Notification.Name("tapReplyTonesChanged")
    /// Posté quand un ton vient d'être ASSIGNÉ à un déclencheur. Distinct de
    /// tapReplyTonesChanged (qui part aussi pour un simple favori) : celui-ci
    /// signifie « la tâche est accomplie », et la bibliothèque des tons s'en
    /// sert pour se refermer derrière la fiche — on revient au Studio d'un
    /// coup, sans avoir à fermer une feuille de plus à la main.
    static let tapReplyToneAssigned = Notification.Name("tapReplyToneAssigned")
}

// MARK: - Mascotte

/// L'AVATAR-MASCOTTE : l'image officielle de la mascotte, déclinée dans les
/// couleurs de la palette (AvatarM0…AvatarM8, même ordre que HZTheme.presets).
/// Remplace l'ancien blob vectoriel sur toutes les surfaces Horizon.
struct MascotAvatarView: View {
    var index: Int = 0
    var size: CGFloat = 40
    /// Statut Pro : la mascotte porte alors une petite COURONNE or, posée de
    /// travers sur la tête (clin d'œil premium — même langage que le badge).
    var crowned: Bool = false

    var body: some View {
        // La mascotte TELLE QUELLE : sticker détouré (pieds + ombre inclus),
        // posé directement sur l'écran — ni rond, ni fond.
        Image("AvatarM\(max(0, min(index, HZTheme.presets.count - 1)))")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // La couronne se pose EN HAUT-DROITE, AU-DESSUS du crâne, inclinée.
            // Elle dépasse volontairement du cadre vers le haut (offset y
            // NÉGATIF) : c'est une parure posée sur la tête, jamais un badge
            // collé sur le visage. `allowsHitTesting(false)` + pas de clip pour
            // que le débordement reste visible dans les conteneurs parents.
            .overlay(alignment: .topTrailing) {
                if crowned {
                    HZCrownMark(size: size * 0.30)
                        .rotationEffect(.degrees(22))
                        .offset(x: -size * 0.09, y: -size * 0.14)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Le CATALOGUE DE POSES de la mascotte (stickers détourés, fond transparent)
/// — utilisé à la création d'un ton personnalisé : on choisit la pose, puis
/// la couleur du fond.
enum MascotCatalog {
    static let count = 10
    /// Les DIX poses : un still vectoriel (TapTapAssets) et son cadrage carré, mesuré dans le pipeline.
    /// Même ordre que les libellés ci-dessous et que les PNG du widget (TTPose0…9_M0…8).
    static let stills: [(id: String, crop: CGRect)] = [
        ("POSE_Ecrit", CGRect(x: 7, y: 6, width: 623, height: 623)),
        ("POSE_Envolee", CGRect(x: 13, y: 18, width: 656, height: 656)),
        ("POSE_Coeur", CGRect(x: 46, y: 32, width: 583, height: 583)),
        ("POSE_Cool", CGRect(x: 2, y: -7, width: 671, height: 671)),
        ("POSE_Cosy", CGRect(x: 32, y: 15, width: 611, height: 611)),
        ("POSE_Fusee", CGRect(x: 1, y: 1, width: 673, height: 673)),
        ("POSE_Show", CGRect(x: 34, y: 28, width: 588, height: 588)),
        ("POSE_Studieux", CGRect(x: 25, y: -1, width: 625, height: 625)),
        ("POSE_Energie", CGRect(x: 55, y: 55, width: 566, height: 566)),
        ("POSE_Zen", CGRect(x: 12, y: 44, width: 651, height: 651)),
    ]
    /// Conservé pour compatibilité : le nom du PNG du WIDGET (couleur de la mascotte de l'utilisateur).
    static func asset(_ index: Int) -> String {
        "TTPose\(max(0, min(index, count - 1)))_M\(TapTapColor.mascotIndex)"
    }
    static func still(_ index: Int) -> (id: String, crop: CGRect) { stills[max(0, min(index, count - 1))] }
    static func label(_ index: Int) -> String {
        switch index {
        case 0: return String(localized: "Écrit")
        case 1: return String(localized: "Envolée")
        case 2: return String(localized: "Cœur")
        case 3: return String(localized: "Cool")
        case 4: return String(localized: "Cosy")
        case 5: return String(localized: "Fusée")
        case 6: return String(localized: "Show")
        case 7: return String(localized: "Studieux")
        case 8: return String(localized: "Énergie")
        default: return String(localized: "Zen")
        }
    }
}

// MARK: - Artwork d'un ton (la « pochette »)

/// La pochette visuelle d'un ton : dégradé signature, onde sonore stylisée
/// (la « voix » du ton) et emoji. 100 % dessinée — aucun asset binaire.
struct ToneArtworkView: View {
    let tone: ToneItem
    var cornerRadius: CGFloat = HZ.Radius.tile
    var emojiScale: CGFloat = 1

    var body: some View {
        // Tons PRÉDÉFINIS : le TapTap costumé du ton — vectoriel, à la couleur de l'utilisateur, cadré à la même
        // distance pour les quatre (référence : Charmeur).
        if let asset = tone.artworkAsset, let still = TapTapClips.toneStill(forAsset: asset) {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(HZ.Colors.card)
                    TapTapStillView(id: still, crop: TapTapClips.toneCrop(still))
                        .padding(geo.size.height * 0.04)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            customArtwork
        }
    }

    /// Tons PERSONNALISÉS : fond dégradé choisi + STICKER MASCOTTE si une
    /// pose a été sélectionnée — sinon l'ancienne pochette onde + emoji
    /// (tons créés avant la mascotte).
    @ViewBuilder
    private var customArtwork: some View {
        if case .custom(let c) = tone, let pose = c.mascotIndex {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: tone.gradientColors,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    // La pose vectorielle, à la couleur de TapTap
                    TapTapStillView(id: MascotCatalog.still(pose).id, crop: MascotCatalog.still(pose).crop)
                        .padding(geo.size.height * 0.06)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            generatedArtwork
        }
    }

    /// Ancienne pochette générée : dégradé + onde + emoji.
    private var generatedArtwork: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: tone.gradientColors,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // Halo doux en haut à gauche
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: w * 0.85)
                    .blur(radius: 30)
                    .offset(x: -w * 0.32, y: -h * 0.38)
                // L'onde : la « voix » du ton
                ToneWaveform(seed: tone.id)
                    .stroke(.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: max(2.5, w * 0.016), lineCap: .round))
                    .padding(.horizontal, w * 0.12)
                    .frame(height: h * 0.42)
                    .offset(y: h * 0.05)
                // Emoji identitaire
                Text(tone.emoji)
                    .font(HZ.Fonts.fig(w * 0.19 * emojiScale))
                    .offset(x: -w * 0.30, y: -h * 0.30)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// Onde pseudo-aléatoire mais STABLE (dérivée de l'id du ton) : chaque ton a
/// sa signature visuelle, constante entre les lancements.
struct ToneWaveform: Shape {
    let seed: String

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bars = 14
        guard bars > 1, rect.width > 0 else { return path }
        // Générateur déterministe simple à partir du hash de l'id
        var state = UInt64(truncatingIfNeeded: seed.unicodeScalars.reduce(5381 as UInt64) {
            ($0 << 5) &+ $0 &+ UInt64($1.value)
        })
        func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 1000) / 1000
        }
        let step = rect.width / CGFloat(bars - 1)
        let midY = rect.midY
        for i in 0..<bars {
            let x = rect.minX + CGFloat(i) * step
            // Enveloppe : plus ample au centre, plus discrète aux bords
            let envelope = 0.35 + 0.65 * sin(.pi * CGFloat(i) / CGFloat(bars - 1))
            let amplitude = (0.25 + 0.75 * next()) * envelope * rect.height / 2
            path.move(to: CGPoint(x: x, y: midY - amplitude))
            path.addLine(to: CGPoint(x: x, y: midY + amplitude))
        }
        return path
    }
}

// MARK: - Vignette de bibliothèque (artwork + cœur + titre)

struct ToneTileView: View {
    let tone: ToneItem
    var isFavorite: Bool
    /// Ton personnalisé créé en plus du ton gratuit, abonnement Pro terminé : gardé mais sous cadenas.
    var locked: Bool = false
    var onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ToneArtworkView(tone: tone)
                .aspectRatio(1.45, contentMode: .fit)
                .saturation(locked ? 0.2 : 1)
                .opacity(locked ? 0.55 : 1)
                .overlay { if locked { ToneLockBadge() } }
                .overlay(alignment: .topTrailing) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isFavorite ? Color(hex: 0xE8324F) : HZ.Colors.ink)
                            .frame(width: 30, height: 30)
                            .background(.white, in: Circle())
                            .hzSoft()
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                .hzSoft()
            HStack(spacing: 5) {
                Text(tone.title)
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.ink)
                    .lineLimit(1)
                if tone.isPreset {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(HZ.Colors.blue)
                }
                if locked {
                    Text(verbatim: "PRO")
                        .font(HZ.Fonts.fig(10, .heavy))
                        .foregroundStyle(HZ.Colors.goldDeep)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(HZ.Colors.gold.opacity(0.14), in: Capsule())
                }
            }
        }
        .accessibilityHint(locked ? String(localized: "Ton réservé à Pro. Touche pour en savoir plus.") : "")
    }
}

/// LA TUILE « CRÉE TON TON », quatrième case de la grille du studio.
///
/// Elle occupe exactement le gabarit d'une tuile de ton — même rapport, même
/// hauteur de légende — pour se lire comme un membre de la collection et non
/// comme un bouton posé à côté. Le contour en pointillé dit la seule différence
/// qui compte : cette case est vide, c'est à toi de la remplir.
struct CreateToneTile: View {
    @ObservedObject private var theme = HZTheme.shared
    /// Le ton gratuit existe déjà (compte sans Pro) : le « + » porte un cadenas, créer un 2e ton est Pro.
    var locked: Bool = false

    private var accent: Color { Color(hex: UInt(theme.accentHex)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: HZ.Radius.card, style: .continuous)
                    .fill(locked ? HZ.Colors.gold.opacity(0.06) : accent.opacity(0.07))

                RoundedRectangle(cornerRadius: HZ.Radius.card, style: .continuous)
                    .strokeBorder(locked ? HZ.Colors.gold.opacity(0.6) : accent.opacity(0.45),
                                  style: StrokeStyle(lineWidth: 1.6, dash: [6, 5]))

                VStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(locked ? .white : accent)
                            .frame(width: 38, height: 38)
                        if locked {
                            HZLockMark(size: 19)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(locked ? String(localized: "tons illimités avec Pro") : String(localized: "à toi d'écrire"))
                        .font(HZ.Fonts.fig(12, .semibold))
                        .foregroundStyle(locked ? HZ.Colors.goldDeep : accent)
                        .multilineTextAlignment(.center)
                }
            }
            .aspectRatio(1.45, contentMode: .fit)

            HStack(spacing: 5) {
                Text(String(localized: "Ton ton perso"))
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.ink)
                    .lineLimit(1)
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
            }
        }
    }
}

// MARK: - Pastille ronde d'un ton (lignes d'historique, slots de déclencheur)

struct ToneDotView: View {
    let tone: ToneItem
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let asset = tone.artworkAsset, let still = TapTapClips.toneStill(forAsset: asset) {
                // Le TapTap du ton en médaillon (cadré sur le visage), à la couleur de l'utilisateur
                ZStack {
                    Circle().fill(HZ.Colors.card)
                    TapTapStillView(id: still, crop: TapTapClips.toneFaceCrop(still))
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else if case .custom(let c) = tone, let pose = c.mascotIndex {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: tone.gradientColors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    TapTapStillView(id: MascotCatalog.still(pose).id, crop: MascotCatalog.still(pose).crop)
                        .padding(size * 0.08)
                }
            } else {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: tone.gradientColors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text(tone.emoji).font(HZ.Fonts.fig(size * 0.44))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
