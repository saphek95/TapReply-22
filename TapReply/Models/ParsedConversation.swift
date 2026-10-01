import Foundation

/// Résultat structuré du parsing OCR d'une capture d'écran de conversation.
struct ParsedConversation {
    struct Message {
        enum Sender: String { case them, me }
        let sender: Sender
        let text: String
    }

    /// État du champ de saisie détecté par le parser (DÉTERMINISTE — l'IA n'a
    /// plus à deviner si l'utilisateur a écrit un brouillon ou non) :
    /// - emptyWithPlaceholder : la barre de saisie est VIDE, son placeholder
    ///   (« Votre message », « iMessage »…) a été vu et filtré → PAS de brouillon,
    ///   il faut répondre au dernier message réel.
    /// - hasDraft : du texte utilisateur est présent dans la zone de composition
    ///   → c'est un brouillon à transformer.
    /// - none : aucune zone de composition détectée (cas rare : capture recadrée,
    ///   plein écran, mail…) → l'IA se fie au contenu seul.
    enum InputFieldState: String {
        case emptyWithPlaceholder = "empty_with_placeholder"
        case hasDraft = "has_draft"
        case none = "none"
    }

    var messages: [Message]
    /// Brouillon détecté dans la zone de composition (la pépite : pré-rédaction)
    var draft: String?
    /// État du champ de saisie (voir InputFieldState)
    var inputFieldState: InputFieldState = .none
    /// App source devinée ("whatsapp", "mail", "imessage", "unknown"…)
    var appSource: String
    /// V1.1.2-debug — OCR BRUT (chaque observation Vision : texte + position
    /// normalisée x,y). Uniquement utilisé en mode debug pour comparer
    /// l'écran réel à ce que le parser a compris. Jamais stocké ailleurs
    /// que dans le log de debug.
    var rawOCR: [String] = []
    /// Vrai si le parsing semble exploitable
    var isUsable: Bool { !messages.isEmpty || (draft?.isEmpty == false) }
}
