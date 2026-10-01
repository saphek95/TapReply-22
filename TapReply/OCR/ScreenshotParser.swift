import Foundation
import Vision
import UIKit

/// Parser OCR on-device : transforme une capture d'écran de conversation
/// en conversation structurée (bulles gauche/droite + brouillon + app source).
/// LA CAPTURE NE QUITTE JAMAIS L'APPAREIL — seul le texte extrait part au backend.
enum ScreenshotParser {

    // MARK: - Types internes

    private struct Obs {
        let text: String
        let box: CGRect // normalisé, origine EN BAS à gauche (convention Vision)
        var midY: CGFloat { box.midY }
        var minX: CGFloat { box.minX }
        var maxX: CGFloat { box.maxX }
    }

    enum ParserError: Error, LocalizedError {
        case invalidImage
        case noText

        var errorDescription: String? {
            switch self {
            case .invalidImage: return String(localized: "Image illisible.")
            case .noText: return String(localized: "Aucun texte détecté sur la capture. Assure-toi que la conversation est visible à l'écran.")
            }
        }
    }

    // MARK: - API

    static func parse(imageData: Data) throws -> ParsedConversation {
        guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
            throw ParserError.invalidImage
        }
        return try parse(cgImage: cgImage)
    }

    // MARK: - Mode onboarding
    /// Vrai tant que l'onboarding (ou sa relecture) est actif : les essais
    /// capturent l'écran de TAPREPLY lui-même → traitement spécial.
    private static var isOnboardingActive: Bool {
        !UserDefaults.standard.bool(forKey: SettingsKeys.onboardingDone)
    }

    /// Textes d'interface de TapReply visibles sur les écrans d'essai
    /// (onboarding ET onglet Essai). Résolus À L'EXÉCUTION (donc dans la langue
    /// de l'UI) puis FILTRÉS de l'OCR en permanence : sans ça, l'IA les prenait
    /// pour des messages ou un brouillon (« Colle ta réponse ici »… — bug
    /// testeurs 21/08). ⚠️ À TENIR À JOUR quand un libellé de ces écrans change :
    /// un texte oublié ici part au backend comme s'il était un vrai message.
    private static var tapReplyUIStrings: [String] {
        [
            // Onglet Essai (Playground)
            String(localized: "En attente de ton Triple Tap…"),
            String(localized: "En attente de ton Action Button…"),
            String(localized: "Essai"),
            String(localized: "Conversation de test"),
            String(localized: "Teste ton double tap"),
            String(localized: "Une conversation pour de faux : personne ne reçoit rien."),
            String(localized: "Double-tape au dos de l'iPhone, sur cet écran"),
            String(localized: "Le génie lit la conversation et copie sa réponse"),
            String(localized: "Colle-la dans le champ en bas, puis envoie"),
            String(localized: "Si ça marche ici, ça marchera dans toutes tes apps."),
            String(localized: "En attente de ton double tap"),
            String(localized: "Le génie s'active…"),
            String(localized: "Réponse copiée : colle-la dans le champ."),
            String(localized: "conversation de test"),
            String(localized: "Prêt"),
            // Mini-onboarding d'un geste secondaire (TriggerSetupFlow) : c'est
            // CET écran que le raccourci capture pendant l'essai final, donc
            // tous ses textes doivent être filtrés.
            String(localized: "Fais le geste maintenant, ici"),
            String(localized: "Trois tapes fermes au dos de l'iPhone."),
            String(localized: "Presse le bouton Action sur le côté de l'iPhone."),
            String(localized: "Geste reçu, génération en cours…"),
            String(localized: "Le génie lit la conversation."),
            String(localized: "Étape 3 sur 3 · l'essai"),
            // ⚠️ Les TROIS BULLES de la conversation d'essai ne sont
            // volontairement PAS filtrées : c'est le contenu que l'IA doit
            // lire pour générer une réponse. Les filtrer aurait vidé la
            // capture et fait échouer l'essai (« rien d'exploitable »).
            String(localized: "Message envoyé"),
            String(localized: "Configuration incomplète"),
            String(localized: "Écris une idée (optionnel)…"),
            String(localized: "Copier et fermer"),
            String(localized: "Colle-la ensuite dans le champ de la conversation, puis envoie 👆"),
            String(localized: "Ta réponse"),
            String(localized: "Fermer"),
            // Onglets de la tab bar
            String(localized: "Accueil"),
            String(localized: "Studio"),
            String(localized: "Réglages"),
            // Écrans d'essai de l'onboarding
            String(localized: "Colle ta réponse ici…"),
            String(localized: "Coller"),
            String(localized: "Réponse prête ✓ copiée"),
            String(localized: "Analyse de ta conversation…"),
            String(localized: "📋 Copiée : tu n'as plus qu'à COLLER en bas ⬇️"),
            // Onboarding v3 (TapTap) — chrome des écrans où un double tap réel peut
            // survenir (le geste s'active pendant l'acte 5). Les bulles de la
            // conversation géante ne sont PAS filtrées : elles sont du contenu.
            String(localized: "Démonstration"),
            String(localized: "Brouillon · pas envoyé"),
            String(localized: "ÉTAPE 1 SUR 3"),
            String(localized: "ÉTAPE 2 SUR 3"),
            String(localized: "ÉTAPE 3 SUR 3 · AVANT TON PREMIER TAP"),
            String(localized: "Tu confirmes ?"),
            String(localized: "Revoir"),
            String(localized: "Montre-moi"),
            String(localized: "Tape deux fois sur le dos"),
            String(localized: "Répondre « Toujours autoriser »"),
            // Écrans d'essai capturés — bandeaux d'alerte du terrain d'essai
            String(localized: "Back Tap"),
            String(localized: "brouillon amplifié"),
            String(localized: "consentement"),
            String(localized: "raccourci"),
            // Mini-onboarding d'un geste secondaire (TriggerSetupFlow) — chrome des 3 étapes.
            // ⚠️ Les TROIS BULLES de sa conversation d'essai ne sont PAS filtrées
            // (« Tu es dispo pour un appel demain matin ? » etc.) : c'est le
            // contenu que l'IA doit lire pour générer la réponse de l'essai.
            String(localized: "Étape 1 sur 3 · le raccourci"),
            String(localized: "Étape 2 sur 3 · le geste"),
            String(localized: "Le raccourci est ajouté"),
            String(localized: "Appuie sur « Ajouter ce raccourci »"),
            String(localized: "L'app Raccourcis s'ouvre sur la fiche du raccourci."),
            String(localized: "Le bouton en bas t'y emmène directement."),
            String(localized: "Revenir au raccourci"),
            String(localized: "On passe à l'association au geste."),
            String(localized: "C'est associé, on teste"),
            String(localized: "Cette association se fait dans les Réglages d'iOS : aucune app ne peut la faire à ta place."),
            String(localized: "Ouvre les Réglages iOS"),
            String(localized: "Ouvrir Réglages"),
            String(localized: "Suis le chemin ci-dessus"),
            String(localized: "Tout en bas de la page « Toucher »."),
            String(localized: "Puis reviens : on teste tout de suite."),
            String(localized: "Reviens ici"),
            String(localized: "Touche le bouton ci-dessus"),
            String(localized: "Le geste ne répond pas : voir l'aide"),
            String(localized: "C'est prêt"),
            String(localized: "Réponse générée : déjà dans ton presse-papiers"),
            String(localized: "La réponse est dans ton presse-papiers."),
            String(localized: "Copier à nouveau"),
            String(localized: "Copié"),
            String(localized: "Terminer"),
            String(localized: "Tu as maintenant deux tons sous la main, chacun sur son geste. Change-les quand tu veux depuis le Studio."),
            // Parcours d'activation d'un geste secondaire, refonte du 30/08 :
            // fiche Raccourcis reconstituée + chemin Réglages redessiné.
            // Ces libellés reproduisent des lignes des Réglages d'iOS, donc
            // l'OCR les lit comme du texte ordinaire s'ils ne sont pas filtrés.
            String(localized: "Accessibilité"),
            String(localized: "Ajouter le raccourci"),
            String(localized: "Désactivé"),
            String(localized: "Fais défiler les options du bouton jusqu'à « Raccourci »."),
            String(localized: "Ouvrir l'app Raccourcis"),
            String(localized: "Touche la carte ci-dessus"),
            String(localized: "Toucher"),
            String(localized: "Toucher deux fois"),
            String(localized: "Toucher le dos de l'appareil"),
            String(localized: "Toucher trois fois"),
            String(localized: "fais défiler jusqu'en bas de la liste"),
            String(localized: "fais défiler les modes jusqu'à « Raccourci »"),
            String(localized: "touche « Choisir un raccourci »"),
            // Écran « Toujours autoriser » de l'onboarding (30/08). Il reproduit
            // une boîte de dialogue d'iOS : si l'utilisateur double-tape ici,
            // l'OCR lirait ces libellés comme des messages.
            String(localized: "AVANT TON PREMIER TAP"),
            String(localized: "Autoriser une fois"),
            String(localized: "C'est la seule étape où je ne peux rien faire à ta place."),
            String(localized: "Compris, toujours autoriser"),
            String(localized: "Pour lire la capture et écrire ta réponse."),
            String(localized: "Recopier"),
            String(localized: "Réponds « Toujours autoriser »"),
            String(localized: "Toujours autoriser"),
            String(localized: "« Autoriser une fois » et iOS te reposera la question à chaque réponse."),
            String(localized: "« Raccourcis » souhaite utiliser TapReply"),
            String(localized: "À ton premier double tap, iOS va demander deux ou trois autorisations. Choisis « Toujours autoriser » chaque fois."),
        ]
    }

    /// Normalisation robuste pour comparer un fragment OCR à un texte d'UI
    /// (l'OCR coupe les phrases en plusieurs observations et abîme la ponctuation).
    private static func normalizeForUIMatch(_ s: String) -> String {
        let mapped: [Character] = s.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(mapped)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// EXCLUSIONS VOLONTAIRES — ne JAMAIS ajouter au filtre ci-dessus :
    /// « Parfait » et « Oups » apparaissent bien dans notre interface, mais ce
    /// sont aussi des messages qu'un humain écrit vraiment. Les filtrer ferait
    /// disparaître un vrai message de la conversation de l'utilisateur, ce qui
    /// est pire que laisser passer un mot de chrome pendant un essai.
    /// Règle générale : on ne filtre que ce qu'un interlocuteur n'écrirait pas.
    ///
    /// Un fragment OCR est-il un texte d'interface TapReply (écrans d'essai) ?
    /// Prudence sur les correspondances partielles : un mot court du brouillon
    /// de l'utilisateur (« pizza ») ne doit JAMAIS être avalé parce qu'il
    /// apparaît dans une consigne — d'où les seuils de longueur.
    private static func isTapReplyUIText(_ text: String, uiStrings: [String]) -> Bool {
        let norm = normalizeForUIMatch(text)
        guard !norm.isEmpty else { return true }
        for ui in uiStrings {
            let uiNorm = normalizeForUIMatch(ui)
            // Correspondance exacte (boutons courts : « Coller », « Fermer »…)
            if norm == uiNorm { return true }
            guard uiNorm.count >= 12 else { continue }
            // Fragment d'une consigne longue (l'OCR coupe les phrases en morceaux)
            if norm.count >= 8 && uiNorm.contains(norm) { return true }
            // Consigne longue reconstituée avec un peu de bruit autour
            if norm.contains(uiNorm) { return true }
        }
        return false
    }

    static func parse(cgImage: CGImage) throws -> ParsedConversation {
        // 1. OCR Vision (.accurate, fr + en)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let raw: [Obs] = (request.results ?? []).compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Obs(text: text, box: obs.boundingBox)
        }

        guard !raw.isEmpty else { throw ParserError.noText }

        // V1.1.2-debug — capture de l'OCR BRUT (texte + position) AVANT tout
        // filtrage, pour le mode debug (comparaison écran / transcription).
        // Format compact : « [x,y] texte » par ligne.
        let rawOCRLines = raw.map { o in
            String(format: "[%.2f,%.2f] %@", o.box.midX, 1.0 - o.box.midY, o.text)
        }

        // 2. Filtrage du bruit UI
        //    - barre de statut (haut 6% : heure, batterie)
        //    - horodatages / accusés de lecture / labels systèmes
        let noisePatterns: [String] = [
            #"^\d{1,2}:\d{2}$"#,                      // 14:32
            #"^\d{1,2}:\d{2}\s?(AM|PM)$"#,
            #"^(Aujourd'hui|Hier|Today|Yesterday)"#,
            #"^(lun|mar|mer|jeu|ven|sam|dim|mon|tue|wed|thu|fri|sat|sun)\.?\s"#,
            #"^\d{1,3}\s?%$"#,                         // batterie
            #"^(✓|✓✓|√√?)$"#,
            #"^(Distribué|Delivered|Lu|Read|Seen|Vu)$"#,
            #"^(en ligne|online|typing|écrit|écrit…)\.{0,3}$"#,
            // Instagram / Messenger / réseaux sociaux
            #"^(Actif|Active)\s?(ve)?\s?\(?(il y a|aujourd'hui|now|today).*$"#,
            #"^(Vu par|Seen by).*$"#,
            #"^(Appuyez pour|Tap to).*$"#,
            #"^(Story|Storys|Stories|Réel|Reels?)$"#,
            #"^(Nouveau message|New message)s?$"#,
            // Métadonnées d'état supplémentaires (toutes apps)
            #"^(Envoyé|Sent|Reçu|Received|Modifié|Edited|Épinglé|Pinned)$"#,
            #"^(est en train d'écrire|is typing|typing)\.{0,3}$"#,
            #"^(Aujourd'hui à|Hier à|Today at|Yesterday at)\s.*$"#,
            #"^(Rép(ondre)?|Reply|Réagir|React|Transférer|Forward)$"#,
            #"^(En ligne|Online|Hors ligne|Offline)$"#,
            #"^(vu|lu|seen|read)\s?\d{0,2}:?\d{0,2}$"#,
            // Boutons/onglets d'interface fréquents dans les captures
            #"^(Appels?|Calls?|Statut|Status|Communautés|Communities|Discussions?|Chats?|Mise?s? à jour|Updates)$"#,
            #"^(Accueil|Home|Recherche|Search|Profil|Profile|Notifications?)$"#,
        ]
        let noiseRegexes = noisePatterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

        func isNoise(_ t: String) -> Bool {
            let range = NSRange(t.startIndex..., in: t)
            return noiseRegexes.contains { $0.firstMatch(in: t, options: [], range: range) != nil }
        }

        var obs = raw.filter { o in
            o.midY < 0.94 &&           // barre de statut / titre
            !isNoise(o.text)
        }

        // 2bis. Textes d'interface de TAPREPLY (onboarding + onglet Essai) :
        // filtrés EN PERMANENCE — si l'utilisateur double-tape sur un écran de
        // l'app, seules les bulles de la conversation d'essai (et son brouillon)
        // doivent atteindre l'IA, jamais les boutons ni les consignes.
        let onboarding = isOnboardingActive
        let uiStrings = tapReplyUIStrings
        obs.removeAll { isTapReplyUIText($0.text, uiStrings: uiStrings) }

        // 3. Détection du clavier (si visible) : forte densité de textes très courts
        //    (touches AZERTY) dans le bas de l'écran.
        let bottomZone = obs.filter { $0.midY < 0.40 }
        let shortKeys = bottomZone.filter { $0.text.count <= 2 }
        let keyboardVisible = shortKeys.count >= 8
        var keyboardTop: CGFloat = 0
        if keyboardVisible {
            keyboardTop = shortKeys.map { $0.box.maxY }.max() ?? 0.35
            // Retirer les touches du clavier + suggestions de la barre prédictive
            obs.removeAll { $0.midY < keyboardTop && $0.text.count <= 14 }
        }

        // 4. Détection du BROUILLON (pré-rédaction) : texte dans la zone de composition,
        //    c.-à-d. la bande juste au-dessus du clavier (ou tout en bas si pas de clavier).
        let composeBandBottom = keyboardVisible ? keyboardTop : 0.02
        // ONBOARDING : le champ de saisie de l'écran d'essai est plus haut que
        // dans une vraie app (boutons de pied de page en dessous) → la bande de
        // composition remonte jusqu'à 30 % de l'écran. Tout texte utilisateur
        // qui s'y trouve est le BROUILLON de l'essai 2 (« pizza »).
        let composeBandTop = keyboardVisible ? keyboardTop + 0.10 : (onboarding ? 0.30 : 0.12)
        // ⚠️ Placeholders des champs de saisie de TOUTES les apps (FR + EN).
        // S'ils passent, ils deviennent un faux « brouillon » et déroutent l'IA
        // (bug Instagram « Votre message… » constaté le 18/08 — catalogue
        // largement étendu le 21/08 : iMessage, WhatsApp, Instagram, Messenger,
        // Snapchat, Telegram, Tinder, Hinge, Bumble, LinkedIn, X, Discord).
        let placeholders = [
            // Génériques FR
            "message", "votre message", "ton message", "un message",
            "écrire un message", "écrivez un message", "écris un message",
            "envoyer un message", "envoie un message", "envoyez un message",
            "nouveau message", "saisis un message", "saisissez un message",
            "tape un message", "tapez un message", "rédige un message",
            "rédigez un message", "écris quelque chose", "commencez à écrire",
            "commence à écrire", "message texte", "répondre", "répondre à",
            "réagir", "ajouter un commentaire", "commenter", "rechercher",
            // Génériques EN
            "type a message", "type your message", "text message", "send a message",
            "send message", "write a message", "write something", "your message",
            "new message", "start typing", "start a message", "reply", "reply to",
            "add a comment", "comment", "search", "message…",
            // Spécifiques par app
            "imessage",                                  // Messages (iMessage)
            "sms", "mms",                                // Messages (fallback réseau)
            "aa",                                        // Messenger (champ vide)
            "envoie un chat", "send a chat", "envoyer un chat", // Snapchat
            "chat",                                      // Snapchat / divers
            "sticker", "stickers", "gif", "gifs",        // barres d'outils
            "commencer un message", "start a chat",      // X / Twitter DM
            "message @",                                 // Discord (préfixe géré plus bas)
            "dites bonjour", "say hello", "dis bonjour", // Tinder/Hinge nouveaux matchs
            "envoyer un premier message", "send a first message"
        ]
        // Préfixes de placeholder dynamiques (« Message #général », « Écris à Léa »,
        // « Message to John », « Répondre à … ») — la fin varie selon le contact.
        let placeholderPrefixes = [
            "message #", "message à ", "message to ", "message @",
            "écris à ", "écrire à ", "write to ", "reply to ", "répondre à "
        ]

        func isPlaceholderText(_ rawText: String) -> Bool {
            // Normalisation : minuscules, sans « … » / « . » finaux
            var lower = rawText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            while lower.hasSuffix("…") || lower.hasSuffix(".") {
                lower = String(lower.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            if placeholders.contains(lower) { return true }
            return placeholderPrefixes.contains { lower.hasPrefix($0) }
        }

        var draftParts: [String] = []
        // V1.1.2 — le parser SAIT si la barre de saisie était vide (placeholder
        // visible et filtré) ou remplie (brouillon). Cette information part au
        // backend : l'IA n'a plus à deviner (bug « Votre message » pris pour un
        // brouillon / réponse au placeholder au lieu du message du dessus).
        var sawPlaceholderInCompose = false
        obs.removeAll { o in
            guard o.midY >= composeBandBottom && o.midY <= composeBandTop else { return false }
            if isPlaceholderText(o.text) {
                sawPlaceholderInCompose = true
            } else if o.text.count > 1 {
                draftParts.append(o.text)
            }
            return true // dans tous les cas on retire la zone de composition des bulles
        }
        // Ordre haut → bas (Vision : y décroissant = vers le bas)
        let draft = draftParts.isEmpty ? nil : draftParts.joined(separator: " ")
        let inputFieldState: ParsedConversation.InputFieldState =
            draft != nil ? .hasDraft
            : (sawPlaceholderInCompose ? .emptyWithPlaceholder
            : .none)

        // 5. Clustering des bulles : tri haut → bas, regroupement par proximité verticale + côté
        let sorted = obs.sorted { $0.midY > $1.midY } // haut d'abord
        var messages: [ParsedConversation.Message] = []
        var currentTexts: [String] = []
        var currentSide: ParsedConversation.Message.Sender? = nil
        var lastBottom: CGFloat? = nil

        func side(of o: Obs) -> ParsedConversation.Message.Sender {
            // Bulle alignée à droite = utilisateur ; sinon interlocuteur.
            // (Un document plein-écran type mail => tout "them", ce qui est correct.)
            if o.minX > 0.30 && o.maxX > 0.82 { return .me }
            return .them
        }

        func flush() {
            guard !currentTexts.isEmpty, let s = currentSide else { return }
            let text = currentTexts.joined(separator: " ")
            if text.count > 1 {
                messages.append(.init(sender: s, text: text))
            }
            currentTexts = []
            currentSide = nil
        }

        for o in sorted {
            let s = side(of: o)
            let gap = lastBottom.map { $0 - o.box.maxY } ?? 0
            let newBlock = currentSide != s || gap > 0.022
            if newBlock { flush() }
            currentSide = s
            currentTexts.append(o.text)
            lastBottom = o.box.minY
        }
        flush()

        // 6. Heuristique app source (indicatif uniquement)
        let allText = raw.map { $0.text.lowercased() }.joined(separator: " ")
        let appSource: String
        if onboarding {
            // Écran d'essai de TapReply : le serveur adapte sa consigne.
            appSource = "onboarding"
        } else if allText.contains("objet :") || allText.contains("subject:") || allText.contains("boîte de réception") || allText.contains("inbox") {
            appSource = "mail"
        } else if allText.contains("votre message") || allText.contains("actif il y a")
                    || allText.contains("active il y a") || allText.contains("instagram")
                    || allText.contains("a partagé une publication") || allText.contains("a partagé un reel") {
            appSource = "instagram"
        } else if allText.contains("messenger") {
            appSource = "messenger"
        } else if allText.contains("linkedin") || allText.contains("inmail") {
            appSource = "linkedin"
        } else if allText.contains("envoie un chat") || allText.contains("send a chat") || allText.contains("snapchat") {
            appSource = "snapchat"
        } else if allText.contains("il vous reste 24 h") || allText.contains("vous avez matché")
                    || allText.contains("you matched") || allText.contains("tinder") {
            appSource = "tinder"
        } else if allText.contains("message #") || allText.contains("discord") {
            appSource = "discord"
        } else if allText.contains("telegram") || allText.contains("dernière connexion") || allText.contains("last seen recently") {
            appSource = "telegram"
        } else if allText.contains("imessage") || allText.contains("message texte") {
            appSource = "imessage"
        } else if allText.contains("en ligne") || allText.contains("last seen") || allText.contains("vu à") {
            appSource = "whatsapp"
        } else {
            appSource = "unknown"
        }

        return ParsedConversation(messages: messages, draft: draft, inputFieldState: inputFieldState, appSource: appSource, rawOCR: rawOCRLines)
    }
}
