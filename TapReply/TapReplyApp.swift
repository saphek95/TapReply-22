import SwiftUI
import SwiftData
import UserNotifications

@main
struct TapReplyApp: App {

    init() {
        // Date du premier lancement (« Membre depuis {année} » — Réglages).
        // Les utilisateurs existants prennent la date de cette mise à jour.
        if UserDefaults.standard.object(forKey: SettingsKeys.firstLaunchDate) == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970,
                                      forKey: SettingsKeys.firstLaunchDate)
        }
        // DOUBLE TAP = CLASSIQUE PAR DÉFAUT. Le geste principal ne doit jamais
        // arriver vierge : à la toute première ouverture — onboarding fait,
        // sauté ou en cours — le Studio montre « Classique » sur le Double Tap,
        // et Triple Tap / bouton Action restent volontairement vides. Amorçage
        // à MARQUEUR DÉDIÉ : on ne se contente pas de tester defaultTone, sinon
        // quelqu'un qui a délibérément vidé son Double Tap se le verrait
        // réassigner à chaque lancement.
        if !UserDefaults.standard.bool(forKey: SettingsKeys.defaultToneSeeded) {
            UserDefaults.standard.set(true, forKey: SettingsKeys.defaultToneSeeded)
            if UserDefaults.standard.string(forKey: SettingsKeys.defaultTone) == nil {
                UserDefaults.standard.set(Tone.auto.rawValue, forKey: SettingsKeys.defaultTone)
            }
        }
        // Tap sur une notification → navigation vers le bon onglet (cf. NotificationDelegate)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Actions de la notification (« Recopier ») : sans enregistrement de la
        // catégorie au lancement, iOS ne les affiche pas.
        NotificationService.registerCategories()
        // Version App Store : aucun outil de diagnostic. Un drapeau debug hérité d'un build TestFlight ne survit
        // pas, et la transcription locale du dernier run (texte de conversations) est purgée.
        if !BuildEnv.allowsDiagnostics {
            UserDefaults.standard.set(false, forKey: "debugLogEnabled")
            RunLog.clear()
        }
        // Achats & crédits (no-op tant que le SDK/clé ne sont pas en place)
        PurchaseService.configure()
        // ICÔNES PRO : si l'abonnement a expiré alors qu'une icône exclusive
        // était active, on remet l'icône principale (elles sont réservées
        // aux abonnés). Vérifié après le rafraîchissement RevenueCat.
        AppIconGuard.enforceProIcons()
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                // ⚠️ JAMAIS de .id() ici : la reconstruction de la racine casse
                // la réception des deep links de l'île (appris en 0.2.4).
                // DA « Porcelaine » : light mode UNIQUEMENT (design.md §1) —
                // sinon les Form/List passent en sombre selon le réglage système.
                .preferredColorScheme(.light)
                .task {
                    // Nettoie UNIQUEMENT les Live Activities périmées (> 60 s) —
                    // jamais une île fraîche que l'utilisateur est en train de lire.
                    await LiveActivityService.cleanupStale()
                }
        }
        .modelContainer(HistoryStore.container)
    }
}
