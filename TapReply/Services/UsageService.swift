import Foundation

/// COUTURE ARCHITECTURALE pour la monétisation (phase 2).
///
/// V1 : usage illimité et gratuit (`UnlimitedUsage`).
/// Phase 2 : remplacer par une implémentation RevenueCat Virtual Currency
/// (vérification du solde côté serveur, débit par génération) SANS toucher
/// au reste du code — tout passe par ce protocole.
protocol UsageService {
    /// Peut-on lancer une génération ? (V2 : solde de crédits > 0 ou abonnement actif)
    func canGenerate() async -> Bool
    /// Appelé après une génération réussie. (V2 : débit d'un crédit)
    func didGenerate() async
    /// Solde affichable (nil = illimité).
    var displayBalance: Int? { get }
}

struct UnlimitedUsage: UsageService {
    func canGenerate() async -> Bool { true }
    func didGenerate() async {}
    var displayBalance: Int? { nil }
}

enum Usage {
    /// Point d'injection unique. Phase 2 : `RevenueCatUsage()`.
    static let service: UsageService = UnlimitedUsage()
}
