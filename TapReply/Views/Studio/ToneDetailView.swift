import SwiftUI

/// FICHE DE TON — refonte Horizon 1.2.0 (design carte blanche).
/// Badge de catégorie, grande pochette, nom + déclencheurs assignés,
/// description, exemple en bulles, puis les actions : Tester, Modifier
/// (grisé pour un préréglage) et la barre noire « Assigner à … » avec son
/// sélecteur de déclencheur.
struct ToneDetailView: View {
    let tone: ToneItem
    /// Déclencheur d'origine (entrée contextuelle via le « + » d'un slot).
    let context: ToneTrigger?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrigger: ToneTrigger
    @State private var showEditor = false
    @State private var showTest = false
    /// Le sélecteur de déclencheur MAISON (plus de menu système)
    @State private var showTriggerPicker = false
    @State private var justAssigned = false
    /// Instantané du ton (il peut être modifié dans l'éditeur pendant que la
    /// fiche est ouverte) — rechargé sur notification, sans churn d'identité.
    @State private var snapshot: ToneItem?
    @State private var showPaywall = false
    @ObservedObject private var purchases = PurchaseService.shared

    init(tone: ToneItem, context: ToneTrigger?) {
        self.tone = tone
        self.context = context
        _selectedTrigger = State(initialValue: context ?? .doubleTap)
    }

    /// Le ton affiché : l'instantané s'il existe, sinon la valeur d'entrée.
    private var current: ToneItem { snapshot ?? tone }

    /// Abonnement vu sans clignotement (cf. ProAccess.isKnownPro).
    private var hasPro: Bool { purchases.isPro || ProAccess.isKnownPro }

    var body: some View {
        content
            .sheet(isPresented: $showPaywall) {
                ProPaywall {
                    showPaywall = false
                }
                .background(DS.Colors.page)
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ① Badge de catégorie centré + fermeture
                    ZStack {
                        HStack(spacing: 6) {
                            if current.isPreset {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(HZ.Colors.blue)
                            }
                            Text(current.isPreset
                                 ? String(localized: "Ton prédéfini")
                                 : String(localized: "Ton personnalisé"))
                                .font(HZ.Fonts.strong)
                                .foregroundStyle(HZ.Colors.ink)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(HZ.Colors.card, in: Capsule())
                        .frame(maxWidth: .infinity)

                        HStack {
                            Spacer()
                            HZCloseButton { dismiss() }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 22)

                    // ② Pochette + identité
                    HStack(alignment: .center, spacing: 16) {
                        ToneArtworkView(tone: current, cornerRadius: 18)
                            .frame(width: 128, height: 96)
                            .hzSoft()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(current.title)
                                .font(HZ.Fonts.fig(26, .bold))
                                .foregroundStyle(HZ.Colors.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                            assignedBadges
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 16)

                    // ③ Description
                    Text(current.about)
                        .font(HZ.Fonts.body)
                        .foregroundStyle(HZ.Colors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 24)

                    // ④ Exemple
                    Text(String(localized: "Exemple"))
                        .font(HZ.Fonts.section)
                        .foregroundStyle(HZ.Colors.ink)
                        .padding(.bottom, 12)

                    exampleBlock
                        .padding(.bottom, 26)

                    // ⑤ Tester / Modifier
                    HStack(spacing: 12) {
                        // Lavande + cobalt : le « Preview template » de monday
                        HZTintButton(title: String(localized: "Tester"),
                                     systemIcon: "play.fill") {
                            showTest = true
                        }

                        Button { showEditor = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(String(localized: "Modifier"))
                                    .font(HZ.Fonts.fig(17, .semibold))
                            }
                            .foregroundStyle(current.isPreset ? HZ.Colors.faint : HZ.Colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(HZ.Colors.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(current.isPreset)
                    }
                }
                .padding(.horizontal, HZ.Spacing.gutter)
                .padding(.bottom, 16)
            }
            // Toucher AILLEURS referme le sélecteur : voile invisible posé
            // sur le contenu défilant (le panneau et la barre, situés en
            // dessous dans le VStack, restent cliquables).
            .overlay {
                if showTriggerPicker {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showTriggerPicker = false
                            }
                        }
                }
            }

            // ⑥ Le sélecteur maison, déplié au-dessus de la barre
            VStack(spacing: 0) {
                if showTriggerPicker {
                    triggerPickerPanel
                        .padding(.horizontal, HZ.Spacing.gutter)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                assignBar
                    .padding(.horizontal, HZ.Spacing.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
            }
        }
        .background(HZ.Colors.sheet)
        .onReceive(NotificationCenter.default.publisher(for: .tapReplyTonesChanged)) { _ in
            // Le ton a pu être modifié (éditeur) ou supprimé pendant l'ouverture.
            if let refreshed = ToneItem.resolve(id: tone.id) {
                snapshot = refreshed
            } else {
                dismiss()
            }
        }
        .sheet(isPresented: $showEditor) {
            if case .custom(let custom) = current {
                ToneEditorView(editing: custom)
            }
        }
        .fullScreenCover(isPresented: $showTest) {
            ToneTestChatView(tone: current)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Badges des déclencheurs déjà assignés

    @ViewBuilder
    private var assignedBadges: some View {
        let triggers = ToneTriggers.triggers(for: current.id)
        if triggers.isEmpty {
            Text(String(localized: "Pas encore assigné"))
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.faint)
        } else {
            HStack(spacing: 6) {
                ForEach(triggers) { trigger in
                    HStack(spacing: 4) {
                        Image(systemName: trigger.systemIcon)
                            .font(.system(size: 9, weight: .bold))
                        Text(trigger.label)
                            .font(HZ.Fonts.fig(11, .semibold))
                    }
                    .foregroundStyle(HZ.Colors.blueDeep)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(HZ.Colors.blue.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    // MARK: - Exemple (bulles)

    @ViewBuilder
    private var exampleBlock: some View {
        if let example = current.example {
            VStack(spacing: 10) {
                HZChatBubble(text: example.them, kind: .incoming)
                HZChatBubble(text: example.me, kind: .outgoing)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .hzCard(fill: HZ.Colors.card, radius: HZ.Radius.card)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(HZ.Colors.faint)
                Text(String(localized: "Pas encore d'exemple"))
                    .font(HZ.Fonts.headline)
                    .foregroundStyle(HZ.Colors.ink)
                Text(String(localized: "Lance un test : le premier échange réussi deviendra l'exemple de cette fiche."))
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 18)
            .hzCard(fill: HZ.Colors.card, radius: HZ.Radius.card)
        }
    }

    // MARK: - Barre d'assignation

    /// LE SÉLECTEUR DE DÉCLENCHEUR — carte blanche arrondie, une ligne par
    /// déclencheur disponible sur cet appareil, avec l'icône du geste, le ton
    /// déjà en place et une coche à la couleur de l'app. Zéro menu système.
    private var triggerPickerPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "Assigner à"))
                    .font(HZ.Fonts.fig(13, .semibold))
                    .kerning(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(HZ.Colors.faint)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(Array(ToneTrigger.available.enumerated()), id: \.element.id) { index, trigger in
                Button {
                    // Geste réservé aux abonnés → on n'assigne pas dans le
                    // vide : on ouvre le paywall, et le picker reste ouvert.
                    if trigger.isPremium && !hasPro {
                        showPaywall = true
                        return
                    }
                    withAnimation(.snappy) {
                        selectedTrigger = trigger
                        showTriggerPicker = false
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(selectedTrigger == trigger
                                      ? HZ.Colors.blue.opacity(0.14) : HZ.Colors.card)
                            Image(systemName: trigger.systemIcon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(selectedTrigger == trigger
                                                 ? HZ.Colors.blueDeep : HZ.Colors.sub)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(trigger.label)
                                .font(HZ.Fonts.headline)
                                .foregroundStyle(HZ.Colors.ink)
                            Text(assignedLabel(for: trigger))
                                .font(HZ.Fonts.sub)
                                .foregroundStyle(HZ.Colors.sub)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if trigger.isPremium && !hasPro {
                            HZLockMark(size: 17)
                        } else if selectedTrigger == trigger {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(HZ.Colors.blue)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < ToneTrigger.available.count - 1 {
                    HZHairline().padding(.leading, 69)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .hzFloating()
    }

    /// Ce qui occupe déjà ce déclencheur (ou « libre »).
    private func assignedLabel(for trigger: ToneTrigger) -> String {
        if trigger.isPremium && !hasPro {
            return String(localized: "Ton supplémentaire avec Pro")
        }
        guard let id = ToneTriggers.assignedToneId(for: trigger),
              let item = ToneItem.resolve(id: id) else {
            return String(localized: "Emplacement libre")
        }
        return item.id == current.id
            ? String(localized: "Ce ton y est déjà")
            : String(localized: "Occupé par \(item.title)")
    }

    /// Le ton est-il déjà assigné au déclencheur sélectionné ?
    private var isAssignedToSelected: Bool {
        ToneTriggers.assignedToneId(for: selectedTrigger) == current.id
    }

    private var assignBar: some View {
        HStack(spacing: 0) {
            // Action principale : ASSIGNER — ou RETIRER si déjà assigné.
            Button {
                if isAssignedToSelected {
                    ToneTriggers.clear(selectedTrigger)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dismiss() }
                } else {
                    ToneTriggers.assign(current.id, to: selectedTrigger)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.snappy) { justAssigned = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: justAssigned ? "checkmark"
                          : (isAssignedToSelected ? "xmark.circle" : selectedTrigger.systemIcon))
                        .font(.system(size: 15, weight: .semibold))
                    Text(justAssigned
                         ? String(localized: "Assigné ✓")
                         : (isAssignedToSelected
                            ? String(localized: "Retirer de \(selectedTrigger.label)")
                            : String(localized: "Assigner à \(selectedTrigger.label)")))
                        .font(HZ.Fonts.fig(17, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(.white.opacity(0.25))
                .frame(width: 1, height: 26)

            // Sélecteur secondaire — panneau MAISON (DA Horizon), pas de menu système
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                    showTriggerPicker.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: showTriggerPicker ? "chevron.down" : "chevron.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
        }
        .background(isAssignedToSelected && !justAssigned ? HZ.Colors.alarm : HZ.Colors.blue,
                    in: Capsule())
        .hzFloating()
    }
}
