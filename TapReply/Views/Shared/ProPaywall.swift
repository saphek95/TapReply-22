import SwiftUI

// =============================================================================
// LE PAYWALL PRO — avec un TapTap vivant
// =============================================================================
//
// Il est PERSONNALISÉ (prénom, couleur, heures gagnées) et il tient dans un
// écran. Les principes du paywall précédent sont conservés intégralement
// (ancrage mensuel, deux offres, chronologie de l'essai, sortie qui propose le
// mensuel, aucun prix dans le code). Ce qui change : TapTap.
//
// LA CHORÉGRAPHIE (≈ 4 s à l'ouverture, puis calme — bible S18 v2) :
//   1. il arrive du haut, assis sur son tapis volant en parchemin (V61), avec
//      le nœud papillon (il a eu le temps pendant le vol) ;
//   2. il se pose (pouf), regarde l'argument central apparaître ;
//   3. quand les offres sont là, il DÉSIGNE l'annuel d'un bras avec un clin
//      d'œil (V51b) — le plan reçoit un halo au même instant ;
//   4. ensuite, réactions courtes seulement : tap Annuel → hoche · tap Mensuel
//      → hoche (aucun désaccord) · fermer / « Non merci » → il retire le nœud
//      et fait coucou (V52). Aucune tristesse, aucune pression.
// Réduire les animations : il est déjà posé, bras tendu, sans chorégraphie.
// =============================================================================

struct ProPaywall: View {
    var onClose: () -> Void
    /// Vrai quand le paywall clôt l'onboarding : TapTap arrive en tapis volant. Faux depuis l'app : il est déjà là.
    var choreographed: Bool = false

    @ObservedObject private var purchases = PurchaseService.shared
    @ObservedObject private var theme = HZTheme.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(SettingsKeys.userName) private var userName = ""
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 20
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false
    /// Les offres n'ont pas répondu après 8 s : on le dit, avec un bouton Réessayer (jamais de prix inventé).
    @State private var pricesTimedOut = false
    @State private var restoring = false

    @State private var annual = true
    @State private var isPurchasing = false
    @State private var toast: String?

    // Mise en scène
    private enum Act { case flying, landed, pointing, leaving }
    @State private var act: Act = .flying
    @State private var repointTick = 0
    @State private var nod = 0
    @State private var halo = false
    @State private var pouf = false

    private var accent: Color { Color(hex: UInt(theme.accentHex)) }
    private var firstName: String { userName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hours: Int { AppSettings.hoursPerYear(messagesPerDay: max(messagesPerDay, 1)) }

    private var headline: String {
        firstName.isEmpty
        ? String(localized: "Gagne jusqu'à \(hours) heures par an.")
        : String(localized: "\(firstName), gagne jusqu'à \(hours) heures par an.")
    }

    var body: some View {
        ZStack {
            HZ.Colors.page.ignoresSafeArea()

            // Tient dans un écran quand c'est possible ; défile sinon (petits iPhone, texte agrandi) : les conditions
            // d'abonnement doivent TOUJOURS être lisibles, jamais rognées.
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        title
                        FeatureMarquee(items: featuresTop, accent: accent, reversed: false).padding(.top, 16)
                        FeatureMarquee(items: featuresBottom, accent: accent, reversed: true, stagger: true).padding(.top, 6)
                        Spacer(minLength: 6)
                        unlimitedPitch
                        pointer.padding(.top, 4)
                        plans.padding(.top, -6)
                        packLink
                        Spacer(minLength: 10)
                        cta
                    }
                    .padding(.horizontal, HZ.Spacing.gutter)
                    .padding(.bottom, 14)
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(HZ.Fonts.fig(14.5, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(HZ.Colors.ink.opacity(0.92)))
                        .padding(.bottom, 170)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
        .animation(.spring(duration: 0.4), value: annual)
        .animation(.easeOut(duration: 0.25), value: toast)
        .task { await choreography() }
        .onAppear { Analytics.track("paywall_view", ["from": choreographed ? "onboarding" : "app"]) }
        .task {
            // Prix pas encore chargés : on les redemande, puis on signale l'indisponibilité au bout de 8 s.
            guard !purchases.prices.isFromStore else { return }
            await purchases.loadPrices()
            try? await Task.sleep(for: .seconds(8))
            if !purchases.prices.isFromStore { pricesTimedOut = true }
        }
    }

    // MARK: En-tête : TapTap + marque + croix

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            HStack(spacing: 7) {
                Text(verbatim: "TapReply").font(HZ.Fonts.fig(19, .heavy)).foregroundStyle(HZ.Colors.ink)
                Text(verbatim: "PRO").font(HZ.Fonts.fig(12.5, .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(accent))
            }
            Spacer(minLength: 0)
            // La croix ferme TOUT DE SUITE (pas d'offre intermédiaire, pas d'attente : guideline 3.1.2 / dark patterns).
            Button { Analytics.track("paywall_close"); onClose() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(HZ.Colors.sub)
                    .frame(width: 36, height: 36).background(Circle().fill(HZ.Colors.card))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Fermer"))
        }
        .padding(.top, 6)
    }

    /// TapTap, juste au-dessus des deux offres : il arrive dans un pouf, puis DÉSIGNE l'annuel (bras tendu vers la
    /// droite-bas, clin d'œil), et recommence de temps en temps. Tap sur une offre → il hoche. Fermer → V52.
    private var pointer: some View {
        // Il est posé au-dessus de la carte de DROITE (l'annuel) ; son bras tendu vers la droite-bas la désigne.
        // Le cadre est large (1,7 × la hauteur) pour que le bras tendu ne soit jamais coupé.
        HStack(alignment: .bottom, spacing: 11) {
            Color.clear.frame(maxWidth: .infinity).frame(height: 1)
            ZStack(alignment: .bottom) {
                if pouf { TapTapPouf(size: 100).offset(y: -10) }
                TapTapStage(beats: beats,
                            placement: .ground(anchor: CGPoint(x: 62, y: 92), height: 80),
                            accent: accent, onBeat: { i in
                                if i == nil && act == .leaving { onClose() }
                                if i == nil && act == .pointing { repoint() }
                            })
                    .frame(width: 156, height: 96)
                    .opacity(act == .flying ? 0 : 1)
                    .tapTapNod(nod)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 96)
        }
        .frame(height: 96)
    }

    private var beats: [TapTapBeat] {
        switch act {
        case .flying:   return [.first(TapTapClips.designe)]
        case .landed:   return [.first(TapTapClips.designe)]
        // Toujours avec son nœud papillon (V51b et V52 partent tous deux de la pose A6-1) : il désigne, garde la
        // pose 2,4 s, redésigne. À la sortie : il retire le nœud et fait coucou (V52).
        case .pointing: return [.play(TapTapClips.designe, speed: 1.25 + Double(repointTick % 2) * 0.001, holdMs: 2_400)]
        case .leaving:  return [.play(TapTapClips.retireNoeudCoucou, speed: 1.35)]
        }
    }

    /// Il redésigne l'annuel toutes les ~5 s (la séquence « désigne · repos » se relance).
    private func repoint() {
        guard act == .pointing else { return }
        repointTick += 1
    }

    /// L'arrivée : un pouf au-dessus des offres, puis il désigne l'annuel. Interruptible : un achat ou une fermeture coupe tout.
    private func choreography() async {
        if !choreographed || reduceMotion {
            act = .pointing; halo = true
            return
        }
        try? await Task.sleep(for: .milliseconds(450))
        pouf = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.easeOut(duration: 0.2)) { act = .landed }
        try? await Task.sleep(for: .milliseconds(420))
        pouf = false
        try? await Task.sleep(for: .milliseconds(500))
        guard act == .landed else { return }
        act = .pointing
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.easeInOut(duration: 0.5)) { halo = true }
    }

    private var title: some View {
        Text(headline)
            .font(HZ.Fonts.fig(25.5, .heavy)).foregroundStyle(HZ.Colors.ink)
            .lineLimit(3).minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private var unlimitedPitch: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(accent.opacity(0.13)).frame(width: 44, height: 44)
                Image(systemName: "infinity").font(.system(size: 20, weight: .bold)).foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Réponses illimitées")).font(HZ.Fonts.fig(17.5, .heavy)).foregroundStyle(HZ.Colors.ink)
                Text(String(localized: "Pour un usage personnel. Sans abonnement : 10 réponses offertes au total."))
                    .font(HZ.Fonts.fig(13, .medium)).foregroundStyle(HZ.Colors.sub).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(accent.opacity(0.22), lineWidth: 1))
    }

    // MARK: Les deux offres

    private var plans: some View {
        HStack(spacing: 11) {
            // Le montant FACTURÉ est l'élément de prix le plus visible ; le « par mois » de l'annuel est secondaire.
            PlanCard(title: String(localized: "Mensuel"),
                     price: purchases.prices.monthly,
                     period: String(localized: "/mois"),
                     caption: String(localized: "facturé chaque mois"),
                     badge: nil, trialBadge: nil,
                     selected: !annual, accent: accent, halo: false) { annual = false; nod += 1 }

            PlanCard(title: String(localized: "Annuel"),
                     price: purchases.prices.annual,
                     period: String(localized: "/an"),
                     caption: String(localized: "soit %@ par mois").replacingOccurrences(of: "%@", with: purchases.prices.annualPerMonth),
                     badge: purchases.prices.annualDiscountPercent.map { String(localized: "−%lld %").replacingOccurrences(of: "%lld", with: "\($0)") },
                     trialBadge: purchases.prices.trialDays.map { String(localized: "%lld jours offerts").replacingOccurrences(of: "%lld", with: "\($0)") },
                     selected: annual, accent: accent, halo: halo) { annual = true; nod += 1 }
        }
    }

    private var packLink: some View {
        Button { buy(.creditsPack) } label: {
            HStack(spacing: 7) {
                Text(String(localized: "Ou juste 50 réponses, %@ (achat unique)").replacingOccurrences(of: "%@", with: purchases.prices.creditsPack))
                    .font(HZ.Fonts.fig(14, .semibold))
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(HZ.Colors.sub).frame(maxWidth: .infinity).frame(height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var storeReady: Bool { purchases.prices.isFromStore }

    private var ctaTitle: String {
        if !storeReady { return pricesTimedOut ? String(localized: "Offres indisponibles") : String(localized: "Chargement des offres…") }
        if annual {
            if let days = purchases.prices.trialDays {
                return String(localized: "Essayer %lld jours gratuits").replacingOccurrences(of: "%lld", with: "\(days)")
            }
            return String(localized: "M'abonner · %@ par an").replacingOccurrences(of: "%@", with: purchases.prices.annual)
        }
        return String(localized: "M'abonner · %@ par mois").replacingOccurrences(of: "%@", with: purchases.prices.monthly)
    }

    /// Conditions d'abonnement (guideline 3.1.2) : montant facturé, période, essai, renouvellement automatique, annulation.
    private var renewalTerms: String {
        let price = annual ? purchases.prices.annual : purchases.prices.monthly
        let period = annual ? String(localized: "par an") : String(localized: "par mois")
        var head: String
        if annual, let days = purchases.prices.trialDays {
            head = String(localized: "%1$lld jours gratuits, puis %2$@ %3$@.")
                .replacingOccurrences(of: "%1$lld", with: "\(days)")
                .replacingOccurrences(of: "%2$@", with: price)
                .replacingOccurrences(of: "%3$@", with: period)
        } else {
            head = String(localized: "%1$@ %2$@.")
                .replacingOccurrences(of: "%1$@", with: price)
                .replacingOccurrences(of: "%2$@", with: period)
        }
        return head + " " + String(localized: "Abonnement à renouvellement automatique : le paiement est débité sur ton compte Apple à la confirmation de l'achat (ou à la fin de l'essai) et se renouvelle au même prix, sauf annulation au moins 24 h avant la fin de la période en cours. Annule à tout moment dans Réglages, ton nom, Abonnements.")
    }

    private var cta: some View {
        VStack(spacing: 8) {
            if !consentAccepted {
                // Sans l'accord de partage avec l'IA, TapReply ne peut rien générer : on le dit AVANT l'achat.
                Label(String(localized: "Active d'abord le partage avec l'IA (Réglages) pour utiliser TapReply."), systemImage: "exclamationmark.circle")
                    .font(HZ.Fonts.fig(12.5, .semibold)).foregroundStyle(HZ.Colors.alarm)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Button { buy(annual ? .annual : .monthly) } label: {
                HStack(spacing: 9) {
                    if !storeReady && !pricesTimedOut { ProgressView().tint(.white) }
                    Text(ctaTitle)
                        .font(HZ.Fonts.fig(17, .bold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if storeReady { Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)) }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58)
                .background(accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: accent.opacity(0.35), radius: 16, y: 7)
                .opacity(isPurchasing || !storeReady ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || !storeReady)

            if storeReady {
                Text(renewalTerms)
                    .font(HZ.Fonts.fig(12, .medium)).foregroundStyle(HZ.Colors.sub)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            } else if pricesTimedOut {
                Button {
                    pricesTimedOut = false
                    Task {
                        await purchases.loadPrices()
                        try? await Task.sleep(for: .seconds(8))
                        if !purchases.prices.isFromStore { pricesTimedOut = true }
                    }
                } label: {
                    Text(String(localized: "Réessayer")).font(HZ.Fonts.fig(14, .bold)).foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Button { restore() } label: {
                    HStack(spacing: 4) {
                        if restoring { ProgressView().controlSize(.mini) }
                        Text(String(localized: "Restaurer")).font(HZ.Fonts.fig(12.5, .semibold))
                    }
                }
                .buttonStyle(.plain)
                .disabled(restoring)
                Text(verbatim: "·").font(HZ.Fonts.fig(12.5, .semibold))
                Link(String(localized: "Conditions d'utilisation"), destination: Config.termsOfUseURL).font(HZ.Fonts.fig(12.5, .semibold))
                Text(verbatim: "·").font(HZ.Fonts.fig(12.5, .semibold))
                Link(String(localized: "Confidentialité"), destination: Config.privacyPolicyURL).font(HZ.Fonts.fig(12.5, .semibold))
            }
            .foregroundStyle(HZ.Colors.sub)
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(height: 30)
        }
    }

    /// « Restaurer » avec un retour visible (un bouton muet se lit « ne marche pas » en review).
    private func restore() {
        guard !restoring else { return }
        guard purchases.isConfigured else {
            flash(String(localized: "Achats momentanément indisponibles. Réessaie plus tard.")); return
        }
        restoring = true
        Analytics.track("restore")
        Task {
            defer { restoring = false }
            do {
                try await purchases.restore()
                if purchases.isPro {
                    flash(String(localized: "Abonnement Pro restauré ✓"))
                    try? await Task.sleep(for: .milliseconds(900))
                    onClose()
                } else {
                    flash(String(localized: "Aucun abonnement à restaurer sur ce compte Apple."))
                }
            } catch {
                flash(String(localized: "La restauration a échoué. Vérifie ta connexion et réessaie."))
            }
        }
    }

    private var featuresTop: [(String, String)] {
        [("infinity", String(localized: "Réponses sans limite")),
         ("hand.tap.fill", String(localized: "2 tons de plus")),
         ("circle.circle.fill", String(localized: "Un raccourci par ton")),
         ("square.grid.2x2.fill", String(localized: "4 icônes exclusives"))]
    }
    private var featuresBottom: [(String, String)] {
        [("gauge.medium", String(localized: "Plus jamais de compteur")),
         ("wand.and.stars", String(localized: "Un ton par geste")),
         ("hand.raised.fingers.spread.fill", String(localized: "Tes tons sur 3 raccourcis")),
         ("sparkles", String(localized: "Tons perso illimités"))]
    }

    // MARK: Achat et sortie

    /// Fermer sans s'abonner : il retire son nœud papillon et fait coucou ; l'écran se ferme à la fin du geste.
    private func leave() {
        guard act != .leaving else { return }
        act = .leaving
        if reduceMotion { onClose() }
        // Filet : si le clip ne se termine pas (ressource absente), on ferme quand même.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_700))
            if act == .leaving { onClose() }
        }
    }

    private func buy(_ plan: PurchaseService.Plan) {
        guard purchases.isConfigured else {
            flash(String(localized: "Achats momentanément indisponibles. Réessaie plus tard.")); return
        }
        if purchases.isPro && plan != .creditsPack {
            flash(String(localized: "Tu as déjà un abonnement actif ✓")); return
        }
        guard !isPurchasing else { return }
        isPurchasing = true
        let planName: String = { switch plan { case .annual: return "annual"; case .monthly: return "monthly"; case .creditsPack: return "credits_50" } }()
        Analytics.track("purchase_start", ["plan": planName])
        Task {
            do {
                try await purchases.purchase(plan)
                Analytics.track("purchase_ok", ["plan": planName])
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                flash(plan == .creditsPack ? String(localized: "+50 réponses ajoutées 🎉") : String(localized: "C'est parti 🎉"))
                try? await Task.sleep(for: .milliseconds(900))
                onClose()
            } catch PurchaseService.PurchaseError.cancelled {
                // annulé par l'utilisateur : rien à dire
                Analytics.track("purchase_fail", ["plan": planName, "reason": "cancelled"])
            } catch {
                Analytics.track("purchase_fail", ["plan": planName, "reason": "error"])
                flash(String(localized: "Achat interrompu."))
            }
            isPurchasing = false
        }
    }

    private func flash(_ message: String) {
        toast = message
        Task { try? await Task.sleep(for: .seconds(2.4)); toast = nil }
    }
}

// MARK: - Une carte d'offre

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let caption: String
    let badge: String?
    let trialBadge: String?
    let selected: Bool
    let accent: Color
    /// Le halo posé par TapTap quand il désigne le plan.
    var halo: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(HZ.Fonts.fig(15.5, .bold)).foregroundStyle(selected ? HZ.Colors.ink : HZ.Colors.sub)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price).font(HZ.Fonts.fig(25, .heavy)).foregroundStyle(selected ? accent : HZ.Colors.sub)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(period).font(HZ.Fonts.fig(13, .semibold)).foregroundStyle(HZ.Colors.faint)
                }
                Text(caption).font(HZ.Fonts.fig(12, .medium)).foregroundStyle(HZ.Colors.sub).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected ? accent.opacity(0.09) : HZ.Colors.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? accent : HZ.Colors.line, lineWidth: selected ? 2 : 1))
            .shadow(color: accent.opacity(halo ? 0.38 : 0), radius: halo ? 18 : 0, y: 4)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(HZ.Fonts.fig(11.5, .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(accent)).offset(x: 6, y: -9)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let trialBadge {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill").font(.system(size: 9, weight: .bold))
                        Text(trialBadge).font(HZ.Fonts.fig(10.5, .heavy))
                    }
                    .foregroundStyle(HZ.Colors.ink).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(HZ.Colors.gold)).offset(x: 6, y: 9)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.5), value: halo)
    }
}

// MARK: - Le bandeau défilant (inchangé)

private struct FeatureMarquee: View {
    let items: [(String, String)]
    let accent: Color
    let reversed: Bool
    var stagger: Bool = false
    private let chipWidth: CGFloat = 168
    private let spacing: CGFloat = 9
    private var loop: CGFloat { CGFloat(items.count) * (chipWidth + spacing) }
    @State private var shift: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { copy in
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        chip(item).frame(width: chipWidth).id("\(copy)-\(i)")
                    }
                }
            }
            .offset(x: offsetX)
        }
        .frame(height: 46)
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: Double(loop) / 32).repeatForever(autoreverses: false)) { shift = loop }
        }
    }

    private var offsetX: CGFloat {
        let stag: CGFloat = stagger ? -chipWidth / 2 : 0
        return (reversed ? -loop + shift : -shift) + stag
    }

    private func chip(_ item: (String, String)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.0).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
            Text(item.1).font(HZ.Fonts.fig(13, .semibold)).foregroundStyle(HZ.Colors.ink).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HZ.Colors.card))
    }
}
