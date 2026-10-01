import Foundation

/// Client HTTP vers la Edge Function Supabase (qui appelle OpenRouter).
/// Seul du TEXTE transite — jamais l'image.
enum GenerationClient {

    struct RequestBody: Encodable {
        struct Msg: Encodable {
            let sender: String
            let text: String
        }
        let messages: [Msg]
        let draft: String?
        let tone: String
        /// Instruction d'un ton PERSONNALISÉ (Studio) — remplace le préréglage côté serveur
        let customToneInstruction: String?
        let targetLocale: String?
        let appSource: String?
        /// État du champ de saisie vu par le parser (V1.1.2) :
        /// "empty_with_placeholder" (barre vide, placeholder filtré) /
        /// "has_draft" (brouillon présent) / "none" (zone non détectée).
        /// Information DÉTERMINISTE : le serveur n'a plus à deviner si le
        /// « dernier message » est un placeholder ou un vrai brouillon.
        let inputFieldState: String?
        /// Mode debug TEMPORAIRE (V1.1.2) : true uniquement quand le panneau
        /// Diagnostic est affiché dans Réglages (5 taps sur Version). Le serveur
        /// logge alors le prompt complet dans les logs de l'Edge Function ET
        /// écrit la ligne complète dans le Google Sheet de debug.
        let debugLog: Bool?
        /// OCR brut (texte + position par observation Vision) — UNIQUEMENT en
        /// mode debug, pour comparer l'écran réel à la sortie du parser.
        let rawOCR: [String]?
        /// ID anonyme RevenueCat — le serveur vérifie abonnement/crédits et débite
        let appUserId: String?
    }

    struct ResponseBody: Decodable {
        let reply: String?
        let error: String?
        let detail: String?
    }

    enum GenerationError: Error, LocalizedError {
        case network(String)
        case server(String)
        case emptyReply
        case noCredits(String)
        case rateLimited
        case unavailable
        case notReady

        var errorDescription: String? {
            switch self {
            case .network: return String(localized: "Connexion impossible. Vérifie ta connexion internet.")
            case .server: return String(localized: "La génération a échoué, aucun crédit n'a été décompté. Réessaie.")
            case .emptyReply: return String(localized: "Aucune réponse générée. Réessaie.")
            case .noCredits(let m): return m
            case .rateLimited: return String(localized: "Trop de demandes d'affilée. Patiente quelques secondes.")
            case .unavailable: return String(localized: "Service momentanément indisponible. Réessaie dans quelques minutes.")
            case .notReady: return String(localized: "TapReply s'initialise. Ouvre l'app une fois puis réessaie.")
            }
        }
    }

    /// Requête de base (en-têtes communs).
    static func baseRequest(timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: Config.backendURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// BOOTSTRAP des crédits de bienvenue, appelé au lancement (PurchaseService). Le serveur octroie les 10 crédits
    /// UNE seule fois par identifiant (et par iPhone si DeviceCheck est configuré). true = le serveur a répondu 200.
    @discardableResult
    static func bootstrapWelcomeCredits(appUserId: String) async -> Bool {
        struct Body: Encodable { let action: String; let appUserId: String; let deviceToken: String? }
        var request = baseRequest(timeout: 15)
        let token = await DeviceToken.current()
        request.httpBody = try? JSONEncoder().encode(Body(action: "bootstrap", appUserId: appUserId, deviceToken: token))
        guard let result = try? await URLSession.shared.data(for: request),
              let http = result.1 as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    /// - Parameter toneId: l'id du ton À EMPLOYER, quand ce n'est pas celui du Double Tap : rawValue d'un
    ///   préréglage ou UUID d'un ton personnalisé (Triple Tap, bouton Action). nil = le réglage du Double Tap.
    static func generate(from parsed: ParsedConversation,
                         tone: Tone? = nil,
                         toneId: String? = nil) async throws -> String {
        // RÉSOLUTION DU TON : la valeur stockée est soit un Tone.rawValue, soit l'UUID d'un ton personnalisé.
        let storedRaw = toneId
            ?? UserDefaults.standard.string(forKey: SettingsKeys.defaultTone)
            ?? Tone.auto.rawValue
        let customTone = tone == nil ? CustomToneStore.tone(withID: storedRaw) : nil
        let effectiveTone = tone ?? (customTone != nil ? .auto : (Tone(rawValue: storedRaw) ?? .auto))
        // 0 langue = auto (nil) · 1 langue = forcée · 2+ = l'IA choisit parmi elles
        let locales = AppSettings.replyLocales

        // Sans identité, le serveur refuse (401) : inutile d'appeler.
        guard let uid = await PurchaseService.appUserID else { throw GenerationError.notReady }

        // Debug serveur : builds DEBUG / TestFlight uniquement (jamais dans la version App Store).
        let isDebug = BuildEnv.allowsDiagnostics && UserDefaults.standard.bool(forKey: "debugLogEnabled")
        let body = RequestBody(
            messages: parsed.messages.map { .init(sender: $0.sender.rawValue, text: $0.text) },
            draft: parsed.draft,
            // « fact » n'existe pas côté serveur : il part comme « auto » + son instruction (Tone.presetInstruction).
            tone: effectiveTone.backendValue,
            customToneInstruction: customTone?.instruction ?? effectiveTone.presetInstruction,
            targetLocale: locales.isEmpty ? nil : locales.joined(separator: ","),
            appSource: parsed.appSource,
            inputFieldState: parsed.inputFieldState.rawValue,
            debugLog: isDebug ? true : nil,
            rawOCR: isDebug ? parsed.rawOCR : nil,
            appUserId: uid
        )
        return Self.withoutEmDash(try await send(body, timeout: 25))
    }

    /// Envoi + interprétation HTTP COMMUNE (double tap, test de ton du Studio). Les messages affichés sont ceux
    /// de l'app (traduits), jamais le texte brut du serveur ni un détail technique.
    static func send<B: Encodable>(_ body: B, timeout: TimeInterval) async throws -> String {
        var request = baseRequest(timeout: timeout)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GenerationError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw GenerationError.network("no response") }
        let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data)

        switch http.statusCode {
        case 200:
            guard let reply = decoded?.reply, !reply.isEmpty else { throw GenerationError.emptyReply }
            // Le serveur vient de débiter : l'Accueil doit montrer le vrai solde.
            Task { @MainActor in await PurchaseService.shared.refreshCredits() }
            return reply
        case 402:
            // 402 = plus de crédits, ou usage raisonnable du jour atteint (décision SERVEUR)
            if decoded?.error == "fair_use" {
                throw GenerationError.noCredits(String(localized: "Beaucoup de demandes aujourd'hui. Fais une petite pause, ça repart demain."))
            }
            throw GenerationError.noCredits(String(localized: "Plus de réponses gratuites. Passe à Pro ou prends un pack pour continuer."))
        case 401: throw GenerationError.notReady
        case 429: throw GenerationError.rateLimited
        case 503: throw GenerationError.unavailable
        default:  throw GenerationError.server(decoded?.error ?? "HTTP \(http.statusCode)")
        }
    }

    /// Aucun tiret cadratin dans ce que l'app affiche ou copie (le prompt serveur l'interdit déjà : filet de
    /// sécurité côté app). « a — b » devient « a, b » ; un tiret isolé devient une virgule.
    static func withoutEmDash(_ text: String) -> String {
        var t = text.replacingOccurrences(of: " — ", with: ", ")
        t = t.replacingOccurrences(of: "— ", with: ", ").replacingOccurrences(of: " —", with: ",")
        return t.replacingOccurrences(of: "—", with: ", ")
    }
}
