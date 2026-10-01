import Foundation
import SwiftData

/// Une réponse générée, stockée EN LOCAL UNIQUEMENT (SwiftData).
@Model
final class ReplyRecord {
    var id: UUID
    var reply: String
    var tone: String
    var appSource: String
    var hadDraft: Bool
    var createdAt: Date
    var isFavorite: Bool

    init(reply: String, tone: String, appSource: String, hadDraft: Bool) {
        self.id = UUID()
        self.reply = reply
        self.tone = tone
        self.appSource = appSource
        self.hadDraft = hadDraft
        self.createdAt = Date()
        self.isFavorite = false
    }
}
