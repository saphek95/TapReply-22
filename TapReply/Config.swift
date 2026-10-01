import Foundation

/// Configuration backend — V1.
/// La clé ci-dessous est la clé PUBLIQUE (anon) Supabase : elle est prévue pour être embarquée côté client.
/// La clé OpenRouter, elle, ne quitte JAMAIS le serveur (Edge Function).
enum Config {
    static let backendURL = URL(string: "https://ftabuhfyjsvalezloaks.supabase.co/functions/v1/tapreply-generate")!
    static let supabaseAnonKey = "sb_publishable_0szh0O5PwjsW3neVguropA_dRZGXjZA"

    /// Version affichée dans les Réglages — LUE DANS LE BUNDLE, jamais écrite
    /// à la main.
    ///
    /// C'est la correction d'un défaut qui s'était déjà produit : cette
    /// constante avait suivi jusqu'à « 2.0.2 » pendant que le bundle était
    /// resté à 1.0.1, si bien qu'un testeur lisait deux versions différentes
    /// selon qu'il regardait l'app ou TestFlight. Toute valeur recopiée à la
    /// main finit par diverger ; celle-ci ne peut plus.
    ///
    /// Affiche « version (build) », par exemple « 1.0.1 (10) » : c'est le
    /// couple exact qu'un testeur doit pouvoir nous citer, puisque plusieurs
    /// builds coexistent sous une même version dans TestFlight.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// Clé API RevenueCat (clé PUBLIQUE, prévue pour le client).
    /// PRODUCTION : clé App Store (StoreKit réel — sandbox sur TestFlight,
    /// vrais paiements après publication).
    static let revenueCatAPIKey = "appl_kifdDSYOEdLPBipZzJsRpCmBTmG"

    /// Politique de confidentialité (exigée par la guideline 5.1.2(i) — lien
    /// cliquable dans l'écran de consentement + à renseigner dans App Store Connect)
    /// Version du 26/09/2026 (FR + EN, conforme à l'app et au backend v42 : IA tierces nommées, RevenueCat,
    /// compteurs). MÊME URL à renseigner dans App Store Connect. Support : la même page, ancre #support.
    static let privacyPolicyURL = URL(string: "https://tapreply.vercel.app/privacy")!
    static let supportURL = URL(string: "https://tapreply.vercel.app/support")!

    /// CONDITIONS D'UTILISATION (EULA) — exigées par la guideline 3.1.2 sur
    /// TOUT écran d'abonnement, au même titre que la politique de
    /// confidentialité. Sans ces deux liens, le paywall est un motif de rejet
    /// classique, indépendamment de la qualité de l'intégration RevenueCat.
    ///
    /// Par défaut : l'EULA standard d'Apple, que l'on est autorisé à utiliser
    /// tant qu'on ne fournit pas ses propres conditions. Si Pierre rédige les
    /// siennes, remplacer cette URL ET renseigner le même lien dans App Store
    /// Connect (Informations sur l'app → Contrat de licence).
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: - Raccourcis iCloud, UN PAR GESTE
    //
    // iOS ne dit JAMAIS quel geste a lancé un raccourci : le Back Tap double,
    // le Back Tap triple et le bouton Action arrivent tous comme une simple
    // invocation, sans signature. Impossible donc de deviner l'origine depuis
    // un raccourci unique. La solution : TROIS raccourcis, chacun appelant une
    // ACTION DIFFÉRENTE de TapReply (« Analyser », « Analyser (triple tap) »,
    // « Analyser (bouton Action) »). C'est le raccourci qui porte l'étiquette,
    // et l'app en déduit quel ton employer.
    //
    // ⚠️ Un raccourci référence son action via le Bundle ID de l'app : si le
    // Bundle ID change (release App Store), regénérer et repartager les liens.

    /// Double Tap — le raccourci HISTORIQUE, celui de l'onboarding.
    static let shortcutInstallURL: URL? = URL(string: "https://www.icloud.com/shortcuts/f10ed8dfb5184e13b06163a6be5931e3")
    /// Triple Tap — raccourci « TapReply (Triple Tap) », action
    /// « Analyser (triple tap) ». Publié par Pierre le 30/08.
    static let shortcutInstallURLTripleTap: URL? = URL(string: "https://www.icloud.com/shortcuts/423f1440a0a846de9aa647f6eeb109de")
    /// Bouton Action — raccourci « TapReply (Action Button) », action
    /// « Analyser (bouton Action) ». Publié par Pierre le 30/08.
    static let shortcutInstallURLActionButton: URL? = URL(string: "https://www.icloud.com/shortcuts/0e381cb17672462d91b5817316391b03")
}
