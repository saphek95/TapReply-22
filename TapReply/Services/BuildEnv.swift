import Foundation

/// Environnement de build : les outils de diagnostic (journal caché, debugLog serveur) n'existent QUE dans les
/// builds de développement et TestFlight, jamais dans la version App Store (guideline 2.3.1 : pas de fonction cachée).
enum BuildEnv {
    static var allowsDiagnostics: Bool {
        // DEBUG uniquement : les builds de review Apple ont AUSSI un reçu
        // « sandbox », ils seraient pris pour du TestFlight (guideline 2.3.1).
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
