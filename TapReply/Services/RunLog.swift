import Foundation

/// Journal de diagnostic (UserDefaults) partagé app ↔ intent.
/// Affiché dans Réglages → Diagnostic (5 taps sur Version).
///
/// Deux niveaux :
/// 1. `log()` — étapes techniques et erreurs (comportement historique).
/// 2. `recordRun()` — V1.1.2 : TRANSCRIPTION COMPLÈTE du dernier run
///    (messages THEM/ME, état du champ de saisie, brouillon, app détectée,
///    réponse de l'IA). C'est l'outil de diagnostic des retours testeurs :
///    il permet de savoir si un échec vient de l'OCR/parser (mauvaise
///    transcription) ou de l'IA (bonne transcription, mauvaise réponse).
///
/// ⚠️ Confidentialité : tout reste ON-DEVICE (UserDefaults local), jamais
/// envoyé au serveur, effaçable d'un tap. Le dernier run écrase le précédent.
enum RunLog {
    private static let key = "runlog.entries"
    private static let lastRunKey = "runlog.lastRun"
    private static let maxEntries = 60

    static func log(_ message: String) {
        var entries = UserDefaults.standard.stringArray(forKey: key) ?? []
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        entries.append("[\(formatter.string(from: Date()))] \(message)")
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        UserDefaults.standard.set(entries, forKey: key)
    }

    static var entries: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    // MARK: - Transcription détaillée du dernier run (V1.1.2)

    /// Enregistre ce que l'OCR a réellement transmis au backend, puis la
    /// réponse de l'IA. Appelé en deux temps par ReplyPipeline :
    /// `recordRunTranscription` juste après l'OCR, `recordRunReply` après la
    /// génération (ou l'erreur).
    static func recordRunTranscription(_ parsed: ParsedConversation) {
        var lines: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm:ss"
        lines.append("RUN du \(formatter.string(from: Date()))")
        lines.append("App détectée : \(parsed.appSource)")
        switch parsed.inputFieldState {
        case .emptyWithPlaceholder:
            lines.append("Champ de saisie : VIDE (placeholder vu et filtré)")
        case .hasDraft:
            lines.append("Champ de saisie : BROUILLON détecté")
        case .none:
            lines.append("Champ de saisie : non détecté")
        }
        if let draft = parsed.draft, !draft.isEmpty {
            lines.append("Brouillon : « \(draft) »")
        }
        lines.append("··· Conversation transcrite (\(parsed.messages.count) message(s)) ···")
        for m in parsed.messages {
            lines.append("\(m.sender == .me ? "ME  " : "THEM") : \(m.text)")
        }
        lines.append("··· Réponse IA ···")
        UserDefaults.standard.set(lines.joined(separator: "\n"), forKey: lastRunKey)
    }

    static func recordRunReply(_ reply: String) {
        guard var text = UserDefaults.standard.string(forKey: lastRunKey) else { return }
        text += "\n\(reply)"
        UserDefaults.standard.set(text, forKey: lastRunKey)
    }

    static func recordRunError(_ error: String) {
        guard var text = UserDefaults.standard.string(forKey: lastRunKey) else { return }
        text += "\n❌ \(error)"
        UserDefaults.standard.set(text, forKey: lastRunKey)
    }

    /// La transcription complète du dernier run (nil si aucun).
    static var lastRunTranscription: String? {
        UserDefaults.standard.string(forKey: lastRunKey)
    }

    /// Texte complet à exporter (journal d'événements + transcription détaillée)
    /// — Pierre le colle dans la conversation pour le diagnostic.
    static var exportText: String {
        var parts: [String] = []
        if let last = lastRunTranscription {
            parts.append("=== DERNIÈRE TRANSCRIPTION (ce que l'OCR a envoyé à l'IA) ===\n\(last)")
        }
        let events = entries
        if !events.isEmpty {
            parts.append("=== JOURNAL D'ÉVÉNEMENTS ===\n\(events.joined(separator: "\n"))")
        }
        return parts.joined(separator: "\n\n")
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: lastRunKey)
    }
}
