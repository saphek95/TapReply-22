import Foundation

/// Langue d'interface choisie in-app.
///
/// Mécanisme : on écrit `AppleLanguages` dans UserDefaults — iOS charge alors
/// l'app dans cette langue AU PROCHAIN DÉMARRAGE. C'est l'approche fiable avec
/// les String Catalogs (le changement « à chaud » par substitution de bundle ne
/// couvre pas `String(localized:)` et cassait les deep links — abandonné en 0.2.5).
/// L'UI propose un redémarrage en un tap juste après le choix.
enum AppLocalization {

    static let storageKey = "appLanguage" // "" = automatique (langue de l'iPhone)

    /// Langues d'interface embarquées (doit refléter les locales du catalogue)
    static let available: [(code: String, label: String)] = [
        ("", String(localized: "Automatique (langue de l'iPhone)")),
        ("fr", "Français"),
        ("en", "English"),
        ("es", "Español"),
        ("de", "Deutsch"),
        ("it", "Italiano"),
        ("pt-BR", "Português (Brasil)"),
    ]

    /// Enregistre la préférence système — effective au prochain lancement.
    static func apply(_ code: String) {
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }
}
