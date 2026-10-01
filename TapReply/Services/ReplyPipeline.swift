import Foundation
import UIKit

/// Pipeline complet : image → OCR on-device → génération → presse-papiers → historique → notification.
/// Utilisé par l'App Intent (boucle cœur) ET par le Playground (test in-app / simulateur).
enum ReplyPipeline {

    struct Output {
        let reply: String
        /// Le ton tel qu'il est STOCKÉ (rawValue d'un préréglage ou UUID d'un ton perso) : sert à choisir la mascotte.
        var toneRaw: String = ""
        let parsed: ParsedConversation
        let tone: Tone
    }

    enum PipelineError: Error, LocalizedError {
        case consentMissing
        case nothingUsable
        case quotaExceeded
        /// Ton personnalisé créé en plus du ton gratuit, abonnement Pro terminé.
        case toneLocked

        var errorDescription: String? {
            switch self {
            case .consentMissing:
                return String(localized: "Le partage avec l'IA est désactivé. Active-le dans TapReply, Réglages, Partage avec l'IA.")
            case .nothingUsable:
                return String(localized: "Impossible de lire une conversation sur cette capture. Ouvre la conversation à l'écran puis réessaie.")
            case .quotaExceeded:
                return String(localized: "Quota atteint.")
            case .toneLocked:
                return String(localized: "Ce ton personnalisé fait partie de Pro. Ouvre TapReply pour en profiter, ou choisis un autre ton.")
            }
        }
    }

    /// - Parameter toneId: le ton imposé par le GESTE déclencheur (Triple Tap,
    ///   bouton Action). nil = le pipeline lit le réglage du Double Tap.
    static func run(imageData: Data,
                    tone: Tone? = nil,
                    toneId: String? = nil,
                    copyToClipboard: Bool = true,
                    source: String = "double_tap") async throws -> Output {
        do {
            let out = try await runPipeline(imageData: imageData, tone: tone, toneId: toneId, copyToClipboard: copyToClipboard)
            let raw = out.toneRaw
            Analytics.track("reply", ["result": "ok", "trigger": source,
                                      "tone": Tone(rawValue: raw) != nil ? raw : "custom"])
            return out
        } catch {
            Analytics.track("reply", ["result": "fail", "trigger": source, "reason": Analytics.failureReason(error)])
            throw error
        }
    }

    private static func runPipeline(imageData: Data,
                                    tone: Tone?,
                                    toneId: String?,
                                    copyToClipboard: Bool) async throws -> Output {
        RunLog.log("Pipeline démarré (image : \(imageData.count / 1024) Ko)")

        // 0. Consentement (guideline 5.1.2(i))
        guard AppSettings.consentAccepted else {
            RunLog.log("❌ Consentement manquant")
            throw PipelineError.consentMissing
        }

        // 0bis. Ton personnalisé verrouillé (Pro terminé) : on ne génère pas avec, on l'explique.
        let resolvedToneId = toneId ?? UserDefaults.standard.string(forKey: SettingsKeys.defaultTone)
        if let raw = resolvedToneId, ProAccess.isKnownFree,
           CustomToneStore.isLocked(id: raw, hasPro: false) {
            RunLog.log("🔒 Ton personnalisé verrouillé (abonnement inactif)")
            throw PipelineError.toneLocked
        }

        // 1. Quota (V1 : illimité — couture pour RevenueCat phase 2)
        guard await Usage.service.canGenerate() else {
            RunLog.log("❌ Quota atteint")
            throw PipelineError.quotaExceeded
        }

        // 2. OCR on-device — l'image ne quitte jamais l'appareil
        let parsed: ParsedConversation
        do {
            // OCR Vision (synchrone, 200 à 800 ms) hors du pool coopératif de Swift Concurrency.
            parsed = try await Task.detached(priority: .userInitiated) {
                try ScreenshotParser.parse(imageData: imageData)
            }.value
        } catch {
            RunLog.log("❌ OCR : \(error.localizedDescription)")
            throw error
        }
        RunLog.log("OCR OK : \(parsed.messages.count) message(s), brouillon : \(parsed.draft?.isEmpty == false ? "oui" : "non"), app : \(parsed.appSource)")
        // V1.1.2 — transcription complète conservée ON-DEVICE pour le
        // diagnostic (Réglages → 5 taps sur Version). Jamais envoyée ailleurs
        // qu'au backend de génération (c'est déjà le cas du pipeline).
        // Transcription (texte de la conversation, messages de tiers compris) : diagnostic uniquement.
        if BuildEnv.allowsDiagnostics { RunLog.recordRunTranscription(parsed) }
        guard parsed.isUsable else {
            RunLog.log("❌ Rien d'exploitable sur la capture")
            RunLog.recordRunError("Rien d'exploitable sur la capture")
            throw PipelineError.nothingUsable
        }

        // 3. Génération (texte seul vers le backend)
        // ⚠️ On passe le paramètre `tone` TEL QUEL (nil la plupart du temps) :
        // c'est GenerationClient qui résout le réglage stocké, y compris les
        // TONS PERSONNALISÉS (UUID → customToneInstruction). Passer un Tone
        // résolu ici court-circuitait les tons personnalisés du double tap.
        // Ton effectif RETOURNÉ (affichage) : si un geste impose un ton, c'est
        // le sien ; un ton personnalisé se présente comme « auto » côté backend.
        let effectiveTone = tone
            ?? toneId.flatMap { Tone(rawValue: $0) }
            ?? (toneId != nil ? .auto : AppSettings.defaultTone)
        let reply: String
        do {
            reply = try await GenerationClient.generate(from: parsed, tone: tone, toneId: toneId)
        } catch {
            RunLog.log("❌ Backend : \(error.localizedDescription)")
            RunLog.recordRunError(error.localizedDescription)
            throw error
        }
        RunLog.log("✅ Réponse générée (\(reply.count) caractères)")
        RunLog.recordRunReply(reply)

        // 4. Presse-papiers (sécurité en plus de l'action "Copier" du raccourci)
        if copyToClipboard {
            await MainActor.run {
                UIPasteboard.general.string = reply
            }
        }

        // 5. Historique local + compteur
        // Le ton stocké peut être l'UUID d'un ton personnalisé (Studio) :
        // on conserve la forme brute pour que l'Historique affiche son titre.
        let storedToneRaw = tone?.rawValue
            ?? toneId
            ?? UserDefaults.standard.string(forKey: SettingsKeys.defaultTone)
            ?? effectiveTone.rawValue
        HistoryStore.save(
            reply: reply,
            tone: storedToneRaw,
            appSource: parsed.appSource,
            hadDraft: parsed.draft?.isEmpty == false
        )

        // 5bis. Marqueur de succès (l'onboarding s'en sert pour valider les essais)
        AppSettings.recordLastReply(reply)

        // 6. Pas de notification ici : depuis la V0.1.13, l'affichage (île prête,
        // ou notification de secours si l'île est indisponible) est géré par
        // LiveActivityService.showReply, appelé par l'intent APRÈS ce pipeline.
        // (Le Playground et les essais d'onboarding ont leur propre affichage.)

        // 7. Compteur d'usage (V2 : débit de crédit)
        await Usage.service.didGenerate()

        return Output(reply: reply, toneRaw: storedToneRaw, parsed: parsed, tone: effectiveTone)
    }
}
