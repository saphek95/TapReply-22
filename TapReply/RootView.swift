import SwiftUI
import UIKit

extension Notification.Name {
    /// Demande d'ouverture de la page Historique complète depuis l'Accueil.
    static let tapReplyOpenHistory = Notification.Name("tapReplyOpenHistory")
    /// Demande de sélection d'un onglet (object = NSNumber index).
    /// 0 Accueil · 1 Studio · 2 Réglages · 3 Essai.
    static let tapReplySelectTab = Notification.Name("tapReplySelectTab")
}

/// RACINE — refonte Horizon 1.2.0.
/// La tab bar système laisse place à une barre FLOTTANTE en deux bulles :
/// à gauche la pilule Accueil / Studio / Réglages (sélection animée façon
/// liquide, matchedGeometryEffect), à droite la bulle ronde « Essai ».
struct RootView: View {
    @ObservedObject private var theme = HZTheme.shared
    @ObservedObject private var keyboard = HZKeyboard.shared
    @AppStorage(SettingsKeys.onboardingDone) private var onboardingDone = false
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 12
    @State private var selectedTab = 0
    @AppStorage(SettingsKeys.tourDone) private var tourDone = false
    @State private var showTour = false
    /// Paywall présenté à la RACINE (au-dessus des onglets) : le tap sur l'île
    /// « crédits épuisés » doit l'ouvrir DIRECTEMENT, quel que soit l'ordre
    /// des événements onOpenURL / didBecomeActive au réveil de l'app.
    @State private var showPaywall = false
    /// Splash de marque à CHAQUE ouverture (v1.1.0) : les deux taps deviennent
    /// le logo, puis fondu vers l'app. Ne s'affiche pas devant l'onboarding
    /// (qui a déjà son propre écran de splash, avec le texte et le CTA).
    @State private var showLaunchSplash = true
    @AppStorage(SettingsKeys.brandSplashSeen) private var splashSeen = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            content
            if showLaunchSplash && (onboardingDone || splashSeen) {
                // TapTap salue dans LA couleur choisie, puis file vers le coin
                // de l'accueil. L'ancien splash de marque montrait un logo et un
                // nom d'application à quelqu'un qui venait justement d'ouvrir
                // cette application : il ne lui apprenait rien.
                TapTapSplash {
                    withAnimation(.easeOut(duration: 0.32)) { showLaunchSplash = false }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .onAppear {
            // Le splash « Commencer » n'existe QUE la toute première fois
            // (premier écran de l'onboarding). Ensuite, chaque ouverture — même
            // au milieu d'un onboarding inachevé — affiche le splash court.
            if !onboardingDone && !splashSeen { showLaunchSplash = false }
            Analytics.appOpened()
        }
        // Statistiques anonymes : une ouverture par retour au premier plan ; envoi de la file en quittant.
        .onChange(of: scenePhase) { old, p in
            if p == .active && old == .background { Analytics.appOpened() }
            if p == .background { Task { await Analytics.flush() } }
        }
    }

    @ViewBuilder
    private var content: some View {
        // ⚠️ JAMAIS de .id() ici : la reconstruction de la racine casse
        // la réception des deep links de l'île (appris en 0.2.4).
        if onboardingDone {
            ZStack(alignment: .bottom) {
                // Fond commun des quatre onglets : BLANC PUR, posé à la racine.
                // (La brume bleue a été retirée — trop de bleu, pas assez
                // authentique. Le premium vient du blanc, de l'encre et des
                // touches or à main levée.)
                HZ.Colors.page.ignoresSafeArea()

                // TabView PAGINÉE (points masqués) : on peut SWIPER entre les
                // onglets — Accueil ↔ Studio ↔ Réglages ↔ Essai — en plus des
                // boutons. L'arbitrage des gestes est natif : les défilements
                // horizontaux internes (cartes de stats…) gardent la priorité.
                TabView(selection: $selectedTab) {
                    HomeView().tag(0)
                    StudioView().tag(1)
                    SettingsView().tag(2)
                    PlaygroundView().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // ⚠️ PAS d'ignoresSafeArea(.keyboard) ici. C'était la cause du
                // champ de saisie inatteignable dans le terrain d'essai : les
                // pages ignoraient le clavier, donc aucun ScrollView ne
                // réservait sa place et rien ne pouvait défiler sous lui.

                // La barre s'ESCAMOTE quand le clavier monte : une barre
                // flottante posée au-dessus d'un clavier recouvre le champ
                // qu'on est justement en train de remplir.
                if !keyboard.isVisible {
                    HorizonTabBar(selected: $selectedTab)
                        .padding(.horizontal, HZ.Spacing.gutter)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // LA VISITE GUIDÉE, une seule fois, juste après l'onboarding.
                //
                // Elle vit ICI et pas dans l'onboarding : elle a besoin des
                // vrais onglets et des vraies pages derrière son voile. Montrer
                // des captures de l'application dans l'onboarding aurait été
                // plus simple et beaucoup moins convaincant.
            }
            // Le projecteur a besoin des rectangles RÉELS des onglets.
            // `overlayPreferenceValue` les résout dans le repère de cette vue,
            // donc le trou et l'anneau tombent exactement sur la pilule.
            .overlayPreferenceValue(TabAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    if showTour {
                        OnbTour(selectedTab: $selectedTab,
                                tabRects: anchors.mapValues { proxy[$0] }) {
                            tourDone = true
                            showTour = false
                            // La visite se termine SUR le terrain d'essai (dernier arrêt) : on y reste.
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .animation(.easeOut(duration: 0.22), value: keyboard.isVisible)
            // La visite s'ouvre à la PREMIÈRE arrivée dans l'application, une
            // fois seulement. Le court délai laisse l'accueil se dessiner
            // derrière le voile : un projecteur posé sur un écran encore vide ne
            // désigne rien.
            .task {
                guard !tourDone, !showTour else { return }
                try? await Task.sleep(for: .milliseconds(760))
                showTour = true
            }
            // CHANGER D'ONGLET REFERME LE CLAVIER. En glissant vers un autre
            // onglet, le clavier restait planté à l'écran par-dessus une page
            // qui n'a aucun champ — et sans plus rien pour le refermer, la
            // bulle de saisie étant partie avec l'onglet précédent.
            .onChange(of: selectedTab) { _, _ in
                guard keyboard.isVisible else { return }
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil)
            }
            // Tap sur l'île : réponse → Historique · erreur → Accueil · crédits → paywall
            .onOpenURL { url in
                // Un tap sur l'île ne doit JAMAIS rester coincé derrière le
                // splash de lancement : on l'escamote immédiatement.
                showLaunchSplash = false
                // Les liens sont générés par l'app (tapreply://paywall|history|home) : on lit l'hôte, rien d'autre.
                switch url.host?.lowercased() {
                case "paywall": openPaywallFromLink()
                case "history": openHistory()
                case "home":    selectedTab = 0
                default:        break
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywall { showPaywall = false }
                    .background(DS.Colors.page)
            }
            // Tap sur une NOTIFICATION : même navigation que l'île
            .onReceive(NotificationCenter.default.publisher(for: .tapReplyOpenDestination)) { note in
                applyDestination(note.object as? String)
            }
            // Sélection d'onglet demandée par une vue (pilule Pro → 2, Studio → 1)
            .onReceive(NotificationCenter.default.publisher(for: .tapReplySelectTab)) { note in
                if let index = (note.object as? NSNumber)?.intValue, (0...3).contains(index) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        selectedTab = index
                    }
                }
            }
            .onAppear {
                if let d = UserDefaults.standard.string(forKey: SettingsKeys.pendingOpenDestination) {
                    UserDefaults.standard.removeObject(forKey: SettingsKeys.pendingOpenDestination)
                    applyDestination(d)
                }
            }
        } else {
            // ONBOARDING V2. L'ancien (OnboardingFlow) reste dans le projet
            // le temps que celui-ci soit éprouvé sur un vrai appareil : il ne
            // coûte rien tant qu'il n'est pas référencé, et il évite de se
            // retrouver sans porte d'entrée si V2 posait problème au build.
            // À supprimer dès la validation.
            OnboardingV3()
        }
    }

    /// L'onglet Historique n'existe plus : on va sur l'Accueil ET on demande
    /// l'ouverture de la page Historique complète (léger différé pour laisser
    /// la racine se stabiliser — même raison que le paywall).
    private func openHistory() {
        selectedTab = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .tapReplyOpenHistory, object: nil)
        }
    }

    /// Île « crédits épuisés » → paywall, présenté avec un DIFFÉRÉ : une .sheet
    /// déclenchée pendant l'animation d'activation de la scène est ignorée par iOS.
    private func openPaywallFromLink() {
        selectedTab = 0
        showPaywall = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPaywall = true }
    }

    private func applyDestination(_ destination: String?) {
        // Idem pour un tap sur une notification de secours.
        showLaunchSplash = false
        switch destination {
        case "history": openHistory()
        case "home":    selectedTab = 0
        case "paywall": openPaywallFromLink()
        default: break
        }
    }
}

// MARK: - Barre de navigation flottante « deux bulles »

/// À gauche : la pilule des trois onglets principaux, avec une capsule sombre
/// qui GLISSE sous l'onglet sélectionné (matchedGeometryEffect — l'effet
/// liquide demandé). À droite : la bulle ronde « Essai ».
/// Les rectangles réels des onglets, publiés par la barre elle-même.
///
/// La visite guidée en a besoin pour placer son projecteur. Les calculer par
/// fractions ne pouvait pas marcher : la barre n'a pas quatre cases égales mais
/// une capsule de trois onglets à gauche — dont le sélectionné s'élargit pour
/// afficher son libellé — et un bouton isolé à droite. Le trou tombait donc
/// systématiquement à côté.
struct TabAnchorKey: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>],
                       nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct HorizonTabBar: View {
    @Binding var selected: Int
    /// La barre observe le thème EN DIRECT : changer la couleur dans les
    /// Réglages la repeint immédiatement (sans attendre un changement d'onglet).
    @ObservedObject private var theme = HZTheme.shared
    @Namespace private var glider

    private struct Item: Identifiable {
        let index: Int
        let label: String
        let icon: String
        var id: Int { index }
    }

    private var items: [Item] {
        [
            Item(index: 0, label: String(localized: "Accueil"), icon: "house.fill"),
            Item(index: 1, label: String(localized: "Studio"), icon: "waveform"),
            Item(index: 2, label: String(localized: "Réglages"), icon: "gearshape.fill"),
        ]
    }

    /// Le ressort de la barre : un peu d'overshoot pour que la capsule
    /// « atterrisse » avec du rebond au lieu de juste changer.
    private var barSpring: Animation { .spring(response: 0.45, dampingFraction: 0.68) }

    var body: some View {
        HStack(spacing: 12) {
            // Bulle GAUCHE — les trois onglets
            HStack(spacing: 4) {
                ForEach(items) { item in
                    tabButton(item)
                }
            }
            .padding(6)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(HZ.Colors.line.opacity(0.7), lineWidth: 1))
            .hzFloating()

            Spacer(minLength: 0)

            // Bulle DROITE — Essai (le terrain de jeu du pipeline réel)
            Button {
                select(3)
            } label: {
                ZStack {
                    Circle().fill(.white)
                    if selected == 3 {
                        Circle()
                            .fill(HZ.Gradients.spark)
                            .padding(5)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(selected == 3 ? .white : HZ.Colors.blue)
                        .symbolEffect(.bounce, value: selected == 3)
                        .rotationEffect(.degrees(selected == 3 ? -8 : 0))
                }
                .frame(width: 62, height: 62)
                .overlay(Circle().strokeBorder(HZ.Colors.line.opacity(0.7), lineWidth: 1))
                .scaleEffect(selected == 3 ? 1.08 : 1)
                .hzFloating()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Essai"))
            .anchorPreference(key: TabAnchorKey.self, value: .bounds) { [3: $0] }
        }
        // Anime AUSSI les changements venus du swipe de pages (le binding
        // change sans withAnimation) : la capsule glisse toujours.
        .animation(barSpring, value: selected)
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selected == item.index
        return Button {
            select(item.index)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    // Petit rebond de l'icône à l'arrivée de la sélection
                    .symbolEffect(.bounce, value: isSelected)
                if isSelected {
                    Text(item.label)
                        .font(HZ.Fonts.fig(14.5, .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected ? .white : HZ.Colors.sub)
            .padding(.horizontal, isSelected ? 17 : 13)
            .frame(height: 50)
            .background {
                if isSelected {
                    Capsule()
                        .fill(HZ.Colors.blue)
                        .matchedGeometryEffect(id: "hz.tab.glider", in: glider)
                }
            }
            // La pilule sélectionnée « pope » légèrement — effet gelée
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        // Le rectangle réel de cet onglet, pour le projecteur de la visite.
        .anchorPreference(key: TabAnchorKey.self, value: .bounds) {
            [item.index: $0]
        }
    }

    private func select(_ index: Int) {
        guard selected != index else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
            selected = index
        }
    }
}
