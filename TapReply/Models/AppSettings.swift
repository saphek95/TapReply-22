import SwiftUI

/// Tons disponibles. `auto` = miroir du registre de la conversation.
/// ⚠️ Les rawValue ne changent JAMAIS (whitelistées par le backend).
/// Seuls les libellés d'interface changent (Classique/Professionnel/Rigolo/Charmeur).
enum Tone: String, CaseIterable, Identifiable {
    case auto, pro, friendly, direct, fact
    var id: String { rawValue }

    /// Valeur envoyée au backend. « fact » est un préréglage CÔTÉ APP : le backend reçoit tone=auto + une
    /// instruction (même mécanique que les tons personnalisés) — aucune whitelist serveur à toucher.
    var backendValue: String { self == .fact ? Tone.auto.rawValue : rawValue }
    /// Instruction du préréglage quand il passe par le canal « instruction » (Fact Checker uniquement).
    var presetInstruction: String? {
        guard self == .fact else { return nil }
        return "MODE FACT CHECKER. Tu ne réponds PAS au message, tu le VÉRIFIES. Le CONTENU de ta réponse est un verdict factuel sur ce qui est affiché à l'écran (chiffres, dates, causes, citations, faits présentés comme vrais), en 2 à 3 phrases, dans la langue de la conversation : commence par VRAI, FAUX ou À NUANCER (en majuscules), puis la correction ou la précision, et pourquoi (ordre de grandeur ou source si utile). Sobre, précis, sans emoji ni politesse, sans avis ni relance. S'il n'y a aucune affirmation vérifiable, écris : « Rien à vérifier ici. » puis une phrase disant pourquoi."
    }

    var label: String {
        switch self {
        case .auto: return String(localized: "Classique", comment: "tone")
        case .pro: return String(localized: "Professionnel")
        case .friendly: return String(localized: "Rigolo")
        case .direct: return String(localized: "Charmeur")
        case .fact: return String(localized: "Fact Checker")
        }
    }

    /// Phrase d'exemple affichée dans le Studio (UNE seule ligne).
    var example: String {
        switch self {
        case .auto: return String(localized: "« Oui, ça marche. On dit 18 h ? »")
        case .pro: return String(localized: "« Très bien, je vous confirme 18 h. »")
        case .friendly: return String(localized: "« 18 h ! Je ramène l'ambiance 😄 »")
        case .direct: return String(localized: "« 18 h, et la suite autour d'un verre ? 😏 »")
        case .fact: return String(localized: "« FAUX. La tour Eiffel mesure 330 m, pas 400. »")
        }
    }

    /// Conservé pour compatibilité — NE PLUS AFFICHER (DA Wellness §2.3 :
    /// pas d'emoji comme icône d'interface ; le Studio utilise WToneArt).
    var emoji: String {
        switch self {
        case .auto: return "✨"
        case .pro: return "💼"
        case .friendly: return "😊"
        case .direct: return "😏"
        case .fact: return "🔎"
        }
    }
}

/// Une langue de réponse sélectionnable dans les Réglages.
/// La sélection est MULTIPLE : 0 langue = automatique (langue de la conversation),
/// 1 langue = réponse forcée dans cette langue, 2+ = l'IA choisit la plus
/// adaptée au contexte PARMI les langues sélectionnées.
struct AppLanguage: Identifiable, Hashable {
    let code: String      // code ISO envoyé au backend
    let name: String      // nom français (affichage principal)
    let native: String    // nom natif (affichage secondaire + recherche)
    var id: String { code }

    /// Catalogue — trié par nom français.
    static let all: [AppLanguage] = [
        .init(code: "af", name: "Afrikaans", native: "Afrikaans"),
        .init(code: "sq", name: "Albanais", native: "Shqip"),
        .init(code: "de", name: "Allemand", native: "Deutsch"),
        .init(code: "en", name: "Anglais", native: "English"),
        .init(code: "ar", name: "Arabe", native: "العربية"),
        .init(code: "hy", name: "Arménien", native: "Հայերեն"),
        .init(code: "az", name: "Azerbaïdjanais", native: "Azərbaycanca"),
        .init(code: "eu", name: "Basque", native: "Euskara"),
        .init(code: "bn", name: "Bengali", native: "বাংলা"),
        .init(code: "be", name: "Biélorusse", native: "Беларуская"),
        .init(code: "my", name: "Birman", native: "မြန်မာ"),
        .init(code: "bs", name: "Bosnien", native: "Bosanski"),
        .init(code: "bg", name: "Bulgare", native: "Български"),
        .init(code: "ca", name: "Catalan", native: "Català"),
        .init(code: "zh", name: "Chinois (simplifié)", native: "中文（简体）"),
        .init(code: "zh-TW", name: "Chinois (traditionnel)", native: "中文（繁體）"),
        .init(code: "ko", name: "Coréen", native: "한국어"),
        .init(code: "hr", name: "Croate", native: "Hrvatski"),
        .init(code: "da", name: "Danois", native: "Dansk"),
        .init(code: "es", name: "Espagnol", native: "Español"),
        .init(code: "et", name: "Estonien", native: "Eesti"),
        .init(code: "fi", name: "Finnois", native: "Suomi"),
        .init(code: "fr", name: "Français", native: "Français"),
        .init(code: "gl", name: "Galicien", native: "Galego"),
        .init(code: "cy", name: "Gallois", native: "Cymraeg"),
        .init(code: "ka", name: "Géorgien", native: "ქართული"),
        .init(code: "el", name: "Grec", native: "Ελληνικά"),
        .init(code: "gu", name: "Gujarati", native: "ગુજરાતી"),
        .init(code: "he", name: "Hébreu", native: "עברית"),
        .init(code: "hi", name: "Hindi", native: "हिन्दी"),
        .init(code: "hu", name: "Hongrois", native: "Magyar"),
        .init(code: "id", name: "Indonésien", native: "Bahasa Indonesia"),
        .init(code: "ga", name: "Irlandais", native: "Gaeilge"),
        .init(code: "is", name: "Islandais", native: "Íslenska"),
        .init(code: "it", name: "Italien", native: "Italiano"),
        .init(code: "ja", name: "Japonais", native: "日本語"),
        .init(code: "kn", name: "Kannada", native: "ಕನ್ನಡ"),
        .init(code: "kk", name: "Kazakh", native: "Қазақша"),
        .init(code: "km", name: "Khmer", native: "ខ្មែរ"),
        .init(code: "ky", name: "Kirghize", native: "Кыргызча"),
        .init(code: "lo", name: "Lao", native: "ລາວ"),
        .init(code: "lv", name: "Letton", native: "Latviešu"),
        .init(code: "lt", name: "Lituanien", native: "Lietuvių"),
        .init(code: "lb", name: "Luxembourgeois", native: "Lëtzebuergesch"),
        .init(code: "mk", name: "Macédonien", native: "Македонски"),
        .init(code: "ms", name: "Malais", native: "Bahasa Melayu"),
        .init(code: "ml", name: "Malayalam", native: "മലയാളം"),
        .init(code: "mt", name: "Maltais", native: "Malti"),
        .init(code: "mr", name: "Marathi", native: "मराठी"),
        .init(code: "mn", name: "Mongol", native: "Монгол"),
        .init(code: "nl", name: "Néerlandais", native: "Nederlands"),
        .init(code: "ne", name: "Népalais", native: "नेपाली"),
        .init(code: "no", name: "Norvégien", native: "Norsk"),
        .init(code: "ur", name: "Ourdou", native: "اردو"),
        .init(code: "uz", name: "Ouzbek", native: "Oʻzbekcha"),
        .init(code: "pa", name: "Pendjabi", native: "ਪੰਜਾਬੀ"),
        .init(code: "fa", name: "Persan", native: "فارسی"),
        .init(code: "tl", name: "Philippin (Tagalog)", native: "Filipino"),
        .init(code: "pl", name: "Polonais", native: "Polski"),
        .init(code: "pt", name: "Portugais", native: "Português"),
        .init(code: "pt-BR", name: "Portugais (Brésil)", native: "Português (Brasil)"),
        .init(code: "ro", name: "Roumain", native: "Română"),
        .init(code: "ru", name: "Russe", native: "Русский"),
        .init(code: "sr", name: "Serbe", native: "Српски"),
        .init(code: "sk", name: "Slovaque", native: "Slovenčina"),
        .init(code: "sl", name: "Slovène", native: "Slovenščina"),
        .init(code: "sv", name: "Suédois", native: "Svenska"),
        .init(code: "sw", name: "Swahili", native: "Kiswahili"),
        .init(code: "ta", name: "Tamoul", native: "தமிழ்"),
        .init(code: "cs", name: "Tchèque", native: "Čeština"),
        .init(code: "te", name: "Télougou", native: "తెలుగు"),
        .init(code: "th", name: "Thaï", native: "ไทย"),
        .init(code: "tr", name: "Turc", native: "Türkçe"),
        .init(code: "uk", name: "Ukrainien", native: "Українська"),
        .init(code: "vi", name: "Vietnamien", native: "Tiếng Việt"),
    ]

    static func named(_ code: String) -> AppLanguage? {
        all.first { $0.code == code }
    }
}

/// Clés AppStorage partagées (app + intent tournent dans le même process).
enum SettingsKeys {
    static let onboardingDone = "onboardingDone"
    static let consentAccepted = "consentAccepted"
    static let shortcutConfirmed = "shortcutConfirmed"
    static let backTapConfirmed = "backTapConfirmed"
    static let defaultTone = "defaultTone"
    /// Ancienne clé (V≤0.2.1, valeur "auto"/"french"/"english") — migrée vers `replyLanguages`
    static let replyLanguageLegacy = "replyLanguage"
    /// Codes ISO séparés par des virgules ("fr,en"). Vide = automatique.
    static let replyLanguages = "replyLanguages"
    static let totalReplies = "totalReplies"
    /// Réponse quotidienne estimée par l'utilisateur (question d'engagement)
    static let messagesPerDay = "messagesPerDay"
    /// Détection des essais d'onboarding : timestamps de run + texte de la dernière réponse
    static let lastRunStartedAt = "lastRunStartedAt"
    static let lastReplyAt = "lastReplyAt"
    static let lastReplyText = "lastReplyText"
    static let lastRunErrorAt = "lastRunErrorAt"
    static let lastRunErrorMessage = "lastRunErrorMessage"
    /// CONFIRMATION DU RACCOURCI, PAR DÉCLENCHEUR. `shortcutConfirmed` reste la
    /// clé HISTORIQUE du Double Tap (ne pas renommer : elle est lue par
    /// l'onboarding, l'Accueil, l'Essai et les Réglages depuis la 1.0).
    /// Les deux gestes secondaires ont chacun leur propre raccourci, donc leur
    /// propre confirmation — iOS n'expose aucun moyen de les vérifier.
    static let shortcutConfirmedTripleTap = "shortcutConfirmed.tripleTap"
    static let shortcutConfirmedActionButton = "shortcutConfirmed.actionButton"
    /// Miroir PERSISTANT de l'entitlement Pro. L'App Intent tourne en
    /// arrière-plan, où PurchaseService.isPro n'a pas eu le temps d'être
    /// rafraîchi : ce cache lui donne la dernière valeur connue. Absent =
    /// jamais su → on laisse passer (fail-open, on ne pénalise personne).
    static let proCached = "proCached"
    /// Reprise de l'onboarding à une étape précise (ex. consentement refusé)
    static let onboardingResumeStep = "onboardingResumeStep"
    /// Onglet à ouvrir suite au tap sur une notification ("history" | "home" | "paywall")
    static let pendingOpenDestination = "pendingOpenDestination"
    /// JSON encodé de [CustomTone] (Studio — tons personnalisés)
    static let customTones = "customTones"
    /// Index de couleur de l'avatar blob (AvatarPalette)
    static let avatarColorIndex = "avatarColorIndex"
    /// AFFICHAGE DES RÉPONSES : "auto" (le système choisit — Dynamic Island sur
    /// les iPhone qui en ont une, bannière sur les autres) ou "notification".
    ///
    /// Ce réglage existe parce qu'aucune API ne permet de savoir si la bannière
    /// a réellement été VUE. Des testeurs sans Dynamic Island ne voyaient rien
    /// et désactivaient les activités en direct dans les Réglages d'iOS pour
    /// forcer la notification : bonne intuition, mauvais outil (ça coupait
    /// aussi l'affichage sur écran verrouillé). Ce réglage-ci fait la bascule
    /// proprement, sans rien casser d'autre.
    static let replyChannel = "replyChannel"
    /// Date du premier lancement (« Membre depuis {année} » des Réglages)
    static let firstLaunchDate = "firstLaunchDate"
    /// Vrai pendant un « Revoir l'onboarding » : les essais deviennent passables
    /// (pas de génération imposée si les crédits sont épuisés)
    static let onboardingReplay = "onboardingReplay"
    /// L'écran de splash « Commencer » a déjà été vu une fois. Passé ce cap,
    /// TOUTE ouverture de l'app affiche le splash court (logo + nom, sans
    /// bouton), même si l'onboarding n'est pas terminé.
    static let brandSplashSeen = "brandSplashSeen"
    /// La visite guidée des onglets, jouée une seule fois après l'onboarding.
    static let tourDone = "tourDone"
}

/// Accès simple aux réglages depuis du code non-SwiftUI (l'intent notamment).
enum AppSettings {
    static var defaultTone: Tone {
        Tone(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.defaultTone) ?? "auto") ?? .auto
    }
    /// Langues de réponse sélectionnées (codes ISO). Vide = automatique.
    /// Migre silencieusement l'ancien réglage mono-langue (V≤0.2.1).
    static var replyLocales: [String] {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: SettingsKeys.replyLanguages) {
            return raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        }
        // Migration one-shot depuis l'ancienne clé
        switch d.string(forKey: SettingsKeys.replyLanguageLegacy) {
        case "french":
            d.set("fr", forKey: SettingsKeys.replyLanguages)
            return ["fr"]
        case "english":
            d.set("en", forKey: SettingsKeys.replyLanguages)
            return ["en"]
        default:
            return []
        }
    }
    static var consentAccepted: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.consentAccepted)
    }
    static func incrementReplies() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: SettingsKeys.totalReplies) + 1, forKey: SettingsKeys.totalReplies)
    }

    // MARK: - Détection des essais (onboarding)
    /// L'intent marque le DÉBUT du run → l'onboarding affiche l'île simulée « analyse… »
    static func recordRunStarted() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: SettingsKeys.lastRunStartedAt)
    }
    static var lastRunStartedAt: Date? {
        let t = UserDefaults.standard.double(forKey: SettingsKeys.lastRunStartedAt)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    /// L'intent enregistre chaque ÉCHEC (les vues in-app affichent l'erreur)
    static func recordRunError(_ message: String) {
        let d = UserDefaults.standard
        d.set(Date().timeIntervalSince1970, forKey: SettingsKeys.lastRunErrorAt)
        d.set(message, forKey: SettingsKeys.lastRunErrorMessage)
    }
    static var lastRunErrorAt: Date? {
        let t = UserDefaults.standard.double(forKey: SettingsKeys.lastRunErrorAt)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    static var lastRunErrorMessage: String {
        UserDefaults.standard.string(forKey: SettingsKeys.lastRunErrorMessage) ?? ""
    }

    /// Le pipeline enregistre chaque succès
    static func recordLastReply(_ text: String) {
        let d = UserDefaults.standard
        d.set(Date().timeIntervalSince1970, forKey: SettingsKeys.lastReplyAt)
        d.set(text, forKey: SettingsKeys.lastReplyText)
    }
    static var lastReplyAt: Date? {
        let t = UserDefaults.standard.double(forKey: SettingsKeys.lastReplyAt)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    static var lastReplyText: String {
        UserDefaults.standard.string(forKey: SettingsKeys.lastReplyText) ?? ""
    }

    /// Heures/an estimées à chercher ses mots (45 s par vraie réponse)
    static func hoursPerYear(messagesPerDay: Int) -> Int {
        max(1, Int((Double(messagesPerDay) * 45.0 * 365.0 / 3600.0).rounded()))
    }
}
