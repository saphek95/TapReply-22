import Foundation
import ActivityKit

/// ⚠️ Copie IDENTIQUE de TapReply/Models/ReplyActivityAttributes.swift.
/// Les deux modules doivent définir exactement la même structure.
/// Seuls les COMMENTAIRES peuvent différer : toute divergence de champ rend
/// l'état indécodable côté widget, et l'île s'affiche vide en silence.
struct ReplyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// "generating" | "ready" | "error" | "no_credits"
        var status: String
        var reply: String
        var toneEmoji: String
        var toneLabel: String
        /// V1.2.0 — thème au moment du run : couleur d'accent choisie dans
        /// les Réglages (hex RGB) et index de la mascotte de l'utilisateur
        /// (AvatarM0…AvatarM8). OPTIONNELS pour rester décodables face à un
        /// état émis par une version précédente de l'app.
        var accentHex: Int?
        var avatarIndex: Int?
        /// Nom d'asset de la MASCOTTE DU TON utilisé pour cette réponse
        /// (ToneClassique / TonePro / … / MascotPoseN). L'île la préfère à
        /// l'avatar. Optionnel (rétrocompatibilité de décodage).
        var mascotAsset: String?
    }

    var startedAt: Date
}
