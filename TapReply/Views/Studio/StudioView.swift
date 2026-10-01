import SwiftUI

/// STUDIO — refonte Horizon 1.2.0.
/// Le QG des tons : trois emplacements de déclencheurs (Double Tap, Triple
/// Tap, Action Button) à associer à un ton, puis la bibliothèque des tons
/// favoris. « Voir tout » ouvre la grande bibliothèque.
///
/// Les tons vivent dans UserDefaults (préréglages figés + CustomToneStore) :
/// la vue écoute .tapReplyTonesChanged pour se rafraîchir.
struct StudioView: View {

    @ObservedObject private var theme = HZTheme.shared

    // Rafraîchissement : les tons ne sont pas un store observable — on garde
    // un INSTANTANÉ en @State, rechargé à chaque notification de changement.
    // ⚠️ Pas de .id() : changer l'identité de la vue fermerait les sheets
    // ouvertes (bibliothèque, fiche) à chaque modification de ton.
    @State private var favorites: [ToneItem] = []
    @State private var assignments: [ToneTrigger: ToneItem] = [:]

    // Routes de présentation
    @State private var libraryRoute: ToneLibraryRoute?
    @State private var detailRoute: ToneDetailRoute?
    @State private var editorRoute: ToneEditorRoute?
    @State private var testTone: ToneItem?
    @State private var showPaywall = false
    /// Explication avant le paywall (ton personnalisé verrouillé ou limite du ton gratuit).
    @State private var gateAlert: ToneGateAlert?
    /// Le geste dont on doit installer le raccourci (feuille d'installation).
    @State private var shortcutSetup: ToneTrigger?
    /// Le geste dont on lance le MINI-ONBOARDING complet (plein écran).
    @State private var setupFlow: ToneTrigger?
    @ObservedObject private var purchases = PurchaseService.shared
    // ⚠️ @AppStorage et NON une lecture directe de UserDefaults : SwiftUI
    // n'observe pas UserDefaults. La carte « il manque le raccourci » restait
    // donc affichée après confirmation, faute d'invalidation de la vue.
    @AppStorage(SettingsKeys.shortcutConfirmedTripleTap) private var tripleShortcutOK = false
    @AppStorage(SettingsKeys.shortcutConfirmedActionButton) private var actionShortcutOK = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // ① Titre + description (centrés, comme la maquette)
                VStack(spacing: 8) {
                    Text(String(localized: "Choisissez vos tons"))
                        .font(HZ.Fonts.title)
                        .foregroundStyle(HZ.Colors.ink)
                    Text(String(localized: "Associe un ton de communication à chacun de tes déclencheurs rapides : Double Tap, Triple Tap et Action Button."))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
                .padding(.bottom, 26)

                // ② Les trois emplacements de déclencheurs
                triggerSlots
                    .padding(.bottom, 34)

                // ③ Vos tons favoris + Voir tout
                HZSectionHeader(title: String(localized: "Vos tons favoris"),
                                actionLabel: String(localized: "Voir tout")) {
                    libraryRoute = ToneLibraryRoute(context: nil)
                }
                .padding(.bottom, 14)

                favoritesGrid
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, HZ.Spacing.tabBarClearance)
        }
        // Le fond (brume commune) vit au niveau de la RACINE — page transparente.
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .tapReplyTonesChanged)) { _ in
            withAnimation(.snappy) { reload() }
        }
        .sheet(item: $libraryRoute) { route in
            ToneLibrarySheet(context: route.context)
        }
        .sheet(item: $detailRoute) { route in
            ToneDetailView(tone: route.tone, context: route.context)
        }
        .sheet(item: $editorRoute) { route in
            ToneEditorView(editing: route.editing)
        }
        .fullScreenCover(item: $testTone) { tone in
            ToneTestChatView(tone: tone)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywall {
                showPaywall = false
            }
            .background(DS.Colors.page)
        }
        .customToneGate($gateAlert) { free in editorRoute = ToneEditorRoute(editing: free) }
        // PREMIÈRE ASSIGNATION D'UN GESTE SECONDAIRE → mini-onboarding IMPOSÉ.
        // Une carte discrète se laissait ignorer : on triple-tapait dans le
        // vide et on concluait que l'app ne marchait pas. Le différé laisse la
        // fiche puis la bibliothèque se refermer avant que le plein écran monte
        // (sinon iOS empile deux présentations et en perd une).
        .onReceive(NotificationCenter.default.publisher(for: .tapReplyToneAssigned)) { note in
            guard let raw = note.object as? String,
                  let assigned = ToneTrigger(rawValue: raw),
                  assigned.isPremium else { return }
            let alreadyConfirmed = assigned == .tripleTap ? tripleShortcutOK : actionShortcutOK
            guard !alreadyConfirmed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { setupFlow = assigned }
        }
        .fullScreenCover(item: $setupFlow, onDismiss: { reload() }) { trigger in
            TriggerSetupFlow(trigger: trigger) { reload() }
        }
        .sheet(item: $shortcutSetup, onDismiss: { reload() }) { trigger in
            GuideSheet(title: String(localized: "Raccourci \(trigger.label)"),
                       confirmKey: trigger.shortcutConfirmedKey,
                       confirmLabel: String(localized: "C'est installé et associé")) {
                TriggerShortcutGuideView(trigger: trigger)
            }
        }
        .task { await purchases.refresh() }
    }

    /// L'abonnement vu SANS clignotement : au lancement, RevenueCat n'a pas
    /// encore répondu et `isPro` vaut false — le cache persistant garde la
    /// dernière valeur connue et évite d'afficher un cadenas à un abonné.
    private var hasPro: Bool { purchases.isPro || ProAccess.isKnownPro }

    /// Ton personnalisé verrouillé (créé en plus du gratuit, Pro terminé) : nil si le ton est accessible.
    private func lockedCustom(_ tone: ToneItem) -> CustomTone? {
        if case .custom(let c) = tone, CustomToneStore.isLocked(c, hasPro: hasPro) { return c }
        return nil
    }

    /// « + » : on crée si c'est permis ; sinon on EXPLIQUE (1 ton gratuit) avant de proposer Pro.
    private func createTone() {
        if CustomToneStore.canCreate(hasPro: hasPro) { editorRoute = ToneEditorRoute(editing: nil) }
        else { gateAlert = .limit }
    }

    // MARK: - Emplacements de déclencheurs

    private var triggerSlots: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(ToneTrigger.available) { trigger in
                    TriggerSlotView(trigger: trigger,
                                    assigned: assignments[trigger],
                                    // Gestes secondaires = offre Pro. Le slot
                                    // reste VISIBLE, cadenassé : une promesse,
                                    // pas une absence.
                                    locked: trigger.isPremium && !hasPro,
                                    toneLocked: assignments[trigger].flatMap { lockedCustom($0) } != nil,
                                    onTapLocked: { showPaywall = true },
                                    onTapLockedTone: {
                                        if let t = assignments[trigger], let c = lockedCustom(t) { gateAlert = .locked(c) }
                                    },
                                    onTapEmpty: { libraryRoute = ToneLibraryRoute(context: trigger) },
                                    onTapAssigned: { tone in
                                        detailRoute = ToneDetailRoute(tone: tone, context: trigger)
                                    },
                                    onTest: { tone in
                                        if let c = lockedCustom(tone) { gateAlert = .locked(c) } else { testTone = tone }
                                    },
                                    onEdit: { tone in
                                        if let c = lockedCustom(tone) { gateAlert = .locked(c) }
                                        else if case .custom(let c) = tone { editorRoute = ToneEditorRoute(editing: c) }
                                    },
                                    onReplace: { libraryRoute = ToneLibraryRoute(context: trigger) },
                                    onRemove: { ToneTriggers.clear(trigger) })
                }
            }

            // LE RAPPEL QUI MANQUAIT : un ton assigné à un geste secondaire ne
            // sert à rien tant que le raccourci de CE geste n'existe pas — iOS
            // ne peut pas réutiliser celui du double tap, il ne saurait pas
            // lequel des deux a été fait. On le dit ici, au moment exact où
            // l'assignation vient d'être faite, et jamais avant.
            ForEach(pendingShortcutTriggers, id: \.self) { trigger in
                // Rattrapage : si on a esquivé le mini-onboarding, cette carte
                // le relance en entier — même parcours, même essai final.
                Button { setupFlow = trigger } label: {
                    HStack(spacing: 11) {
                        ZStack {
                            Circle().fill(HZ.Colors.mYellow.opacity(0.18))
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HZ.Colors.mOrange)
                        }
                        .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Il manque le raccourci du \(trigger.label)"))
                                .font(HZ.Fonts.fig(14.5, .semibold))
                                .foregroundStyle(HZ.Colors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(String(localized: "Reprendre l'activation, une minute."))
                                .font(HZ.Fonts.caption)
                                .foregroundStyle(HZ.Colors.sub)
                        }
                        Spacer(minLength: 0)
                        HZChevron()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hzCard(radius: HZ.Radius.row)
                    .hzSoft()
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Les gestes qui ont un ton mais pas encore leur raccourci confirmé.
    /// Le Double Tap en est exclu : son raccourci est posé à l'onboarding, et
    /// l'Accueil s'occupe déjà de le réclamer s'il manque.
    private var pendingShortcutTriggers: [ToneTrigger] {
        guard hasPro else { return [] }
        return ToneTrigger.available.filter { trigger in
            guard trigger.isPremium, assignments[trigger] != nil else { return false }
            switch trigger {
            case .tripleTap:    return !tripleShortcutOK
            case .actionButton: return !actionShortcutOK
            case .doubleTap:    return false
            }
        }
    }

    // MARK: - Rechargement de l'instantané

    private func reload() {
        favorites = ToneFavorites.ids.compactMap { ToneItem.resolve(id: $0) }
        assignments = Dictionary(uniqueKeysWithValues: ToneTrigger.available.compactMap { trigger in
            ToneTriggers.assignedTone(for: trigger).map { (trigger, $0) }
        })
    }

    // MARK: - Grille des favoris

    private var favoritesGrid: some View {
        Group {
            if favorites.isEmpty {
                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        Text(String(localized: "Aucun favori pour l'instant"))
                            .font(HZ.Fonts.headline)
                            .foregroundStyle(HZ.Colors.ink)
                        Text(String(localized: "Touche le cœur d'un ton dans la bibliothèque pour le retrouver ici."))
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.sub)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .hzCard(radius: HZ.Radius.card)
                    .hzSoft()

                    // Même sans favori, créer son ton reste à portée : c'est
                    // justement l'état où on a le plus besoin de la proposer.
                    Button { createTone() } label: {
                        CreateToneTile(locked: !CustomToneStore.canCreate(hasPro: hasPro))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                          spacing: 18) {
                    ForEach(favorites) { tone in
                        Button {
                            if let locked = lockedCustom(tone) { gateAlert = .locked(locked) }
                            else { detailRoute = ToneDetailRoute(tone: tone, context: nil) }
                        } label: {
                            ToneTileView(tone: tone,
                                         isFavorite: true,
                                         locked: lockedCustom(tone) != nil) {
                                withAnimation(.snappy) { ToneFavorites.toggle(tone.id) }
                                NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // LA TUILE DE CRÉATION, toujours en dernière position.
                    //
                    // Écrire son propre ton est ce que TapReply fait de plus
                    // singulier, et personne ne le découvrait : la
                    // fonctionnalité vivait derrière « Voir tout ». Elle occupe
                    // maintenant la quatrième case de la grille d'accueil, à
                    // égalité visuelle avec les préréglages.
                    Button { createTone() } label: {
                        CreateToneTile(locked: !CustomToneStore.canCreate(hasPro: hasPro))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Routes identifiables

struct ToneLibraryRoute: Identifiable {
    let context: ToneTrigger?
    let id = UUID()
}

struct ToneDetailRoute: Identifiable {
    let tone: ToneItem
    let context: ToneTrigger?
    var id: String { tone.id }
}

struct ToneEditorRoute: Identifiable {
    let editing: CustomTone?   // nil = création
    let id = UUID()
}

extension ToneItem {
    // fullScreenCover(item:) exige Identifiable — l'id du ton suffit.
}

// MARK: - Un emplacement de déclencheur

/// Vide : carré pointillé avec « + ». Assigné : la pastille du ton + son nom.
/// Tap vide → bibliothèque contextuelle · tap assigné → fiche du ton ·
/// appui long → menu rapide (Tester / Modifier / Remplacer / Retirer).
struct TriggerSlotView: View {
    let trigger: ToneTrigger
    let assigned: ToneItem?
    /// Geste réservé aux abonnés, sur un compte gratuit : le slot s'affiche
    /// quand même, sous cadenas or — même langage que les icônes Pro.
    var locked: Bool = false
    /// Le ton ASSIGNÉ est un ton personnalisé verrouillé (Pro terminé) : il reste visible, sous cadenas.
    var toneLocked: Bool = false
    var onTapLocked: () -> Void = {}
    var onTapLockedTone: () -> Void = {}
    var onTapEmpty: () -> Void
    var onTapAssigned: (ToneItem) -> Void
    var onTest: (ToneItem) -> Void
    var onEdit: (ToneItem) -> Void
    var onReplace: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Group {
                if locked {
                    // Emplacement PREMIUM verrouillé : exactement la silhouette
                    // d'un emplacement libre — cadre pointillé — mais en or, et
                    // le cadenas remplace le « + ». On comprend d'un regard que
                    // la place existe et qu'elle s'achète.
                    Button(action: onTapLocked) {
                        ZStack {
                            RoundedRectangle(cornerRadius: HZ.Radius.tile, style: .continuous)
                                .fill(HZ.Colors.gold.opacity(0.06))
                            RoundedRectangle(cornerRadius: HZ.Radius.tile, style: .continuous)
                                .strokeBorder(HZ.Colors.gold.opacity(0.6),
                                              style: StrokeStyle(lineWidth: 1.6, dash: [6, 6]))
                            HZLockMark(size: 26)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else if let tone = assigned {
                    Button { if toneLocked { onTapLockedTone() } else { onTapAssigned(tone) } } label: {
                        VStack(spacing: 7) {
                            ToneDotView(tone: tone, size: 42)
                                .saturation(toneLocked ? 0.2 : 1)
                                .opacity(toneLocked ? 0.55 : 1)
                                .overlay { if toneLocked { HZLockMark(size: 20) } }
                            Text(tone.title)
                                .font(HZ.Fonts.fig(12.5, .semibold))
                                .foregroundStyle(HZ.Colors.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .background(
                            RoundedRectangle(cornerRadius: HZ.Radius.tile, style: .continuous)
                                .fill(.white)
                        )
                        .hzSoft()
                    }
                    .buttonStyle(.plain)
                    // Retrait en UN tap : petite croix sur le coin du slot
                    .overlay(alignment: .topTrailing) {
                        Button {
                            withAnimation(.snappy) { onRemove() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(HZ.Colors.sub)
                                .frame(width: 20, height: 20)
                                .background(.white, in: Circle())
                                .overlay(Circle().strokeBorder(HZ.Colors.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                    .contextMenu {
                        Button { onTest(tone) } label: {
                            Label(String(localized: "Tester"), systemImage: "play.circle")
                        }
                        if !tone.isPreset {
                            Button { onEdit(tone) } label: {
                                Label(String(localized: "Modifier"), systemImage: "pencil")
                            }
                        }
                        Button { onReplace() } label: {
                            Label(String(localized: "Remplacer"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(role: .destructive) { onRemove() } label: {
                            Label(String(localized: "Retirer le ton"), systemImage: "xmark.circle")
                        }
                    }
                } else {
                    Button(action: onTapEmpty) {
                        ZStack {
                            RoundedRectangle(cornerRadius: HZ.Radius.tile, style: .continuous)
                                .strokeBorder(HZ.Colors.dash,
                                              style: StrokeStyle(lineWidth: 1.6, dash: [6, 6]))
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(HZ.Colors.faint)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            // La COURONNE du geste premium débloqué : perchée sur le coin, elle
            // dépasse volontairement de la carte (offset négatif) — même
            // langage que la couronne de la mascotte et des icônes Pro.
            .overlay(alignment: .topLeading) {
                if trigger.isPremium && !locked {
                    HZCrownMark(size: 17)
                        .rotationEffect(.degrees(-14))
                        .offset(x: -3, y: -7)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: trigger.systemIcon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(trigger.label)
                    .font(HZ.Fonts.fig(12, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(HZ.Colors.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
