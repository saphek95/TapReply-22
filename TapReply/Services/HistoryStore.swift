import Foundation
import SwiftData

/// Conteneur SwiftData partagé entre l'app et l'App Intent (même process).
enum HistoryStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: ReplyRecord.self)
        } catch {
            // Base locale illisible (disque plein, fichier corrompu) : l'app démarre quand même, avec un historique
            // en mémoire pour cette session, plutôt que de planter au lancement (audit 26/09, BUG-001).
            RunLog.log("❌ Historique indisponible, bascule en mémoire : \(error.localizedDescription)")
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: ReplyRecord.self, configurations: memory) { return fallback }
            fatalError("SwiftData container error: \(error)")
        }
    }()

    /// Insertion utilisable depuis l'intent (contexte éphémère).
    static func save(reply: String, tone: String, appSource: String, hadDraft: Bool) {
        let context = ModelContext(container)
        context.insert(ReplyRecord(reply: reply, tone: tone, appSource: appSource, hadDraft: hadDraft))
        do { try context.save() } catch { RunLog.log("❌ Historique : enregistrement impossible (\(error.localizedDescription))") }
        AppSettings.incrementReplies()
    }
}
