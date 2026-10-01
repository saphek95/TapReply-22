import Foundation
import ActivityKit

/// Attributs de la Live Activity « réponse en cours / prête ».
/// ⚠️ Une copie IDENTIQUE de ce fichier existe dans TapReplyWidgets/ —
/// si tu modifies l'un, modifie l'autre à l'identique.
/// Seuls les COMMENTAIRES peuvent différer : la structure, elle, doit rester
/// au champ près, sinon le widget ne sait plus décoder l'état et l'île
/// s'affiche vide sans qu'aucune erreur ne soit levée.
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
