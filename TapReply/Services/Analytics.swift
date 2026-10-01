import Foundation
import UIKit

/// STATISTIQUES D'USAGE ANONYMES (26/09) — étapes vues, jamais de contenu.
///
/// Ce qui part : un NOM d'événement (« onb_step », « paywall_view »…) et quelques étiquettes courtes
/// (« step: privacy », « plan: annual »), liés à l'identifiant anonyme d'achat (RevenueCat). JAMAIS de texte de
/// conversation, de prénom, de brouillon ni de réponse. Stockage : notre base (UE), conservation 13 mois.
/// L'utilisateur peut désactiver l'envoi dans Réglages › Statistiques d'usage anonymes.
///
/// File d'attente persistée (UserDefaults), envoi groupé quelques secondes après le dernier événement : l'app
/// ne fait jamais une requête par tap, et rien n'est perdu si elle est fermée entre-temps.
enum Analytics {
    static let enabledKey = "analyticsEnabled"
    private static let queueKey = "analytics.queue"
    private static let maxQueued = 200
    private static var flushTask: Task<Void, Never>?

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Nom : minuscules, chiffres et « _ » (2 à 40). Étiquettes : 8 au plus, valeurs courtes, jamais de texte libre.
    static func track(_ name: String, _ props: [String: String] = [:]) {
        guard isEnabled else { return }
        var queue = UserDefaults.standard.array(forKey: queueKey) as? [[String: Any]] ?? []
        queue.append(["name": name, "props": props, "ts": Date().timeIntervalSince1970])
        if queue.count > maxQueued { queue.removeFirst(queue.count - maxQueued) }
        UserDefaults.standard.set(queue, forKey: queueKey)
        scheduleFlush()
    }

    /// Désactivation : on vide aussi ce qui attendait d'être envoyé.
    static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: enabledKey)
        if !on { UserDefaults.standard.removeObject(forKey: queueKey) }
    }

    private static func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await flush()
        }
    }

    static func flush() async {
        guard isEnabled else { return }
        let queue = UserDefaults.standard.array(forKey: queueKey) as? [[String: Any]] ?? []
        guard !queue.isEmpty, let uid = await PurchaseService.appUserID else { return }
        let batch = Array(queue.prefix(40))
        let body: [String: Any] = ["action": "events", "appUserId": uid, "events": batch]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = GenerationClient.baseRequest(timeout: 12)
        request.httpBody = data
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        // On retire ce qui est parti (la file a pu grossir entre-temps).
        var current = UserDefaults.standard.array(forKey: queueKey) as? [[String: Any]] ?? []
        current.removeFirst(min(batch.count, current.count))
        UserDefaults.standard.set(current, forKey: queueKey)
        if !current.isEmpty { scheduleFlush() }
    }

    /// Ouverture de l'app (une fois par passage au premier plan) : version et langue, pour savoir qui est actif.
    static func appOpened() {
        let info = Bundle.main.infoDictionary
        let v = "\(info?["CFBundleShortVersionString"] as? String ?? "?")(\(info?["CFBundleVersion"] as? String ?? "?"))"
        track("app_open", ["v": v, "lang": Locale.current.language.languageCode?.identifier ?? "?"])
    }

    /// Raison d'échec d'une génération, en étiquette courte (jamais le message).
    static func failureReason(_ error: Error) -> String {
        switch error {
        case ReplyPipeline.PipelineError.consentMissing: return "consent"
        case ReplyPipeline.PipelineError.nothingUsable: return "nothing_usable"
        case ReplyPipeline.PipelineError.quotaExceeded: return "quota"
        case ReplyPipeline.PipelineError.toneLocked: return "tone_locked"
        case GenerationClient.GenerationError.noCredits: return "no_credits"
        case GenerationClient.GenerationError.network: return "network"
        case GenerationClient.GenerationError.rateLimited: return "rate_limited"
        case GenerationClient.GenerationError.unavailable: return "unavailable"
        case GenerationClient.GenerationError.notReady: return "not_ready"
        case GenerationClient.GenerationError.emptyReply: return "empty"
        case GenerationClient.GenerationError.server: return "server"
        default: return "ocr_or_other"
        }
    }
}
