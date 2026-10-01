import Foundation
import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

/// Couche d'achats RevenueCat — TOUT le code RevenueCat de l'app passe par ici.
///
/// Conçu pour compiler MÊME SANS le package RevenueCat (gardes `#if canImport`) :
/// tant que le SDK n'est pas ajouté via Swift Package Manager, le service est
/// simplement « non configuré » et l'app fonctionne comme avant (le backend est
/// en fail-open). Dès que le package + la clé API sont en place, tout s'active.
///
/// Montage monétisation (validé 18/08) :
/// — Annuel ILLIMITÉ 39,99 €/an (trial 3 j) · package $rc_annual
/// — Mensuel ILLIMITÉ 11,99 €/mois · package $rc_monthly
/// — Pack 50 réponses 4,99 € (consommable → +50 crédits Virtual Currency "RPLY")
/// — 10 crédits de bienvenue (octroyés par le backend au premier contact)
/// — Entitlement : "pro" · débit des crédits : CÔTÉ SERVEUR (Edge Function)
@MainActor
final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    /// Vrai si le SDK est présent ET la clé API renseignée
    @Published private(set) var isConfigured = false
    /// Abonnement actif (entitlement "pro")
    @Published private(set) var isPro = false
    /// Solde de crédits (Virtual Currency "RPLY"), nil = inconnu
    @Published private(set) var creditsBalance: Int?
    /// Détails d'abonnement pour l'affichage Réglages (nil si pas Pro)
    @Published private(set) var proSince: Date?
    @Published private(set) var proUntil: Date?
    @Published private(set) var proPlanLabel: String?

    enum Plan { case annual, monthly, creditsPack }

    // MARK: - Prix affichés
    //
    // ⚠️ RÈGLE APPLE (guideline 3.1.2) : le prix montré à l'utilisateur doit
    // être celui du store, dans SA devise et SON format. Écrire « 39,99 € »
    // en dur affiche un prix faux à tout utilisateur hors zone euro, et un
    // prix périmé dès qu'on le change dans App Store Connect.
    //
    // Les valeurs de REPLI ci-dessous ne servent qu'à la première frame, avant
    // que l'offering RevenueCat ait répondu (sinon le paywall s'ouvrirait avec
    // des trous, ou sauterait quand les prix arrivent). Dès que le store
    // répond, elles sont remplacées et `isFromStore` passe à true.
    struct DisplayPrices: Equatable {
        var monthly: String
        var annual: String
        var annualPerMonth: String
        var creditsPack: String
        /// Économie de l'annuel face au mensuel, CALCULÉE sur les vrais prix.
        /// nil = on ne l'affiche pas plutôt que d'annoncer un chiffre faux.
        var annualDiscountPercent: Int?
        /// Durée de l'essai gratuit telle que déclarée par le store, en jours.
        /// nil = aucun essai sur cette offre / ce pays → on masque la promesse.
        var trialDays: Int?
        /// true = valeurs réelles du store · false = repli le temps du chargement
        var isFromStore: Bool

        /// Repli NEUTRE : aucun prix, aucune remise, aucun essai tant que le store n'a pas répondu (un reviewer
        /// hors zone euro voyait des prix en euros et un essai auquel il n'avait peut-être pas droit).
        static let fallback = DisplayPrices(
            monthly: "…",
            annual: "…",
            annualPerMonth: "…",
            creditsPack: "…",
            annualDiscountPercent: nil,
            trialDays: nil,
            isFromStore: false
        )
    }

    /// Prix à afficher dans le paywall. Repli tant que le store n'a pas répondu.
    @Published private(set) var prices = DisplayPrices.fallback


    enum PurchaseError: Error, LocalizedError {
        case notConfigured
        case productUnavailable
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return String(localized: "Achats momentanément indisponibles. Réessaie plus tard.")
            case .productUnavailable:
                return String(localized: "Offre indisponible. Réessaie dans un instant.")
            case .cancelled:
                return String(localized: "Achat annulé.")
            case .failed(let m):
                return String(localized: "L'achat a échoué.") + " (\(m))"
            }
        }
    }

    private init() {}

    // MARK: - Configuration (appelée au lancement, depuis App.init → thread principal)

    #if canImport(RevenueCat)
    private var customerInfoListener: Task<Void, Never>?
    #endif

    static func configure() {
        #if canImport(RevenueCat)
        let key = Config.revenueCatAPIKey
        // La clé Test Store n'est jamais acceptée dans un build App Store.
        guard key.hasPrefix("appl_") || (key.hasPrefix("test_") && BuildEnv.allowsDiagnostics) else {
            RunLog.log("💳 RevenueCat non configuré (clé API absente ou interdite)")
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key) // sans appUserID → ID anonyme
        // SYNCHRONE : l'App Intent peut générer quelques millisecondes après le lancement à froid ; un
        // isConfigured posé dans un Task laissait partir des requêtes SANS identifiant (audit 26/09, m1).
        shared.isConfigured = true
        shared.startListening()
        Task { @MainActor in await shared.refresh() }
        RunLog.log("💳 RevenueCat configuré")
        #else
        RunLog.log("💳 SDK RevenueCat absent (package SPM non ajouté)")
        #endif
    }

    /// Identifiant anonyme envoyé au backend (vérification Pro, débit des crédits). Basé sur l'état RÉEL du SDK.
    static var appUserID: String? {
        #if canImport(RevenueCat)
        guard Purchases.isConfigured else { return nil }
        return Purchases.shared.appUserID
        #else
        return nil
        #endif
    }

    /// Expiration, remboursement, renouvellement, achat sur un autre appareil : RevenueCat pousse le nouvel état
    /// ici, sans attendre un retour au premier plan.
    private func startListening() {
        #if canImport(RevenueCat)
        customerInfoListener?.cancel()
        customerInfoListener = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        #endif
    }

    #if canImport(RevenueCat)
    private func apply(_ info: CustomerInfo) {
        let ent = info.entitlements["pro"]
        isPro = ent?.isActive == true
        // MIROIR PERSISTANT pour l'App Intent (arrière-plan) : avec son échéance (cf. ProAccess).
        ProAccess.cache(isPro: isPro, until: isPro ? ent?.expirationDate : nil)
        AppIconGuard.enforce(isPro: isPro)
        proSince = isPro ? ent?.latestPurchaseDate : nil
        proUntil = isPro ? ent?.expirationDate : nil
        if isPro, let pid = ent?.productIdentifier {
            if pid.localizedCaseInsensitiveContains("annual") {
                proPlanLabel = String(localized: "Pro · Annuel")
            } else if pid.localizedCaseInsensitiveContains("monthly") {
                proPlanLabel = String(localized: "Pro · Mensuel")
            } else {
                proPlanLabel = pid
            }
        } else {
            proPlanLabel = nil
        }
    }
    #endif

    // MARK: - État (entitlement + solde)

    func refresh() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        // Les prix du store, en parallèle de l'état : le paywall peut s'ouvrir à tout moment.
        Task { await loadPrices() }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
        await refreshCredits()

        // CRÉDITS DE BIENVENUE : le drapeau n'est posé QUE si le serveur a répondu 200 ; sinon on réessaiera au
        // prochain lancement (avant, un échec réseau privait définitivement des 10 crédits).
        if !isPro, (creditsBalance ?? 0) == 0 {
            let uid = Purchases.shared.appUserID
            let flag = "welcomeBootstrap.\(uid)"
            if !UserDefaults.standard.bool(forKey: flag) {
                if await GenerationClient.bootstrapWelcomeCredits(appUserId: uid) {
                    UserDefaults.standard.set(true, forKey: flag)
                }
                await refreshCredits()
            }
        }
        #endif
    }

    /// Relit le solde RPLY (cache SDK invalidé : le débit est fait par le serveur).
    func refreshCredits() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        Purchases.shared.invalidateVirtualCurrenciesCache()
        if let vc = try? await Purchases.shared.virtualCurrencies() {
            creditsBalance = vc.all["RPLY"]?.balance
        }
        #endif
    }

    // MARK: - Prix (chargement depuis l'offering)

    /// Lit les prix localisés de l'offering courante. Idempotent, sans effet de
    /// bord : en cas d'échec on garde simplement le repli.
    func loadPrices() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        guard let current = try? await Purchases.shared.offerings().current else { return }

        var next = DisplayPrices.fallback
        var gotAny = false

        if let monthly = current.monthly?.storeProduct {
            next.monthly = monthly.localizedPriceString
            gotAny = true
        }
        if let annual = current.annual?.storeProduct {
            next.annual = annual.localizedPriceString
            // Le « par mois » de l'offre annuelle est un CALCUL, pas un prix du
            // store : on divise par 12 en réutilisant le formateur du produit,
            // donc la bonne devise et les bonnes séparations décimales.
            if let formatter = annual.priceFormatter {
                let perMonth = annual.price / 12
                if let s = formatter.string(from: perMonth as NSDecimalNumber) {
                    next.annualPerMonth = s
                }
            }
            // ÉCONOMIE ANNONCÉE — calculée, jamais écrite en dur. Annoncer
            // « −72 % » alors que les prix ont changé serait une allégation
            // commerciale fausse (motif de rejet et risque juridique).
            if let monthly = current.monthly?.storeProduct, monthly.price > 0 {
                let yearAtMonthlyRate = monthly.price * 12
                if yearAtMonthlyRate > annual.price {
                    let ratio = (yearAtMonthlyRate - annual.price) / yearAtMonthlyRate
                    next.annualDiscountPercent = Int((ratio as NSDecimalNumber).doubleValue * 100)
                } else {
                    next.annualDiscountPercent = nil
                }
            } else {
                next.annualDiscountPercent = nil
            }
            // ESSAI GRATUIT — lu sur l'offre d'introduction du produit. Selon le
            // pays et l'éligibilité, il peut ne pas exister : dans ce cas on ne
            // promet rien.
            if let intro = annual.introductoryDiscount, intro.paymentMode == .freeTrial {
                let p = intro.subscriptionPeriod
                switch p.unit {
                case .day:   next.trialDays = p.value
                case .week:  next.trialDays = p.value * 7
                case .month: next.trialDays = p.value * 30
                case .year:  next.trialDays = p.value * 365
                @unknown default: next.trialDays = nil
                }
            } else {
                next.trialDays = nil
            }
            // ÉLIGIBILITÉ : un essai déjà consommé (ou non proposé à ce compte) n'est jamais promis.
            if next.trialDays != nil {
                let elig = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: annual)
                if elig != .eligible { next.trialDays = nil }
            }
            gotAny = true
        }
        if let pack = current.availablePackages.first(where: {
            $0.identifier == "credits_50" || $0.storeProduct.productIdentifier.contains("credits")
        })?.storeProduct {
            next.creditsPack = pack.localizedPriceString
            gotAny = true
        }

        next.isFromStore = gotAny
        if next != prices { prices = next }
        RunLog.log(gotAny
                   ? "💰 Prix du store chargés (\(next.monthly) · \(next.annual))"
                   : "💰 Offering sans prix exploitable, repli conservé")
        #endif
    }

    // MARK: - Achats

    func purchase(_ plan: Plan) async throws {
        #if canImport(RevenueCat)
        guard isConfigured else { throw PurchaseError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else { throw PurchaseError.productUnavailable }

        let package: Package?
        switch plan {
        case .annual: package = current.annual
        case .monthly: package = current.monthly
        case .creditsPack:
            package = current.availablePackages.first {
                $0.identifier == "credits_50" || $0.storeProduct.productIdentifier.contains("credits")
            }
        }
        guard let package else { throw PurchaseError.productUnavailable }

        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled { throw PurchaseError.cancelled }
        await refresh()
        RunLog.log("💳 Achat réussi : \(package.identifier)")
        #else
        throw PurchaseError.notConfigured
        #endif
    }

    func restore() async throws {
        #if canImport(RevenueCat)
        guard isConfigured else { throw PurchaseError.notConfigured }
        _ = try await Purchases.shared.restorePurchases()
        await refresh()
        RunLog.log("💳 Achats restaurés")
        #else
        throw PurchaseError.notConfigured
        #endif
    }
}
