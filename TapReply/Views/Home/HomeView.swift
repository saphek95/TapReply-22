import SwiftUI
import SwiftData
import UserNotifications

/// ACCUEIL — refonte Horizon 1.2.0.
/// Gradient bleu → blanc en tête, salutation + avatar, pilule Upgrade / Pro,
/// cartes de statistiques en verre dépoli qui défilent, carte d'alerte
/// conditionnelle, section Historique avec « Voir tout ».
/// LOGIQUE CONSERVÉE : cascade d'alertes, stats partageables, copie, détection
/// notifications, rafraîchissement des crédits.
struct HomeView: View {
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false
    @State private var showConsentSheet = false
    @AppStorage(SettingsKeys.shortcutConfirmed) private var shortcutConfirmed = false
    @AppStorage(SettingsKeys.backTapConfirmed) private var backTapConfirmed = false
    @AppStorage(SettingsKeys.totalReplies) private var totalReplies = 0
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 12
    @AppStorage(SettingsKeys.avatarColorIndex) private var avatarColorIndex = 0
    @AppStorage(SettingsKeys.userName) private var userName = ""

    @ObservedObject private var theme = HZTheme.shared
    @ObservedObject private var purchases = PurchaseService.shared
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \ReplyRecord.createdAt, order: .reverse) private var records: [ReplyRecord]

    @State private var showPaywall = false
    @State private var showHistory = false
    @State private var showAvatarPicker = false
    @State private var showShortcutGuide = false
    @State private var showBackTapGuide = false
    @State private var notificationsDenied = false
    @State private var shareKind: ShareKind?
    @State private var showToast = false
    /// Carte du palmarès actuellement alignée (points de pagination)
    @State private var statPage: ShareKind? = .time
    /// Nombre de réponses vu à la dernière visite : s'il a augmenté, TapTap fait une mini-danse UNE fois.
    @AppStorage("home.lastSeenReplies") private var lastSeenReplies = -1
    @State private var celebrate = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, HZ.Spacing.gutter)
                    .padding(.top, 8)

                // ① Carte d'alerte — seulement si quelque chose empêche l'app de marcher
                if let alert = currentAlert {
                    alertCard(alert)
                        .padding(.horizontal, HZ.Spacing.gutter)
                        .padding(.top, 18)
                }

                // ② Ton palmarès — LE grand container cobalt (façon « My
                // favorites » de monday) : carrousel de cartes blanches
                // illustrées, points de pagination blancs.
                palmaresCard
                    .padding(.horizontal, HZ.Spacing.gutter)
                    .padding(.top, 22)

                // ③ Section Historique
                if !records.isEmpty {
                    historySection
                        .padding(.horizontal, HZ.Spacing.gutter)
                        .padding(.top, 30)
                } else {
                    emptyHistoryBlock
                        .padding(.horizontal, HZ.Spacing.gutter)
                        .padding(.top, 34)
                }
            }
            .padding(.bottom, HZ.Spacing.tabBarClearance)
        }
        // Pas de scroll inutile : avec 3 lignes d'historique, tout tient à
        // l'écran — la page ne bouge que si le contenu déborde vraiment.
        .scrollBounceBehavior(.basedOnSize)
        // Le fond (brume commune) vit au niveau de la RACINE, sous les pages
        // de la TabView : ici la page reste transparente.
        .sheet(isPresented: $showConsentSheet) {
            ConsentSheet(accepted: $consentAccepted)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywall { showPaywall = false }
                .background(DS.Colors.page)
        }
        .fullScreenCover(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarColorPicker()
        }
        // LES DEUX ÉTAPES S'ENCHAÎNENT. Avant, il fallait toucher la carte,
        // confirmer, attendre que la deuxième carte apparaisse, la toucher, et
        // confirmer encore — quatre gestes pour une seule mise en route. Ici, la
        // confirmation du raccourci ouvre DIRECTEMENT le Back Tap, comme dans
        // l'onboarding. Le différé de 0,45 s est nécessaire : deux feuilles
        // présentées dans le même cycle et iOS en ignore une.
        .sheet(isPresented: $showShortcutGuide, onDismiss: {
            if shortcutConfirmed && !backTapConfirmed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showBackTapGuide = true
                }
            }
        }) {
            GuideSheet(title: String(localized: "Créer le raccourci"),
                       confirmKey: SettingsKeys.shortcutConfirmed,
                       confirmLabel: String(localized: "Le raccourci est installé")) { ShortcutGuideView() }
        }
        // Le chaînage marche dans les DEUX sens : quelqu'un qui confirme
        // d'abord le Back Tap se voit proposer le raccourci juste après.
        .sheet(isPresented: $showBackTapGuide, onDismiss: {
            if backTapConfirmed && !shortcutConfirmed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showShortcutGuide = true
                }
            }
        }) {
            GuideSheet(title: String(localized: "Activer le Back Tap"),
                       confirmKey: SettingsKeys.backTapConfirmed,
                       confirmLabel: String(localized: "Le Back Tap est activé")) { BackTapGuideView() }
        }
        .sheet(item: $shareKind) { kind in
            SharePreviewSheet(kind: kind,
                              timeSaved: minutesSavedText,
                              repliesCount: totalReplies,
                              percentile: percentile)
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastView(message: String(localized: "Copiée"))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Île « réponse prête » / notification → page Historique complète
        .onReceive(NotificationCenter.default.publisher(for: .tapReplyOpenHistory)) { _ in
            showHistory = true
        }
        .task {
            await refreshNotificationStatus()
            await purchases.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await refreshNotificationStatus()
                    await purchases.refresh()
                }
            }
        }
    }

    // MARK: - En-tête : avatar + salutation | Upgrade / Pro

    private var header: some View {
        HStack(spacing: 12) {
            // TapTap vectoriel, à la couleur de l'utilisateur : il respire, cligne, salue au retour, danse une
            // fois quand une nouvelle réponse est arrivée, et fait un gag au toucher. La couronne Pro reste.
            TapTapAvatar(size: 54, celebrate: celebrate) { showAvatarPicker = true }
                // La couronne Pro est posée SUR sa tête et le suit dans chaque geste (dessinée dans le clip).
                .environment(\.tapTapCrowned, purchases.isPro)
                .onAppear {
                    if lastSeenReplies >= 0 && totalReplies > lastSeenReplies { celebrate = true }
                    lastSeenReplies = totalReplies
                }
                .onChange(of: totalReplies) { _, n in
                    if n > lastSeenReplies { celebrate = true }
                    lastSeenReplies = n
                }

            Text(userName.isEmpty
                 ? String(localized: "Salut 👋")
                 : String(localized: "Salut \(userName) 👋"))
                .font(HZ.Fonts.fig(20, .bold))
                .foregroundStyle(HZ.Colors.ink)
                // Un prénom long ne pousse JAMAIS la pilule de droite : le texte
                // prend la place restante, passe sur 2 lignes au besoin, puis se
                // réduit un peu et se coupe. L'en-tête grandit en hauteur et le
                // reste de l'accueil descend, la pilule ne bouge pas.
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

            upgradePill
                .fixedSize()
                .layoutPriority(1)
        }
    }

    /// Pilule de droite : « Upgrade » (gratuit) ou « Pro ∞ » (abonné).
    @ViewBuilder
    private var upgradePill: some View {
        if purchases.isConfigured && purchases.isPro {
            // Traitement PREMIUM : or dégradé « ∞ Pro · Illimité » — le statut
            // saute aux yeux, sans zone noire.
            Button {
                NotificationCenter.default.post(name: .tapReplySelectTab, object: NSNumber(value: 2))
            } label: {
                HZProBadge()
            }
            .buttonStyle(.plain)
        } else {
            Button { showPaywall = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HZ.Colors.blue)
                    Text(String(localized: "Upgrade"))
                        .font(HZ.Fonts.fig(15, .bold))
                        .foregroundStyle(HZ.Colors.ink)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(.white, in: Capsule())
                .overlay(Capsule().strokeBorder(HZ.Colors.line, lineWidth: 1))
                .hzSoft()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Carte d'alerte conditionnelle (cascade conservée)

    private struct HomeAlert {
        let title: String
        let subtitle: String
        let actionLabel: String
        let blocking: Bool
        let action: () -> Void
    }

    private var currentAlert: HomeAlert? {
        if !consentAccepted {
            return HomeAlert(
                title: String(localized: "Partage avec l'IA désactivé"),
                subtitle: String(localized: "Sans ton accord, aucune réponse ne peut être générée."),
                actionLabel: String(localized: "Activer"),
                blocking: true
            ) {
                // On ouvre une feuille de consentement, PAS l'onboarding.
                //
                // Relancer l'onboarding entier pour récupérer une case à cocher
                // était brutal et déroutant : l'utilisateur venait de le
                // terminer, et se retrouvait renvoyé à l'écran d'accueil de la
                // mascotte sans comprendre ce qu'on lui redemandait.
                showConsentSheet = true
            }
        }
        // Ces deux étapes sont DÉCLARATIVES : iOS n'expose aucune API pour
        // savoir si le raccourci existe, ni si le Back Tap lui est associé. On
        // ne peut donc pas affirmer que c'est cassé — on demande. D'où le ton
        // interrogatif et « Vérifier » plutôt que « Réparer » : le guide
        // propose ensuite « C'est fait » au retour de l'app Raccourcis.
        // Sur iPad, ni raccourci Back Tap ni Back Tap : pas d'alerte à confirmer.
        if !shortcutConfirmed && !DeviceCapabilities.isIPad {
            return HomeAlert(
                title: String(localized: "Raccourci à confirmer"),
                subtitle: String(localized: "Dis-nous s'il est bien installé."),
                actionLabel: String(localized: "Vérifier"),
                blocking: true
            ) { showShortcutGuide = true }
        }
        if !backTapConfirmed && !DeviceCapabilities.isIPad {
            return HomeAlert(
                title: String(localized: "Back Tap à confirmer"),
                subtitle: String(localized: "Dis-nous s'il est bien activé."),
                actionLabel: String(localized: "Vérifier"),
                blocking: true
            ) { showBackTapGuide = true }
        }
        if purchases.isConfigured && !purchases.isPro && (purchases.creditsBalance ?? 1) <= 0 {
            return HomeAlert(
                title: String(localized: "Plus de réponses"),
                subtitle: String(localized: "Passe en illimité pour continuer."),
                actionLabel: String(localized: "Débloquer"),
                blocking: true
            ) { showPaywall = true }
        }
        if notificationsDenied {
            return HomeAlert(
                title: String(localized: "Notifications désactivées"),
                subtitle: String(localized: "Tu ne seras pas prévenu."),
                actionLabel: String(localized: "Activer"),
                blocking: false
            ) {
                Task {
                    let granted = await NotificationService.requestPermission()
                    if !granted, let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                    await refreshNotificationStatus()
                }
            }
        }
        return nil
    }

    private func alertCard(_ alert: HomeAlert) -> some View {
        Button(action: alert.action) {
            HStack(spacing: 13) {
                Circle()
                    .fill(alert.blocking ? HZ.Colors.alarm : HZ.Colors.blue)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(alert.title)
                        .font(HZ.Fonts.headline)
                        .foregroundStyle(HZ.Colors.ink)
                    Text(alert.subtitle)
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                }
                Spacer(minLength: 0)
                Text(alert.actionLabel)
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.blue)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(radius: HZ.Radius.row)
            .hzFloating()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cartes de stats en verre (défilement horizontal)

    /// (Conservé pour la signature de la carte de partage ; plus AFFICHÉ : voir ReplyLevel.)
    private var percentile: Int {
        switch totalReplies {
        case 0...5: return 80
        case 6...20: return 50
        case 21...50: return 25
        case 51...120: return 10
        case 121...300: return 5
        default: return 1
        }
    }

    /// Une page du palmarès : illustration (still vectoriel de TapTap, recoloré) + valeur + légende.
    private struct PalmaresPage: Identifiable {
        let kind: ShareKind
        let image: String
        let value: String
        let caption: String
        var id: String { kind.rawValue }
    }

    private var palmaresPages: [PalmaresPage] {
        [
        PalmaresPage(kind: .time, image: TapTapClips.stillPalmaresTemps,
                     value: minutesSavedText,
                     caption: String(localized: "de temps gagné · \(totalReplies) réponses")),
        PalmaresPage(kind: .replies, image: TapTapClips.stillPalmaresReponses,
                     value: "\(totalReplies)",
                     caption: String(localized: "réponses écrites pour toi")),
        PalmaresPage(kind: .percentile, image: TapTapClips.stillPalmaresRang,
                     value: ReplyLevel.name(for: totalReplies),
                     caption: String(localized: "ton niveau TapReply")),
        ]
    }

    /// Le grand container COBALT du palmarès (façon « My favorites ») :
    /// titre blanc + cercle-flèche, carrousel de cartes blanches illustrées
    /// (images générées, pas d'icônes), points de pagination blancs.
    private var palmaresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "Ton palmarès"))
                    .font(HZ.Fonts.fig(21, .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button { shareKind = statPage ?? .time } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HZ.Colors.ink)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)

            // Le carrousel occupe TOUTE la largeur du container : les cartes
            // défilent DEDANS et sont rognées par ses bords arrondis — jamais
            // par-dessus le violet (contentMargins gère l'alignement).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(palmaresPages) { page in
                        palmaresInnerCard(page)
                            .id(page.kind)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 14, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $statPage)

            // Points de pagination blancs (comme monday)
            HStack(spacing: 7) {
                ForEach(palmaresPages) { page in
                    Circle()
                        .fill(.white.opacity(statPage == page.kind ? 1 : 0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .animation(.snappy, value: statPage)
        }
        .padding(.vertical, 14)
        .background(HZ.Colors.blue,
                    in: RoundedRectangle(cornerRadius: HZ.Radius.hero, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: HZ.Radius.hero, style: .continuous))
        .hzSoft()
    }

    /// Carte blanche intérieure : panneau illustré (image générée) puis
    /// valeur + légende. Tap = partager cette stat.
    private func palmaresInnerCard(_ page: PalmaresPage) -> some View {
        Button { shareKind = page.kind } label: {
            VStack(alignment: .leading, spacing: 0) {
                // L'illustration est VECTORIELLE et prend la couleur de l'utilisateur : le TapTap du hamac, de
                // l'avion et du podium est le sien.
                TapTapStillView(id: page.image)
                    .padding(6)
                    .frame(width: 236, height: 128)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HZ.Colors.card))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(page.value)
                        .font(HZ.Fonts.fig(22, .bold))
                        .foregroundStyle(HZ.Colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(page.caption)
                        .font(HZ.Fonts.fig(13))
                        .foregroundStyle(HZ.Colors.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 13)
            }
            .frame(width: 252, alignment: .leading)
            .background(.white,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Historique

    /// UN seul container blanc « Historique » (façon « Recently visited ») :
    /// titre + cercle-flèche dans la carte, lignes séparées par des filets.
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "Historique"))
                    .font(HZ.Fonts.fig(21, .bold))
                    .foregroundStyle(HZ.Colors.ink)
                Spacer()
                HZArrowButton { showHistory = true }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 4)

            let recent = Array(records.prefix(3))
            VStack(spacing: 0) {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, record in
                    HistoryRowView(record: record, inContainer: true) { copy(record) }
                    if index < recent.count - 1 {
                        HZHairline().padding(.leading, 72)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(.white,
                    in: RoundedRectangle(cornerRadius: HZ.Radius.hero, style: .continuous))
        .hzSoft()
    }

    private var emptyHistoryBlock: some View {
        VStack(spacing: 14) {
            // TapTap ouvre un carnet vide et hausse les épaules en souriant.
            TapTapStillView(id: TapTapClips.stillHistoriqueVide)
                .frame(width: 150, height: 112)
            Text(String(localized: "Ta première réponse t'attend"))
                .font(HZ.Fonts.section)
                .foregroundStyle(HZ.Colors.ink)
                .multilineTextAlignment(.center)
            Text(String(localized: "Ouvre une conversation, double-tape au dos de ton iPhone : elle apparaîtra ici."))
                .font(HZ.Fonts.body)
                .foregroundStyle(HZ.Colors.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    // MARK: - Actions & helpers

    private func copy(_ record: ReplyRecord) {
        UIPasteboard.general.string = record.reply
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showToast = false }
        }
    }

    /// « 12 min » / « 2 h 34 » — 45 s de mots cherchés économisés par réponse.
    /// FORMULE INCHANGÉE (§5.1-H).
    private var minutesSavedText: String {
        let minutes = max(totalReplies == 0 ? 0 : 1, totalReplies * 45 / 60)
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }
}

// MARK: - Ligne d'historique (partagée Accueil + page Historique)

/// Ligne façon boîte de réception : pastille du ton, réponse sur 2 lignes,
/// heure discrète et — juste dessous — le CŒUR de favori (contour si non
/// enregistré, plein s'il l'est ; un tap le bascule). Tap sur la ligne = copier.
struct HistoryRowView: View {
    @Environment(\.modelContext) private var context
    let record: ReplyRecord
    /// true = posée DANS un container blanc (Accueil) : pas de fond propre,
    /// séparée par des filets. false = carte blanche autonome (page Historique).
    var inContainer: Bool = false
    var onCopy: () -> Void

    private var tone: ToneItem? { ToneItem.resolve(id: record.tone) }

    private var timeText: String {
        record.createdAt.formatted(date: .omitted, time: .shortened)
    }

    /// UNIQUEMENT le ton. L'app d'origine (iMessage, WhatsApp…) et la mention
    /// « brouillon amplifié » étaient du bruit technique : ça n'aide en rien à
    /// retrouver une réponse, et l'app détectée est parfois fausse. Ce qui
    /// distingue deux réponses de la liste, c'est le ton employé.
    private var metaText: String {
        ToneDisplay.label(for: record.tone)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let tone {
                ToneDotView(tone: tone, size: 42)
            } else {
                ZStack {
                    Circle().fill(HZ.Colors.cardDeep)
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(HZ.Colors.sub)
                }
                .frame(width: 42, height: 42)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Accueil : aperçu sur 2 lignes (la carte reste compacte).
                // Page Historique : la réponse ENTIÈRE — c'est justement ce
                // qu'on vient y chercher. Le fixedSize est indispensable :
                // sans lui, SwiftUI tronque un Text multi-lignes placé dans un
                // ScrollView, quel que soit le lineLimit.
                Text(record.reply)
                    .font(HZ.Fonts.fig(15, .regular))
                    .foregroundStyle(HZ.Colors.ink)
                    .lineLimit(inContainer ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: !inContainer)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(metaText)
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
                    .lineLimit(1)
            }

            // Colonne de droite : l'heure, et le cœur juste en dessous
            VStack(alignment: .trailing, spacing: 8) {
                HZTimePill(text: timeText)
                Button {
                    record.isFavorite.toggle()
                    try? context.save()
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: record.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(record.isFavorite ? Color(hex: 0xE8324F) : HZ.Colors.faint)
                        .frame(width: 30, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, inContainer ? 13 : 14)
        .padding(.horizontal, inContainer ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !inContainer {
                RoundedRectangle(cornerRadius: HZ.Radius.row, style: .continuous)
                    .fill(.white)
                    .shadow(color: HZ.Colors.ink.opacity(0.05), radius: 7, y: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }
}

// MARK: - Feuille de partage système (image + texte, hors ligne)

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
