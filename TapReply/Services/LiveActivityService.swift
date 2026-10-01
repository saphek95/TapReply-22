import Foundation
import ActivityKit

/// Gestion de la Live Activity (Dynamic Island / écran verrouillé).
///
/// ⚠️ Règle d'or apprise sur le terrain : `end()` retire IMMÉDIATEMENT l'activité
/// de la Dynamic Island (elle ne survit que dans le centre de notifications).
/// Pour afficher la réponse DANS l'île, il faut donc `update()` (l'île reste vivante),
/// puis clôturer en différé / au prochain lancement.
enum LiveActivityService {

    private static var current: Activity<ReplyActivityAttributes>?

    /// Thème au moment du run : couleur d'accent + mascotte de l'utilisateur
    /// (l'île et la carte d'écran verrouillé se peignent avec).
    private static var themeAccent: Int { HZTheme.shared.accentHex }
    private static var themeAvatar: Int {
        UserDefaults.standard.integer(forKey: SettingsKeys.avatarColorIndex)
    }

    /// La mascotte affichée dans l'île : le TAPTAP DU TON utilisé (Classique, Pro, Rigolo, Charmeur, Fact Checker,
    /// ou la pose d'un ton perso), à la COULEUR DE TAPTAP de l'utilisateur — PNG détourés 240 px du widget
    /// (`<Ton>_M<i>` / `TTPose<n>_M<i>`), sans ombre ni blanc parasite (fond noir de l'île).
    private static var toneMascotAsset: String { "AvatarM\(themeAvatar)" }
    private static func mascotAsset(toneRaw: String?) -> String {
        let i = themeAvatar
        guard let raw = toneRaw, !raw.isEmpty else { return "AvatarM\(i)" }
        if let custom = CustomToneStore.tone(withID: raw) {
            if let pose = custom.mascotIndex { return "TTPose\(max(0, min(pose, MascotCatalog.count - 1)))_M\(i)" }
            return "AvatarM\(i)"
        }
        if let t = Tone(rawValue: raw), let asset = ToneItem.preset(t).artworkAsset { return "\(asset)_M\(i)" }
        return "AvatarM\(i)"
    }

    /// Vrai si une Live Activity est en cours pour ce run (sert à sauter la notification).
    static var isActive: Bool { current != nil }

    // MARK: - CHOIX DU CANAL DE RESTITUTION
    //
    // CE QUE LE SYSTÈME FAIT DÉJÀ, ET QU'IL FAUT LAISSER FAIRE
    // `ActivityConfiguration` définit DEUX présentations : celle de la Dynamic
    // Island, et celle de l'écran verrouillé (`LockScreenView`). Sur un iPhone
    // SANS île, une mise à jour portant un `alertConfiguration` affiche cette
    // seconde présentation EN BANNIÈRE — c'est la documentation ActivityKit :
    // « display the expanded presentation on devices that support the Dynamic
    // Island or a banner on devices that don't support it ».
    //
    // Autrement dit : la bannière de marque EXISTE DÉJÀ (LockScreenView, fond
    // blanc, encre, accents de l'app) et elle est bien plus belle qu'une
    // notification nue. Router ces appareils vers la notification par défaut
    // reviendrait à jeter un design qu'on possède.
    //
    // POURQUOI UN RÉGLAGE PLUTÔT QU'UNE DÉTECTION AUTOMATIQUE
    // Aucune API ne dit si la bannière a RÉELLEMENT été vue. Impossible donc de
    // basculer « seulement quand ça ne marche pas ». Et envoyer les deux canaux
    // ferait un doublon sonore à chaque réponse sur les iPhone avec île.
    // On laisse donc le choix : par défaut le système décide (île ou bannière),
    // et quiconque ne voit rien bascule sur la notification en un tap depuis
    // les Réglages. C'est exactement la manœuvre que des testeurs faisaient à
    // la main en désactivant les activités en direct — sauf qu'ici elle ne
    // casse plus rien d'autre.
    //
    // `DeviceCapabilities.hasDynamicIsland` ne sert donc PAS à router : il sert
    // à écrire dans le journal quelle présentation s'applique, pour qu'un
    // « je ne vois rien » devienne instruisable depuis le panneau Diagnostic.

    /// Le canal retenu : "auto" (défaut), "banner" ou "notification".
    private static var channel: String {
        UserDefaults.standard.string(forKey: SettingsKeys.replyChannel) ?? "auto"
    }

    /// Faut-il passer par la notification pour ce run ?
    ///
    /// LE DÉFAUT EST CELUI QUI S'AFFICHE À COUP SÛR, PAS LE PLUS BEAU.
    /// Sur un iPhone avec île, l'île s'affiche par-dessus l'app : rien à
    /// arbitrer. Sur un iPhone sans île, la documentation ActivityKit annonce
    /// une BANNIÈRE, mais elle ne dit pas si cette bannière apparaît par-dessus
    /// une autre app ou seulement sur l'écran verrouillé — et c'est justement
    /// dans une autre app que le geste se fait. Tant que ce point n'est pas
    /// vérifié sur un appareil réel, le défaut va au canal dont on SAIT qu'il
    /// s'affiche : la notification. Un utilisateur qui préfère la bannière la
    /// choisit en un tap dans les Réglages.
    ///
    /// Le jour où la bannière est confirmée sur un iPhone sans île, il suffit
    /// de renvoyer `false` dans la branche "auto" pour inverser le défaut.
    private static var useNotification: Bool {
        switch channel {
        case "notification": return true
        case "banner":       return false
        default:             return !DeviceCapabilities.hasDynamicIsland
        }
    }

    /// Le repli notification, avec trace explicite quand il part dans le vide.
    /// - Parameter toneLabel: affiché en sous-titre — vérifier d'un coup d'œil
    ///   que le bon geste a joué le bon ton.
    private static func fallbackNotification(preview: String,
                                            destination: String? = nil,
                                            toneLabel: String? = nil) async {
        if await NotificationService.isAuthorized() {
            NotificationService.postReplyReady(preview: preview,
                                               destination: destination ?? "history",
                                               toneLabel: toneLabel)
        } else {
            // Sans autorisation, postReplyReady part dans le vide SANS erreur.
            // On le dit : c'est la seule façon de diagnostiquer « je ne reçois
            // rien » depuis le panneau Diagnostic.
            RunLog.log("❌ AUCUN CANAL DISPONIBLE : notifications non autorisées. La réponse est dans le presse-papiers, mais rien ne s'affiche. → Réglages iOS > TapReply > Notifications.")
        }
    }

    /// Trace la présentation attendue sur cet appareil (diagnostic uniquement).
    private static func logPresentation() {
        RunLog.log(DeviceCapabilities.hasDynamicIsland
                   ? "🏝️ Présentation attendue : Dynamic Island"
                   : "🎫 Bannière demandée sur un iPhone sans île. Si rien n'apparaît par-dessus l'app, repasser sur Notification dans les Réglages.")
    }

    /// Démarre l'activité en état « génération… » (nettoie d'abord les anciennes).
    static func startGenerating(tone: Tone) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            RunLog.log("⚠️ Live Activities désactivées (Réglages iOS > TapReply)")
            return
        }
        // Nettoyage : termine toute activité résiduelle d'un run précédent
        await cleanupAll()

        do {
            let attributes = ReplyActivityAttributes(startedAt: Date())
            let state = ReplyActivityAttributes.ContentState(
                status: "generating",
                reply: "",
                toneEmoji: tone.emoji,
                toneLabel: tone.label,
                accentHex: themeAccent,
                avatarIndex: themeAvatar,
                mascotAsset: "AvatarM\(themeAvatar)"
            )
            current = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            RunLog.log("🏝️ Live Activity démarrée")
        } catch {
            RunLog.log("⚠️ Live Activity refusée : \(error.localizedDescription)")
        }
    }

    /// V0.1.13 — SANS phase de chargement (demande Pierre 18/08 après-midi) :
    /// l'animation du raccourci suffit pendant la génération. L'île n'apparaît
    /// qu'au moment où la réponse est PRÊTE : démarrage direct en état « ready »
    /// + alerte (expansion avec l'aperçu, mécanique 0.1.8 validée), clôture 8 s.
    static func showReply(reply: String, tone: Tone, toneRaw: String? = nil) async {
        if useNotification {
            RunLog.log(channel == "auto"
                       ? "🔔 Pas de Dynamic Island → notification (canal par défaut sur cet iPhone)"
                       : "🔔 Canal choisi dans les Réglages : notification")
            await fallbackNotification(preview: reply, toneLabel: tone.label)
            return
        }
        logPresentation()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            RunLog.log("⚠️ Live Activities désactivées → notification de secours")
            await fallbackNotification(preview: reply, toneLabel: tone.label)
            return
        }
        await cleanupAll()

        let state = ReplyActivityAttributes.ContentState(
            status: "ready",
            // ActivityKit limite l'état à 4 Ko : une réponse très longue faisait échouer l'île en silence.
            reply: String(reply.prefix(1_500)),
            toneEmoji: tone.emoji,
            toneLabel: tone.label,
            accentHex: themeAccent,
            avatarIndex: themeAvatar,
            mascotAsset: mascotAsset(toneRaw: toneRaw)
        )
        do {
            let activity = try Activity.request(
                attributes: ReplyActivityAttributes(startedAt: Date()),
                content: .init(state: state, staleDate: Date().addingTimeInterval(300))
            )
            // L'alerte déclenche l'expansion proéminente avec l'aperçu du message
            // (même mécanique que la 0.1.8 validée — une seule alerte, un seul son).
            await activity.update(
                .init(state: state, staleDate: Date().addingTimeInterval(300)),
                alertConfiguration: AlertConfiguration(
                    title: "Réponse prête ✓ Copiée",
                    body: LocalizedStringResource(stringLiteral: String(reply.prefix(80))),
                    sound: .default
                )
            )
            RunLog.log("🏝️ Réponse affichée dans l'île (sans phase de chargement)")
            // Clôture à 8 s, .immediate : disparition totale, aucune trace.
            Task.detached {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        } catch {
            RunLog.log("⚠️ Île refusée (\(error.localizedDescription)) → notification de secours")
            await fallbackNotification(preview: reply, toneLabel: tone.label)
        }
        current = nil
    }

    /// V0.1.22 — Île d'ERREUR : depuis que la génération ne montre plus de barre,
    /// il n'existe AUCUNE île pendant le run → l'erreur doit démarrer sa propre
    /// activité (l'ancien fail() supposait une île déjà ouverte = erreur muette).
    /// Tap sur l'île d'erreur → l'app s'ouvre sur l'Accueil (correction en 1 tap).
    static func showError(message: String) async {
        if useNotification {
            await fallbackNotification(preview: "⚠️ \(message)", destination: "home")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            RunLog.log("⚠️ Live Activities désactivées → notification d'erreur")
            await fallbackNotification(preview: "⚠️ \(message)", destination: "home")
            return
        }
        await cleanupAll()
        let state = ReplyActivityAttributes.ContentState(
            status: "error",
            reply: message,
            toneEmoji: "⚠️",
            toneLabel: "",
            accentHex: themeAccent,
            avatarIndex: themeAvatar,
            mascotAsset: "AvatarM\(themeAvatar)"
        )
        do {
            let activity = try Activity.request(
                attributes: ReplyActivityAttributes(startedAt: Date()),
                content: .init(state: state, staleDate: Date().addingTimeInterval(120))
            )
            await activity.update(
                .init(state: state, staleDate: Date().addingTimeInterval(120)),
                alertConfiguration: AlertConfiguration(
                    title: "Ça n'a pas marché",
                    body: LocalizedStringResource(stringLiteral: String(message.prefix(80))),
                    sound: .default
                )
            )
            RunLog.log("🏝️ Erreur affichée dans l'île : \(message)")
            Task.detached {
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        } catch {
            RunLog.log("⚠️ Île d'erreur refusée → notification")
            await fallbackNotification(preview: "⚠️ \(message)", destination: "home")
        }
        current = nil
    }

    /// V0.2.3 — Île « CRÉDITS ÉPUISÉS » : état dédié (pas l'erreur générique).
    /// Message positif + invitation claire ; tap → paywall directement.
    static func showNoCredits(message: String) async {
        if useNotification {
            await fallbackNotification(preview: "✨ \(message)", destination: "paywall")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await fallbackNotification(preview: "✨ \(message)", destination: "paywall")
            return
        }
        await cleanupAll()
        let state = ReplyActivityAttributes.ContentState(
            status: "no_credits",
            reply: message,
            toneEmoji: "✨",
            toneLabel: "",
            accentHex: themeAccent,
            avatarIndex: themeAvatar,
            mascotAsset: "AvatarM\(themeAvatar)"
        )
        do {
            let activity = try Activity.request(
                attributes: ReplyActivityAttributes(startedAt: Date()),
                content: .init(state: state, staleDate: Date().addingTimeInterval(120))
            )
            await activity.update(
                .init(state: state, staleDate: Date().addingTimeInterval(120)),
                alertConfiguration: AlertConfiguration(
                    title: LocalizedStringResource("Plus de réponses gratuites"),
                    body: LocalizedStringResource(stringLiteral: String(message.prefix(80))),
                    sound: .default
                )
            )
            RunLog.log("🏝️ Île « crédits épuisés » affichée")
            Task.detached {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        } catch {
            await fallbackNotification(preview: "✨ \(message)", destination: "paywall")
        }
        current = nil
    }

    /// (Conservé pour référence/retour arrière — plus appelé depuis la V0.1.13.)
    /// Affiche la réponse DANS l'île (update, pas end !), puis clôture en différé.
    /// Comportement historique 0.1.8 validé sur appareil.
    static func complete(reply: String, tone: Tone) async {
        guard let activity = current else { return }
        let state = ReplyActivityAttributes.ContentState(
            status: "ready",
            reply: reply,
            toneEmoji: tone.emoji,
            toneLabel: tone.label,
            accentHex: themeAccent,
            avatarIndex: themeAvatar,
            mascotAsset: toneMascotAsset
        )
        // L'île reste vivante et bascule sur la réponse, avec une ALERTE d'activité :
        // l'île s'étend de façon proéminente pour montrer le message.
        await activity.update(
            .init(state: state, staleDate: Date().addingTimeInterval(300)),
            alertConfiguration: AlertConfiguration(
                title: "Réponse prête ✓ Copiée",
                body: LocalizedStringResource(stringLiteral: String(reply.prefix(80))),
                sound: .default
            )
        )
        RunLog.log("🏝️ Réponse affichée dans l'île")

        // Clôture à 8 s avec .immediate : disparition TOTALE (île + centre de
        // notifications, aucune trace). Le message reste dans l'Historique de l'app.
        Task.detached {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        current = nil
    }

    /// Affiche l'erreur dans l'île (update), clôture différée courte.
    static func fail(message: String) async {
        guard let activity = current else { return }
        let state = ReplyActivityAttributes.ContentState(
            status: "error",
            reply: message,
            toneEmoji: "⚠️",
            toneLabel: "",
            accentHex: themeAccent,
            avatarIndex: themeAvatar,
            mascotAsset: "AvatarM\(themeAvatar)"
        )
        await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(60)))
        Task.detached {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        current = nil
    }

    /// Termine toutes les activités TapReply encore ouvertes (avant chaque nouveau run).
    static func cleanupAll() async {
        for activity in Activity<ReplyActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }

    /// Au LANCEMENT de l'app : ne termine que les activités PÉRIMÉES (> 60 s).
    /// (cleanupAll au lancement tuait une île toute fraîche quand l'utilisateur
    /// ouvrait l'app juste après un run — le message disparaissait d'un coup.)
    static func cleanupStale() async {
        for activity in Activity<ReplyActivityAttributes>.activities {
            if Date().timeIntervalSince(activity.attributes.startedAt) > 60 {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }
}
