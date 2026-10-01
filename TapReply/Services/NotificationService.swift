import Foundation
import UIKit
import UserNotifications

/// Notifications locales — le canal de restitution des iPhone SANS Dynamic
/// Island, et le filet de tous les autres.
///
/// ⚠️ CE N'EST PLUS UN PIS-ALLER. Sur un iPhone 13 ou un SE, c'est le SEUL
/// affichage que l'utilisateur verra de sa réponse : elle doit donc être aussi
/// soignée que l'île, pas un message système générique.
enum NotificationService {

    /// Catégorie portant l'action « Recopier ».
    private static let categoryId = "TAPREPLY_REPLY"
    static let actionCopy = "TAPREPLY_COPY"

    /// À appeler UNE fois au lancement : sans catégorie enregistrée, les
    /// actions n'apparaissent pas (iOS les associe par identifiant de
    /// catégorie, pas par notification).
    static func registerCategories() {
        let copy = UNNotificationAction(
            identifier: actionCopy,
            title: String(localized: "Recopier"),
            options: [] // sans .foreground : on recopie SANS ouvrir l'app
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [copy],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Les notifications sont-elles AUTORISÉES ?
    ///
    /// Indispensable pour choisir un canal de restitution : sans autorisation,
    /// `postReplyReady` part dans le vide, silencieusement. C'est ce qui rendait
    /// le problème indiagnosticable pour un testeur — il ne recevait rien, et
    /// aucune erreur ne remontait.
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Notifie que la réponse est prête (et déjà copiée).
    /// `destination` : onglet ouvert quand l'utilisateur touche la notification
    /// ("history" = réponse prête · "home" = erreur, pour corriger) — même
    /// logique que le tap sur l'île.
    static func postReplyReady(preview: String, destination: String = "history") {
        postReplyReady(preview: preview, destination: destination, toneLabel: nil)
    }

    /// - Parameter toneLabel: le ton employé, affiché en sous-titre. C'est ce
    ///   qui permet de vérifier d'un coup d'œil que le bon geste a joué le bon
    ///   ton — l'île l'affiche déjà, la notification l'ignorait.
    static func postReplyReady(preview: String, destination: String = "history", toneLabel: String?) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            RunLog.log(settings.authorizationStatus == .authorized
                       ? "📬 Notification postée"
                       : "⚠️ Notifications non autorisées (Réglages iOS > TapReply)")
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Réponse prête ✓ Copiée")
        if let toneLabel, !toneLabel.isEmpty {
            content.subtitle = toneLabel
        }
        content.body = String(preview.prefix(300))
        content.sound = nil // discret : l'utilisateur est probablement devant son écran
        content.userInfo = ["destination": destination, "reply": String(preview.prefix(1_500))]
        // L'action « Recopier » (voir registerCategories).
        content.categoryIdentifier = categoryId

        // TEMPS CRITIQUE — la réponse ne vaut que MAINTENANT : l'utilisateur est
        // dans sa conversation, le doigt en attente. Une notification reléguée
        // par un mode de concentration arrive trop tard pour servir.
        //
        // ⚠️ EXIGE LA CAPACITÉ « Time Sensitive Notifications » dans Xcode
        // (cible TapReply → Signing & Capabilities → +Capability). Sans elle,
        // iOS RETROGRADE simplement le niveau, sans erreur ni plantage : le
        // code ci-dessous est donc sans risque, il ne devient utile qu'une fois
        // la case cochée.
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        // Vignette MASCOTTE attachée à la notification : la mascotte de
        // l'utilisateur (sa couleur choisie), rendue depuis les assets.
        // Le système DÉPLACE l'attachement, d'où le fichier temporaire.
        let avatarIndex = UserDefaults.standard.integer(forKey: SettingsKeys.avatarColorIndex)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tapreply-notif-\(UUID().uuidString).png")
        if let mascot = UIImage(named: "AvatarM\(avatarIndex)"),
           let data = mascot.pngData() {
            try? data.write(to: tmpURL)
            if let attachment = try? UNNotificationAttachment(identifier: "mascot", url: tmpURL) {
                content.attachments = [attachment]
            }
        } else if let logoURL = Bundle.main.url(forResource: "NotificationLogo", withExtension: "png") {
            // Filet : l'ancien logo si les assets mascotte manquaient
            try? FileManager.default.copyItem(at: logoURL, to: tmpURL)
            if let attachment = try? UNNotificationAttachment(identifier: "logo", url: tmpURL) {
                content.attachments = [attachment]
            }
        }

        let id = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil // immédiat
        )
        UNUserNotificationCenter.current().add(request)

        // Zéro trace : la bannière vit son temps d'affichage (~6 s) puis on retire
        // la notification du centre de notifications (le message reste dans l'Historique).
        DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        }
    }
}

// MARK: - Tap sur la notification → même navigation que le tap sur l'île

extension Notification.Name {
    static let tapReplyOpenDestination = Notification.Name("tapReplyOpenDestination")
}

/// Délégué notifications : quand l'utilisateur TOUCHE la notification,
/// on route vers le bon onglet (Historique pour une réponse, Accueil pour
/// une erreur) — exactement comme le tap sur la Dynamic Island.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo

        // ACTION « RECOPIER » — sans ouvrir l'app.
        // Utile dans le cas très réel où l'utilisateur a copié autre chose entre
        // la génération et le moment où il colle : la réponse était perdue, il
        // devait rouvrir TapReply et aller la rechercher dans l'Historique.
        if response.actionIdentifier == NotificationService.actionCopy {
            if let reply = info["reply"] as? String, !reply.isEmpty {
                UIPasteboard.general.string = reply
                RunLog.log("📋 Réponse recopiée depuis la notification")
            }
            completionHandler()
            return
        }

        let destination = info["destination"] as? String ?? "history"
        // Double canal : flag persistant (lancement à froid) + notification interne
        // (app déjà ouverte) — RootView écoute les deux.
        UserDefaults.standard.set(destination, forKey: SettingsKeys.pendingOpenDestination)
        NotificationCenter.default.post(name: .tapReplyOpenDestination, object: destination)
        completionHandler()
    }
}
