import AppIntents
import Foundation

// =============================================================================
// LE MOTEUR PARTAGÉ DES TROIS ACTIONS « ANALYSER »
// =============================================================================
//
// POURQUOI TROIS ACTIONS ET NON UNE
//
// iOS ne transmet JAMAIS l'origine d'un raccourci : le Back Tap double, le
// Back Tap triple et le bouton Action arrivent tous comme une invocation nue,
// sans signature ni horodatage exploitable. Aucun moyen, donc, de deviner le
// geste depuis un raccourci unique.
//
// La réponse : trois App Intents distincts — « Analyser »,
// « Analyser (triple tap) », « Analyser (bouton Action) » — donc trois actions
// visibles dans l'app Raccourcis. L'utilisateur fabrique un raccourci par
// geste ; c'est le RACCOURCI qui porte l'étiquette, et l'app en déduit le ton.
//
// Trois intents plutôt qu'un intent à paramètre, pour deux raisons concrètes :
// 1. `AnalyzeIntent` n'est pas modifié → les raccourcis DÉJÀ installés chez les
//    testeurs continuent de fonctionner, sans « action à revoir » dans l'app
//    Raccourcis.
// 2. Avec un paramètre, quelqu'un qui oublie de changer le menu obtient deux
//    raccourcis identiques : son triple tap jouerait le ton du double tap, sans
//    le moindre message d'erreur. Une action par geste rend l'erreur impossible.
//
// Tout le travail reste ICI, en un seul endroit : les trois intents ne sont que
// trois portes d'entrée sur ce runner.
enum AnalyzeRunner {

    /// Fenêtre de l'anti-rebond, PAR GESTE (cf. `ToneTrigger.runGuardKey`).
    private static let guardWindow: TimeInterval = 5

    static func run(trigger: ToneTrigger, screenshot: IntentFile) async -> String {
        RunLog.log("⚡️ Action « \(trigger.intentActionName) » invoquée par le raccourci")

        // ── ANTI DOUBLE-DÉCLENCHEMENT, propre à ce geste ───────────────────
        // Le Back Tap part parfois deux fois d'affilée : le 2e run tuait l'île
        // du 1er (le message « flashait » puis repartait en chargement).
        //
        // ⚠️ Le garde-fou est PAR GESTE. Un compteur commun ferait qu'un triple
        // tap suivant un double tap de moins de 5 s serait ignoré — et
        // renverrait silencieusement la réponse de l'autre ton. Bug
        // indiagnosticable pour l'utilisateur.
        let guardKey = trigger.runGuardKey
        let lastForThisTrigger = UserDefaults.standard.double(forKey: guardKey)
        if lastForThisTrigger > 0,
           Date().timeIntervalSince1970 - lastForThisTrigger < guardWindow {
            RunLog.log("⏭️ Double déclenchement ignoré (< 5 s sur \(trigger.rawValue))")
            // On renvoie la DERNIÈRE réponse (pas une chaîne vide) : l'action
            // « Copier » du raccourci dupliqué recopiera la même réponse au
            // lieu d'ÉCRASER le presse-papiers avec du vide.
            return AppSettings.lastReplyText
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: guardKey)

        // ── GESTES SECONDAIRES = ABONNÉS ──────────────────────────────────
        // Sans cette porte, quelqu'un qui se désabonne garderait ses trois
        // gestes à vie. FAIL-OPEN assumé : si l'état de l'abonnement n'a jamais
        // été connu sur cet appareil (cache absent), on laisse passer — même
        // politique que les crédits côté backend, on ne pénalise jamais
        // quelqu'un pour une incertitude de notre côté.
        if trigger.isPremium, ProAccess.isKnownFree {
            let message = String(localized: "Ce raccourci utilise un ton Pro. Ouvre TapReply pour en profiter.")
            RunLog.log("🔒 \(trigger.rawValue) refusé : abonnement inactif")
            AppSettings.recordRunError(message)
            // Île « offre » : un tap ouvre directement le paywall (comme pour les crédits épuisés).
            await LiveActivityService.showNoCredits(message: message)
            return "⚠️ TapReply : \(message)"
        }

        // Marqueur GLOBAL de début de run — l'onboarding et le terrain d'essai
        // s'en servent pour afficher l'île « analyse… ». Conservé tel quel.
        AppSettings.recordRunStarted()

        // Le ton du GESTE. nil (emplacement vide) → le pipeline retombe sur le
        // réglage du Double Tap, donc jamais un geste sans réponse.
        let toneId = ToneTriggers.assignedToneId(for: trigger)
        RunLog.log("Ton du geste \(trigger.rawValue) : \(toneId ?? "aucun → réglage par défaut")")

        let imageData = screenshot.data
        RunLog.log("Capture reçue : \(imageData.count / 1024) Ko")

        do {
            let output = try await ReplyPipeline.run(imageData: imageData, toneId: toneId, source: trigger.rawValue)
            await LiveActivityService.showReply(reply: output.reply, tone: output.tone, toneRaw: output.toneRaw)
            return output.reply
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Une erreur est survenue. Réessaie.")
            RunLog.log("❌ Action terminée en erreur : \(message)")
            AppSettings.recordRunError(message)
            // Crédits épuisés → île DÉDIÉE (tap = paywall) · sinon île d'erreur
            if case GenerationClient.GenerationError.noCredits = error {
                await LiveActivityService.showNoCredits(message: message)
            } else if case ReplyPipeline.PipelineError.toneLocked = error {
                await LiveActivityService.showNoCredits(message: message)
            } else {
                await LiveActivityService.showError(message: message)
            }
            return "⚠️ TapReply : \(message)"
        }
    }
}

/// L'accès Pro vu depuis un contexte SANS interface : l'App Intent tourne en arrière-plan, où
/// `PurchaseService.isPro` n'a pas eu le temps d'être rafraîchi. On lit le miroir persistant, AVEC son échéance :
/// un abonné qui résilie ne garde pas les gestes Pro indéfiniment.
enum ProAccess {
    private static let untilKey = "proCachedUntil"
    /// Grâce hors ligne après l'échéance connue (renouvellement pas encore vu).
    private static let offlineGrace: TimeInterval = 3 * 86_400

    /// true si on SAIT que la personne n'est pas (ou plus) abonnée. Cache absent → false (le serveur facture).
    static var isKnownFree: Bool {
        guard let cached = UserDefaults.standard.object(forKey: SettingsKeys.proCached) as? Bool
        else { return false }
        if cached == false { return true }
        let until = UserDefaults.standard.double(forKey: untilKey)
        return until > 0 && Date().timeIntervalSince1970 > until + offlineGrace
    }

    /// true si la DERNIÈRE valeur connue était « abonné » et pas échue (évite le clignotement des cadenas).
    static var isKnownPro: Bool {
        (UserDefaults.standard.object(forKey: SettingsKeys.proCached) as? Bool) == true && !isKnownFree
    }

    /// Miroir écrit par PurchaseService (refresh ET customerInfoStream).
    static func cache(isPro: Bool, until: Date? = nil) {
        UserDefaults.standard.set(isPro, forKey: SettingsKeys.proCached)
        UserDefaults.standard.set(until?.timeIntervalSince1970 ?? 0, forKey: untilKey)
    }
}
