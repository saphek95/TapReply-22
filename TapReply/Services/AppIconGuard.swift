import UIKit

/// GARDE-FOU DES ICÔNES PRO — les icônes exclusives (Menthe, Bonbon, Royal,
/// Flamme) sont réservées aux abonnés. Si l'abonnement expire alors que l'une
/// d'elles est active, on rétablit l'icône principale au prochain lancement.
///
/// Appelé depuis TapReplyApp.init, avec un léger différé : le temps que
/// RevenueCat ait rafraîchi l'entitlement (fail-soft — en cas de doute on ne
/// touche à rien, on ne pénalise jamais un abonné dont l'API tarde).
enum AppIconGuard {

    /// Les noms d'assets d'icônes réservées aux abonnés Pro.
    static let proIconNames: Set<String> = [
        "AppIconMenthe", "AppIconRose", "AppIconRoyal", "AppIconFlamme"
    ]

    /// Au lancement : on ne se fie qu'au miroir PERSISTANT avec échéance (ProAccess), jamais à `isPro` avant que
    /// RevenueCat ait répondu (sinon un abonné dont l'API tarde perdait son icône).
    static func enforceProIcons() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if ProAccess.isKnownFree { resetIfPro() }
        }
    }

    /// Appelé par PurchaseService à CHAQUE état RevenueCat reçu (lancement, retour au premier plan, et en direct
    /// quand l'abonnement expire, est résilié ou remboursé) : l'icône Pro redevient l'icône principale.
    static func enforce(isPro: Bool) {
        guard !isPro else { return }
        DispatchQueue.main.async { resetIfPro() }
    }

    private static func resetIfPro() {
        guard UIApplication.shared.supportsAlternateIcons,
              let current = UIApplication.shared.alternateIconName,
              proIconNames.contains(current) else { return }
        UIApplication.shared.setAlternateIconName(nil) { error in
            if error == nil { RunLog.log("🎨 Icône Pro retirée (abonnement inactif) → icône principale") }
        }
    }
}
