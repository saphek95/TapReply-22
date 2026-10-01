import SwiftUI
import StoreKit
import SwiftData

/// RÉGLAGES — refonte Horizon 1.2.0.
/// Brume lavande en tête, profil centré (avatar + prénom), carte de statut
/// membre, grille de cartes rapides, puis les sections en lignes fines.
/// TOUTE la logique 1.1.3 est conservée : vérification d'installation, guides,
/// replay onboarding, consentement, langues, redémarrage de langue, avatar,
/// icône, abonnement, restauration, confidentialité, effacement, diagnostic
/// caché (5 taps sur Version + flag debugLogEnabled), support.
struct SettingsView: View {
    @AppStorage(SettingsKeys.defaultTone) private var defaultTone = "auto"
    @AppStorage(SettingsKeys.replyLanguages) private var replyLanguages = ""
    @AppStorage(AppLocalization.storageKey) private var appLanguage = ""
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false
    @AppStorage(SettingsKeys.shortcutConfirmed) private var shortcutConfirmed = false
    @AppStorage(SettingsKeys.backTapConfirmed) private var backTapConfirmed = false
    @AppStorage(SettingsKeys.avatarColorIndex) private var avatarColorIndex = 0
    @AppStorage(SettingsKeys.userName) private var userName = ""
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 12
    @Environment(\.modelContext) private var context
    @ObservedObject private var theme = HZTheme.shared
    @ObservedObject private var purchases = PurchaseService.shared

    @State private var showShortcutGuide = false
    @State private var showBackTapGuide = false
    @State private var showVerification = false
    @State private var showConsentSheet = false
    @State private var showManageSubscription = false
    @State private var showLanguageRestart = false
    @AppStorage(Analytics.enabledKey) private var analyticsOn = true
    /// Canal d'affichage des réponses : "auto" (île ou bannière selon
    /// l'appareil) ou "notification". Voir SettingsKeys.replyChannel.
    @AppStorage(SettingsKeys.replyChannel) private var replyChannel = "auto"

    /// Ce que l'appareil fait RÉELLEMENT avec la valeur stockée.
    private var replyChannelLabel: String {
        if replyChannel == "notification" { return String(localized: "Notification") }
        if replyChannel == "banner" { return String(localized: "Bannière") }
        // "auto" : l'île quand il y en a une, la notification sinon.
        return DeviceCapabilities.hasDynamicIsland
            ? String(localized: "Dynamic Island")
            : String(localized: "Notification")
    }
    @State private var showAvatarPicker = false
    @State private var showPaywall = false
    @State private var confirmErase = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    @State private var showIconPicker = false
    @State private var showDiagnostics = false
    @State private var versionTaps = 0
    @State private var editingName = false
    @State private var nameDraft = ""
    @FocusState private var nameFieldFocused: Bool
    @State private var showLanguagePicker = false
    /// Geste secondaire dont on ouvre le guide d'installation du raccourci.
    @State private var secondaryShortcutSetup: ToneTrigger?
    // Même raison que dans le Studio : SwiftUI n'observe pas UserDefaults, une
    // lecture directe laisserait la ligne en rouge après confirmation.
    @AppStorage(SettingsKeys.shortcutConfirmedTripleTap) private var tripleShortcutOK = false
    @AppStorage(SettingsKeys.shortcutConfirmedActionButton) private var actionShortcutOK = false

    var body: some View {
        // Pas de NavigationStack ici : son fond opaque recouvrait la brume
        // commune posée à la racine. Le sélecteur de langues passe en sheet.
        Group {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ① Tête : Upgrade / Pro + profil centré
                    headerBlock

                    Group {
                        // ② Carte de statut membre
                        memberCard
                            .padding(.top, 20)

                        // ③ Cartes rapides 2×2
                        quickGrid
                            .padding(.top, 14)

                        // ④ Préférences
                        sectionTitle(String(localized: "Préférences"))
                        preferencesSection

                        // ⑤ Abonnement
                        sectionTitle(String(localized: "Abonnement"))
                        subscriptionSection

                        // ⑥ Confidentialité
                        sectionTitle(String(localized: "Confidentialité"))
                        privacySection

                        // ⑦ Support
                        sectionTitle(String(localized: "Aide"))
                        supportSection
                    }
                    .padding(.horizontal, HZ.Spacing.gutter)
                }
                .padding(.bottom, HZ.Spacing.tabBarClearance)
            }
            .task { await purchases.refresh() }
            .sheet(isPresented: $showShortcutGuide) {
                GuideSheet(title: String(localized: "Créer le raccourci"),
                           confirmKey: SettingsKeys.shortcutConfirmed,
                           confirmLabel: String(localized: "Le raccourci est installé")) { ShortcutGuideView() }
            }
            .sheet(isPresented: $showBackTapGuide) {
                GuideSheet(title: String(localized: "Activer le Back Tap"),
                           confirmKey: SettingsKeys.backTapConfirmed,
                           confirmLabel: String(localized: "Le Back Tap est activé")) { BackTapGuideView() }
            }
            .sheet(isPresented: $showAvatarPicker) { AvatarColorPicker() }
            .sheet(isPresented: $showIconPicker) { AppIconPickerSheet() }
            .sheet(isPresented: $showLanguagePicker) {
                NavigationStack {
                    LanguagePickerView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "OK")) { showLanguagePicker = false }
                            }
                        }
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywall { showPaywall = false }
                    .background(DS.Colors.page)
            }
            .sheet(isPresented: $showVerification) { verificationSheet }
            .sheet(isPresented: $showConsentSheet) { ConsentSheet(accepted: $consentAccepted) }
            .manageSubscriptionsSheet(isPresented: $showManageSubscription)
            .alert(String(localized: "Nouvelle langue enregistrée"), isPresented: $showLanguageRestart) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "Ferme TapReply (glisse l'app vers le haut depuis le sélecteur d'apps), puis rouvre-la : elle s'affichera dans la nouvelle langue."))
            }
            .sheet(item: $secondaryShortcutSetup) { trigger in
                GuideSheet(title: String(localized: "Raccourci \(trigger.label)"),
                           confirmKey: trigger.shortcutConfirmedKey,
                           confirmLabel: String(localized: "C'est installé et associé")) {
                    TriggerShortcutGuideView(trigger: trigger)
                }
            }
            .alert(String(localized: "Restauration"),
                   isPresented: Binding(get: { restoreMessage != nil },
                                        set: { if !$0 { restoreMessage = nil } })) {
                Button("OK", role: .cancel) { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
            // Prénom : feuille MAISON (l'alerte système gris souris cassait la
            // DA au moment le plus personnel de l'app — cf. nameSheet).
            .sheet(isPresented: $editingName) { nameSheet }
            // Changement de langue : appliqué au prochain démarrage
            .sheet(isPresented: $confirmErase) { eraseSheet }
        }
    }

    // MARK: - Tête (gradient) : pilule + profil centré

    private var headerBlock: some View {
        VStack(spacing: 0) {
            HStack {
                // Pas de badge « Pro » ici : la carte dorée au centre des
                // Réglages porte déjà le statut. Seul le CTA Upgrade subsiste
                // pour les comptes gratuits.
                // ⚠️ NE PAS conditionner à isConfigured : pendant un refresh
                // RevenueCat il repasse brièvement à false et le bouton
                // disparaissait (bug observé par Pierre).
                if !purchases.isPro {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill").font(.system(size: 12, weight: .bold))
                            Text(String(localized: "Upgrade")).font(HZ.Fonts.fig(15, .bold))
                        }
                        .foregroundStyle(HZ.Colors.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(HZ.Colors.line, lineWidth: 1))
                        .hzSoft()
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 8)

            VStack(spacing: 10) {
                Button { showAvatarPicker = true } label: {
                    // Le grand TapTap des Réglages : même moteur que l'écran de couleur de l'onboarding. Il
                    // respire ; changer la couleur rejoue la pose de cette couleur ; un tap = un gag.
                    TapTapAvatar(size: 128)
                        // La couronne Pro est posée SUR sa tête et le suit dans chaque geste (dessinée dans le clip).
                        .environment(\.tapTapCrowned, purchases.isPro)
                }
                .buttonStyle(.plain)

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(userName.isEmpty ? String(localized: "Ton profil") : userName)
                            .font(HZ.Fonts.fig(24, .bold))
                            .foregroundStyle(HZ.Colors.ink)
                        if purchases.isConfigured && purchases.isPro {
                            // La couronne « dessinée à la main » du statut Pro
                            HZCrownMark(size: 19)
                                .offset(y: -2)
                        }
                    }
                    Text(String(localized: "Membre depuis \(memberYear)"))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                }

                Button {
                    nameDraft = userName
                    editingName = true
                } label: {
                    HStack(spacing: 4) {
                        Text(userName.isEmpty
                             ? String(localized: "Ajouter mon prénom")
                             : String(localized: "Modifier mon prénom"))
                            .font(HZ.Fonts.strong)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(HZ.Colors.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
        }
    }

    // MARK: - Carte membre

    private var memberCard: some View {
        Button {
            if !purchases.isPro { showPaywall = true }
        } label: {
            Group {
                if purchases.isConfigured && purchases.isPro {
                    // Statut Pro : tout est CENTRÉ — couronne, titre, formule
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            HZInfinityMark(width: 22)
                            Text(String(localized: "Pro · Illimité"))
                                .font(HZ.Fonts.headline)
                                .foregroundStyle(HZ.Colors.ink)
                            HZCrownMark(size: 15)
                                .offset(y: -3)
                        }
                        Text(purchases.proPlanLabel.map { "\($0) · " + String(localized: "réponses illimitées") }
                             ?? String(localized: "Réponses illimitées"))
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.goldDeep)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Membre Standard"))
                                .font(HZ.Fonts.headline)
                                .foregroundStyle(HZ.Colors.ink)
                            Text(String(localized: "\(purchases.creditsBalance ?? 0) réponses restantes"))
                                .font(HZ.Fonts.sub)
                                .foregroundStyle(HZ.Colors.green)
                        }
                        Spacer(minLength: 0)
                        HZChevron()
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(fill: purchases.isPro ? Color(hex: 0xFDF6E7) : .white,
                    radius: HZ.Radius.row)
            // Statut Pro : la carte est ENTOURÉE À LA MAIN — deux passages de
            // crayon or imparfaitement superposés + la couronne perchée de
            // travers sur le coin (même langage que le badge « Illimité »).
            .overlay {
                if purchases.isConfigured && purchases.isPro {
                    RoundedRectangle(cornerRadius: HZ.Radius.row, style: .continuous)
                        .strokeBorder(HZ.Colors.gold, lineWidth: 1.6)
                    RoundedRectangle(cornerRadius: HZ.Radius.row + 2, style: .continuous)
                        .strokeBorder(HZ.Colors.gold.opacity(0.4), lineWidth: 1.3)
                        .rotationEffect(.degrees(0.7))
                        .padding(-3)
                }
            }
            // Plus de couronne perchée sur le coin ici : entre celle de la
            // mascotte juste au-dessus, celle posée à côté de « Pro · Illimité »
            // et celle-ci, l'écran en comptait trois. Le statut est déjà dit —
            // symbole infini, liseré or à main levée, couronne du titre.
            .hzSoft()
        }
        .buttonStyle(.plain)
        // Un peu plus courte que la largeur de l'onglet, centrée — elle
        // respire (et son contour or n'est plus jamais rogné par les bords).
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
        .padding(.top, 6) // place pour la couronne qui dépasse
    }

    // MARK: - Cartes rapides 2×2

    private var quickGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                  spacing: 12) {
            quickCard(icon: "checkmark.shield.fill", tile: HZ.Colors.mGreen,
                      title: String(localized: "Vérification"),
                      badge: "\(configOK)/3",
                      badgeColor: configOK == 3 ? HZ.Colors.mGreen : HZ.Colors.alarm) {
                showVerification = true
            }
            quickCard(icon: "square.and.arrow.down.fill", tile: HZ.Colors.blue,
                      title: String(localized: "Guide du raccourci")) {
                showShortcutGuide = true
            }
            quickCard(icon: "hand.tap.fill", tile: HZ.Colors.mOrange,
                      title: String(localized: "Guide Back Tap")) {
                showBackTapGuide = true
            }
            quickCard(icon: "app.gift.fill", tile: HZ.Colors.mPurple,
                      title: String(localized: "Icône de l'app")) {
                showIconPicker = true
            }
        }
    }

    /// Carte rapide : tuile d'icône colorée (glyphes provisoires — Pierre
    /// fournira les siens) + le titre.
    private func quickCard(icon: String, tile: Color, title: String,
                           badge: String? = nil, badgeColor: Color = HZ.Colors.green,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HZIconTile(color: tile, icon: icon, size: 38)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(HZ.Fonts.fig(11.5, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 21)
                            .background(badgeColor, in: Capsule())
                    }
                }
                Text(title)
                    .font(HZ.Fonts.fig(14.5, .semibold))
                    .foregroundStyle(HZ.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(radius: HZ.Radius.row)
            .hzSoft()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections en lignes

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(HZ.Fonts.section)
            .foregroundStyle(HZ.Colors.ink)
            .padding(.top, 30)
            .padding(.bottom, 4)
    }

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            HZRow(title: String(localized: "Partage avec l'IA"),
                  subtitle: String(localized: "Autorise l'envoi du texte de tes captures à OpenRouter (Google, Anthropic) pour rédiger tes réponses."),
                  systemIcon: "sparkles") {
                // Activer passe TOUJOURS par l'écran d'information (accord éclairé) ; désactiver est immédiat.
                Toggle("", isOn: Binding(get: { consentAccepted },
                                         set: { on in
                                             if on { showConsentSheet = true }
                                             else { consentAccepted = false; Analytics.track("consent", ["value": "revoked", "where": "settings"]) }
                                         }))
                    .labelsHidden()
                    .tint(HZ.Colors.blue)
            }
            HZHairline()
            HZRow(title: String(localized: "Langues de réponse"),
                  subtitle: LanguageSummary.text(for: replyLanguages),
                  systemIcon: "globe") { HZChevron() } action: { showLanguagePicker = true }
            HZHairline()
            // Langue de l'app, choisie ICI (26/09). iOS n'applique une nouvelle langue qu'au prochain lancement :
            // on le dit et on laisse l'utilisateur rouvrir l'app lui-même. JAMAIS de fermeture par programme
            // (exit), qu'Apple assimile à un plantage (2.1) : c'est ce qui avait fait retirer ce menu.
            HZRow(title: String(localized: "Langue de l'application"),
                  systemIcon: "character.bubble") {
                Menu {
                    Picker(String(localized: "Langue de l'application"), selection: $appLanguage) {
                        ForEach(AppLocalization.available, id: \.code) { lang in
                            Text(lang.label).tag(lang.code)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(appLanguageShortLabel)
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.sub)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HZ.Colors.faint)
                    }
                    .frame(maxWidth: 140, alignment: .trailing)
                }
            }
            .onChange(of: appLanguage) { _, newValue in
                AppLocalization.apply(newValue)
                showLanguageRestart = true
            }
            HZHairline()
            // AFFICHAGE DES RÉPONSES
            //
            // Ce réglage remplace la manœuvre que des testeurs faisaient à la
            // main : désactiver les activités en direct dans iOS pour forcer la
            // notification. Bonne intuition, mauvais outil — ça coupait aussi
            // l'affichage sur écran verrouillé.
            //
            // Les DEUX OPTIONS DÉPENDENT DE L'APPAREIL, et elles sont nommées
            // par ce qu'elles font vraiment. « Automatique » ne veut rien dire
            // pour quelqu'un qui justement ne voit rien s'afficher.
            HZRow(title: String(localized: "Affichage des réponses"),
                  systemIcon: DeviceCapabilities.hasDynamicIsland
                      ? "capsule.portrait"
                      : "rectangle.topthird.inset.filled") {
                Menu {
                    Picker(String(localized: "Affichage des réponses"), selection: Binding(
                        get: { (replyChannel == "auto" && !DeviceCapabilities.hasDynamicIsland) ? "notification" : replyChannel },
                        set: { replyChannel = $0 })) {
                        if DeviceCapabilities.hasDynamicIsland {
                            Text(String(localized: "Dynamic Island")).tag("auto")
                        } else {
                            // Sur un iPhone sans île, « auto » VAUT notification
                            // (cf. LiveActivityService.useNotification) : les
                            // deux choix explicites évitent une valeur muette.
                            Text(String(localized: "Bannière")).tag("banner")
                        }
                        Text(String(localized: "Notification")).tag("notification")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(replyChannelLabel)
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.sub)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HZ.Colors.faint)
                    }
                    .frame(maxWidth: 150, alignment: .trailing)
                }
            }
            HZHairline()

            HZRow(title: String(localized: "Couleur de ma mascotte"),
                  systemIcon: "paintpalette") {
                HStack(spacing: 10) {
                    TapTapFigure(size: 30, beats: [.still(TapTapClips.stillBase)])
                    HZChevron()
                }
            } action: { showAvatarPicker = true }
            HZHairline()
            // COULEUR DE L'APP — nuancier de préréglages : la primaire se
            // repeint PARTOUT instantanément (container palmarès, barre de
            // navigation, CTA, chips…). Pierre choisit, on gravera la finale.
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(HZ.Colors.ink)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Couleur de l'app"))
                            .font(HZ.Fonts.headline)
                            .foregroundStyle(HZ.Colors.ink)
                        Text(String(localized: "La teinte principale, appliquée partout."))
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.sub)
                    }
                    Spacer(minLength: 0)
                }
                // GRILLE flexible (5 par rangée) : jamais plus large que
                // l'écran — la rangée fixe débordait et étirait TOUT l'onglet.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                          spacing: 12) {
                    ForEach(HZTheme.presets, id: \.self) { hex in
                        Button {
                            withAnimation(.snappy) { theme.accentHex = hex }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Circle()
                                .fill(Color(hex: UInt(hex)))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if theme.accentHex == hex {
                                        Circle().strokeBorder(.white, lineWidth: 2.5)
                                        Circle().strokeBorder(HZ.Colors.ink.opacity(0.7), lineWidth: 1.2)
                                            .padding(-3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 15)
            HZHairline()
            HZRow(title: String(localized: "Revoir l'onboarding"),
                  systemIcon: "arrow.counterclockwise") {
                HZChevron()
            } action: {
                // Mode replay : les essais deviennent passables (pas de
                // génération imposée si les crédits sont épuisés)
                UserDefaults.standard.set(true, forKey: SettingsKeys.onboardingReplay)
                UserDefaults.standard.set(false, forKey: SettingsKeys.onboardingDone)
            }
        }
        .padding(.horizontal, 16)
        .hzCard(radius: 20)
        .hzSoft()
    }

    private var subscriptionSection: some View {
        VStack(spacing: 0) {
            HZRow(title: String(localized: "Statut"), systemIcon: "creditcard") {
                Text(purchases.isConfigured
                     ? (purchases.isPro
                        ? String(localized: "Pro · illimité")
                        : String(localized: "\(purchases.creditsBalance ?? 0) réponses restantes"))
                     : String(localized: "Achats momentanément indisponibles"))
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
            }
            if purchases.isPro {
                if let plan = purchases.proPlanLabel {
                    HZHairline()
                    HZRow(title: String(localized: "Formule"), systemIcon: "tag") {
                        Text(plan).font(HZ.Fonts.sub).foregroundStyle(HZ.Colors.sub)
                    }
                }
                if let since = purchases.proSince {
                    HZHairline()
                    HZRow(title: String(localized: "Abonné depuis"), systemIcon: "calendar") {
                        Text(since.formatted(date: .abbreviated, time: .omitted))
                            .font(HZ.Fonts.sub).foregroundStyle(HZ.Colors.sub)
                    }
                }
                if let until = purchases.proUntil {
                    HZHairline()
                    HZRow(title: String(localized: "Prochain renouvellement"), systemIcon: "arrow.triangle.2.circlepath") {
                        Text(until.formatted(date: .abbreviated, time: .shortened))
                            .font(HZ.Fonts.sub).foregroundStyle(HZ.Colors.sub)
                    }
                }
            }
            if purchases.isPro {
                HZHairline()
                HZRow(title: String(localized: "Gérer mon abonnement"),
                      systemIcon: "gearshape") { HZChevron() } action: { showManageSubscription = true }
            }
            HZHairline()
            HZRow(title: String(localized: "Restaurer mes achats"),
                  systemIcon: "arrow.clockwise",
                  titleColor: HZ.Colors.blue) {
                if restoring { ProgressView().tint(HZ.Colors.blue) }
            } action: { Task { await restoreTapped() } }
        }
        .padding(.horizontal, 16)
        .hzCard(radius: 20)
        .hzSoft()
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Label(String(localized: "Capture lue sur l'appareil, jamais envoyée"), systemImage: "iphone")
                Label(String(localized: "Texte envoyé à l'IA seulement avec ton accord"), systemImage: "sparkles")
                Label(String(localized: "Aucun contenu stocké sur nos serveurs"), systemImage: "trash.slash")
                Label(String(localized: "Historique 100% local"), systemImage: "internaldrive")
            }
            .font(HZ.Fonts.sub)
            .foregroundStyle(HZ.Colors.sub)
            .padding(.vertical, 14)
            HZHairline()
            HZRow(title: String(localized: "Politique de confidentialité"),
                  systemIcon: "hand.raised") {
                HZChevron()
            } action: { UIApplication.shared.open(Config.privacyPolicyURL) }
            HZHairline()
            HZRow(title: String(localized: "Statistiques d'usage anonymes"),
                  subtitle: String(localized: "Étapes vues dans l'app, jamais le contenu de tes conversations. Aide à améliorer TapReply."),
                  systemIcon: "chart.bar") {
                Toggle("", isOn: Binding(get: { analyticsOn },
                                         set: { on in analyticsOn = on; Analytics.setEnabled(on) }))
                    .labelsHidden()
                    .tint(HZ.Colors.blue)
            }
            HZHairline()
            HZRow(title: String(localized: "Conditions d'utilisation"),
                  systemIcon: "doc.text") {
                HZChevron()
            } action: { UIApplication.shared.open(Config.termsOfUseURL) }
            HZHairline()
            HZRow(title: String(localized: "Effacer tout l'historique"),
                  systemIcon: "trash",
                  titleColor: HZ.Colors.alarm) {
                EmptyView()
            } action: { confirmErase = true }
        }
        .padding(.horizontal, 16)
        .hzCard(radius: 20)
        .hzSoft()
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showDiagnostics && BuildEnv.allowsDiagnostics {
                // V1.1.2 — transcription détaillée du dernier run :
                // c'est ELLE qui permet de savoir si un échec vient de
                // l'OCR (mauvaise transcription) ou de l'IA (mauvaise
                // réponse à une bonne transcription).
                if let transcription = RunLog.lastRunTranscription {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Dernière transcription (ce que l'OCR a envoyé à l'IA)"))
                            .font(HZ.Fonts.strong)
                            .foregroundStyle(HZ.Colors.ink)
                        Text(transcription)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(HZ.Colors.ink)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 12)
                    HZHairline()
                }
                if RunLog.entries.isEmpty && RunLog.lastRunTranscription == nil {
                    Text(String(localized: "Aucun lancement enregistré. Fais un double tap ou un test, puis reviens ici."))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(RunLog.entries.suffix(15).reversed().enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(line.contains("❌") ? HZ.Colors.alarm : HZ.Colors.ink)
                        }
                        HStack(spacing: 16) {
                            // Copie TOUT (transcription + journal) : à coller
                            // dans la conversation avec l'IA pour diagnostic.
                            Button(String(localized: "Copier tout")) {
                                UIPasteboard.general.string = RunLog.exportText
                            }
                            .font(HZ.Fonts.strong)
                            .foregroundStyle(HZ.Colors.blue)
                            Button(String(localized: "Effacer le journal")) { RunLog.clear() }
                                .font(HZ.Fonts.strong)
                                .foregroundStyle(HZ.Colors.alarm)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.vertical, 12)
                }
                HZHairline()
            }
            HZRow(title: String(localized: "Nous contacter"),
                  subtitle: "contact@saphek.com",
                  systemIcon: "envelope") {
                HZChevron()
            } action: {
                // L'identifiant anonyme est joint AUTOMATIQUEMENT : le support peut vérifier le solde et offrir des
                // crédits tout de suite (tableau de bord › Offrir des crédits), sans aller-retour.
                Task { @MainActor in
                    let uid = PurchaseService.appUserID ?? "?"
                    var c = URLComponents()
                    c.scheme = "mailto"; c.path = "contact@saphek.com"
                    c.queryItems = [
                        URLQueryItem(name: "subject", value: "TapReply"),
                        URLQueryItem(name: "body", value: "\n\n\n---\n" + String(localized: "Identifiant (à laisser, il nous permet de t'aider plus vite) :") + " \(uid)\nTapReply \(Config.appVersion)")
                    ]
                    if let url = c.url { UIApplication.shared.open(url) }
                }
            }
            HZHairline()
            HZRow(title: String(localized: "Version"),
                  systemIcon: "info.circle") {
                Text(Config.appVersion)
                    .font(HZ.Fonts.caption)
                    .foregroundStyle(HZ.Colors.sub)
            } action: {
                // Journal de diagnostic CACHÉ : builds DEBUG / TestFlight uniquement (aucune fonction cachée dans
                // la version App Store, guideline 2.3.1). 5 taps sur Version pour l'afficher/masquer.
                guard BuildEnv.allowsDiagnostics else { return }
                versionTaps += 1
                if versionTaps >= 5 {
                    versionTaps = 0
                    withAnimation { showDiagnostics.toggle() }
                    // V1.1.2 — le flag pilote le mode debug du backend
                    // (log du prompt complet) : il faut qu'il soit lisible
                    // par l'App Intent (processus séparé) → UserDefaults.
                    UserDefaults.standard.set(showDiagnostics, forKey: "debugLogEnabled")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            HZHairline()
            // Identifiant anonyme (achats, crédits) : à citer au support pour une demande d'effacement (RGPD).
            HZRow(title: String(localized: "Identifiant anonyme"),
                  subtitle: String(localized: "À nous transmettre pour toute demande sur tes données"),
                  systemIcon: "person.badge.key") {
                Image(systemName: "doc.on.doc").font(.system(size: 13, weight: .semibold)).foregroundStyle(HZ.Colors.faint)
            } action: {
                Task { @MainActor in
                    UIPasteboard.general.string = PurchaseService.appUserID ?? ""
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
        .padding(.horizontal, 16)
        .hzCard(radius: 20)
        .hzSoft()
    }

    // MARK: - Helpers

    private var configOK: Int {
        [consentAccepted, shortcutConfirmed, backTapConfirmed].filter { $0 }.count
    }

    /// Les gestes secondaires réellement UTILISÉS (un ton leur est assigné) :
    /// eux seuls méritent une ligne de vérification.
    private var secondaryTriggersInUse: [ToneTrigger] {
        ToneTrigger.available.filter {
            $0.isPremium && ToneTriggers.assignedToneId(for: $0) != nil
        }
    }

    /// Libellé COMPACT de la langue d'app : « Automatique » au lieu de
    /// « Automatique (Français) », sinon le nom de la langue seul.
    private var appLanguageShortLabel: String {
        guard let full = AppLocalization.available.first(where: { $0.code == appLanguage })?.label
        else { return String(localized: "Automatique") }
        if let paren = full.firstIndex(of: "(") {
            return String(full[full.startIndex..<paren]).trimmingCharacters(in: .whitespaces)
        }
        return full
    }

    private var memberYear: String {
        let t = UserDefaults.standard.double(forKey: SettingsKeys.firstLaunchDate)
        let date = t > 0 ? Date(timeIntervalSince1970: t) : Date()
        return String(Calendar.current.component(.year, from: date))
    }

    // MARK: - Sheets

    /// FEUILLE DE VÉRIFICATION — remise en page 1.2.0.
    ///
    /// Ancienne version : trois lignes serrées avec deux liens minuscules
    /// « Déjà fait » / « Revoir » en bout de ligne. Personne ne les voyait, et
    /// rien n'expliquait ce qu'il fallait faire. Ici, chaque étape en attente
    /// devient une CARTE qui pose la question franchement et offre deux
    /// chemins de taille égale : je l'ai déjà fait → on coche ; je ne l'ai pas
    /// fait → on ouvre le guide. Les étapes validées se replient en une ligne
    /// verte compacte, pour que le regard aille droit à ce qui reste.
    private var verificationSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Vérification d'installation"))
                        .font(HZ.Fonts.section)
                        .foregroundStyle(HZ.Colors.ink)
                    Text(configOK == 3
                         ? String(localized: "Tout est en place.")
                         : String(localized: "\(configOK) étape sur 3 en place."))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                }
                .padding(.top, 20)
                .padding(.bottom, 2)

                verifBlock(done: consentAccepted,
                           title: String(localized: "Conditions acceptées"),
                           waitingTitle: String(localized: "Conditions à accepter"),
                           explain: String(localized: "L'analyse est désactivée jusqu'à ton accord : c'est nous qui te le devons."),
                           guideLabel: String(localized: "Accepter maintenant"),
                           confirmKey: nil,
                           // La feuille de consentement (comme sur l'accueil), pas une relance de tout l'onboarding.
                           fix: { showVerification = false
                                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showConsentSheet = true } })

                verifBlock(done: shortcutConfirmed,
                           title: String(localized: "Raccourci créé"),
                           waitingTitle: String(localized: "Le raccourci est-il créé ?"),
                           explain: String(localized: "Le raccourci « TapReply » doit exister dans l'app Raccourcis. iOS ne nous laisse pas le vérifier, alors dis-le-nous."),
                           guideLabel: String(localized: "Voir comment faire"),
                           confirmKey: SettingsKeys.shortcutConfirmed,
                           fix: { showVerification = false; showShortcutGuide = true })

                verifBlock(done: backTapConfirmed,
                           title: String(localized: "Back Tap activé"),
                           waitingTitle: String(localized: "Le Back Tap est-il activé ?"),
                           explain: String(localized: "Réglages iOS → Accessibilité → Toucher → Toucher le dos de l'appareil, associé au raccourci."),
                           guideLabel: String(localized: "Voir comment faire"),
                           confirmKey: SettingsKeys.backTapConfirmed,
                           fix: { showVerification = false; showBackTapGuide = true })

                // GESTES SECONDAIRES — listés seulement s'ils SERVENT, c'est-à-
                // dire si un ton leur est assigné. Quelqu'un qui n'utilise que
                // le double tap ne voit jamais ces lignes.
                ForEach(secondaryTriggersInUse, id: \.self) { trigger in
                    verifBlock(done: trigger == .tripleTap ? tripleShortcutOK : actionShortcutOK,
                               title: String(localized: "Raccourci \(trigger.label) créé"),
                               waitingTitle: String(localized: "Le raccourci du \(trigger.label) est-il en place ?"),
                               explain: String(localized: "Ce geste a son propre raccourci : iOS ne dit pas à TapReply quel geste tu as fait. Puis \(trigger.systemSetupPath)."),
                               guideLabel: String(localized: "Voir comment faire"),
                               confirmKey: trigger.shortcutConfirmedKey,
                               fix: { showVerification = false; secondaryShortcutSetup = trigger })
                }

                // La seule preuve FACTUELLE : un vrai double tap qui a abouti.
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: AppSettings.lastReplyAt == nil ? "info.circle" : "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(AppSettings.lastReplyAt.map {
                            String(localized: "Vérifié en conditions réelles : dernier double tap réussi le \($0.formatted(date: .abbreviated, time: .shortened)).")
                         } ?? String(localized: "Pas encore vérifié en conditions réelles : fais un double tap dans l'onglet Essai."))
                        .font(HZ.Fonts.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(AppSettings.lastReplyAt == nil ? HZ.Colors.sub : HZ.Colors.green)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
        }
        .background(HZ.Colors.sheet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Une étape : ligne verte compacte si faite, carte à deux actions sinon.
    @ViewBuilder
    private func verifBlock(done: Bool, title: String, waitingTitle: String,
                            explain: String, guideLabel: String,
                            confirmKey: String?,
                            fix: @escaping () -> Void) -> some View {
        if done {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(HZ.Colors.green)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)
                Text(title)
                    .font(HZ.Fonts.headline)
                    .foregroundStyle(HZ.Colors.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(radius: HZ.Radius.row)
        } else {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(HZ.Colors.alarm.opacity(0.14))
                        Image(systemName: "questionmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(HZ.Colors.alarm)
                    }
                    .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(waitingTitle)
                            .font(HZ.Fonts.headline)
                            .foregroundStyle(HZ.Colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(explain)
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    if let key = confirmKey {
                        Button {
                            UserDefaults.standard.set(true, forKey: key)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label(String(localized: "Je l'ai déjà fait"), systemImage: "checkmark")
                                .font(HZ.Fonts.fig(15, .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(HZ.Colors.green, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: fix) {
                        Text(guideLabel)
                            .font(HZ.Fonts.fig(15, .semibold))
                            .foregroundStyle(HZ.Colors.blue)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(HZ.Colors.blueLight, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(radius: HZ.Radius.row)
            .hzSoft()
        }
    }

    // MARK: - Prénom

    /// LA FEUILLE DU PRÉNOM. L'alerte système posait un bloc gris souris avec
    /// deux boutons ternes par-dessus la mascotte : le moment le plus personnel
    /// de l'app était aussi le seul écran qui ne lui ressemblait pas.
    ///
    /// L'idée : au lieu de DÉCRIRE où le prénom s'affichera, on le MONTRE. La
    /// carte du haut est une réplique exacte de l'en-tête de l'Accueil —
    /// mascotte et salutation — et elle se met à jour à chaque frappe. On voit
    /// son prénom prendre sa place avant même d'enregistrer.
    private var nameSheet: some View {
        let clean = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ① L'aperçu vivant de l'en-tête d'Accueil
                HStack(spacing: 12) {
                    TapTapFigure(size: 52, beats: [.still(TapTapClips.stillBase)])
                    Text(clean.isEmpty
                         ? String(localized: "Salut 👋")
                         : String(localized: "Salut \(clean) 👋"))
                        .font(HZ.Fonts.fig(20, .bold))
                        .foregroundStyle(HZ.Colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .animation(.spring(duration: 0.3), value: clean)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hzCard(radius: HZ.Radius.row)
                .hzSoft()
                .padding(.top, 26)

                // ② La question, posée simplement
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Comment on t'appelle ?"))
                        .font(HZ.Fonts.section)
                        .foregroundStyle(HZ.Colors.ink)
                    Text(String(localized: "Ce prénom ne quitte jamais ton téléphone."))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)

                // ③ Le champ, dans la DA — pas de chrome système
                HStack(spacing: 10) {
                    TextField(String(localized: "Prénom"), text: $nameDraft)
                        .font(HZ.Fonts.fig(19, .semibold))
                        .foregroundStyle(HZ.Colors.ink)
                        .tint(HZ.Colors.blue)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFieldFocused)
                        .onSubmit { commitName() }
                    if !clean.isEmpty {
                        Button {
                            nameDraft = ""
                            nameFieldFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(HZ.Colors.faint)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .frame(height: 60)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(nameFieldFocused ? HZ.Colors.blue : HZ.Colors.line,
                                      lineWidth: nameFieldFocused ? 1.8 : 1)
                )
                .animation(.easeOut(duration: 0.18), value: nameFieldFocused)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(HZ.Colors.sheet)
        // ④ Actions ANCRÉES : en safeAreaInset, elles restent au-dessus du
        // clavier. Posées dans le flux, elles passaient dessous dès que le
        // champ prenait le focus — la sheet à hauteur fixe ne remonte pas.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                HZPrimaryButton(title: clean.isEmpty
                                ? String(localized: "Rester anonyme")
                                : String(localized: "Enregistrer"),
                                fill: HZ.Colors.blue) { commitName() }

                Button(String(localized: "Annuler")) { editingName = false }
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(HZ.Colors.sub)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 10)
            .background(HZ.Colors.sheet)
        }
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Le clavier arrive de lui-même : on ne fait pas taper deux fois.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFieldFocused = true
            }
        }
    }

    private func commitName() {
        userName = String(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        editingName = false
    }

    private var eraseSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Effacer tout l'historique ?"))
                .font(HZ.Fonts.section)
                .foregroundStyle(HZ.Colors.ink)
                .padding(.top, 22)

            Text(String(localized: "Toutes tes réponses générées seront supprimées de ce téléphone. Cette action est définitive."))
                .font(HZ.Fonts.body)
                .foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HZPrimaryButton(title: String(localized: "Tout effacer"), fill: HZ.Colors.alarm) {
                try? context.delete(model: ReplyRecord.self)
                try? context.save()
                RunLog.clear()
                confirmErase = false
            }
            HZSecondaryButton(title: String(localized: "Annuler")) { confirmErase = false }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 14)
        .background(HZ.Colors.sheet)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    /// Restauration avec RETOUR VISUEL (logique inchangée).
    private func restoreTapped() async {
        restoring = true
        defer { restoring = false }
        do {
            try await PurchaseService.shared.restore()
            if purchases.isPro {
                restoreMessage = String(localized: "Abonnement Pro restauré ✓ Tes réponses sont illimitées.")
            } else if let credits = purchases.creditsBalance, credits > 0 {
                restoreMessage = String(localized: "Achats restaurés ✓ Il te reste \(credits) réponses.")
            } else {
                restoreMessage = String(localized: "Aucun achat à restaurer sur ce compte.")
            }
        } catch {
            restoreMessage = error.localizedDescription
        }
    }
}
