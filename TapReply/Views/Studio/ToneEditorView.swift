import SwiftUI

/// ÉDITEUR DE TON — refonte Horizon 1.2.0.
/// Création et modification d'un ton personnalisé : nom, description courte,
/// emoji, couleur, prompt. L'aperçu de la pochette se met à jour en direct.
/// Règles conservées : titre ≤ 24 caractères et unique, instruction 10–600.
struct ToneEditorView: View {
    /// nil = création · sinon édition
    let editing: CustomTone?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var about: String
    @State private var instruction: String
    @State private var emoji: String
    @State private var artIndex: Int
    @State private var mascotIndex: Int
    /// Un ton créé avant les poses (mascotIndex nil) garde sa pochette tant qu'on ne touche pas à la grille.
    @State private var mascotTouched = false
    /// Filet : création refusée si la limite (1 ton gratuit) est atteinte entre-temps.
    @State private var gateAlert: ToneGateAlert?
    private var chosenMascot: Int? {
        (editing != nil && editing?.mascotIndex == nil && !mascotTouched) ? nil : mascotIndex
    }
    @State private var confirmDelete = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, about, instruction }

    init(editing: CustomTone?) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _about = State(initialValue: editing?.about ?? "")
        _instruction = State(initialValue: editing?.instruction ?? "")
        _emoji = State(initialValue: editing?.emoji ?? "🎨")
        _artIndex = State(initialValue: editing?.artIndex ?? Int.random(in: 0..<ToneArtPalette.all.count))
        _mascotIndex = State(initialValue: editing?.mascotIndex ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // En-tête
            HStack {
                Text(editing == nil
                     ? String(localized: "Nouveau ton")
                     : String(localized: "Modifier le ton"))
                    .font(HZ.Fonts.title)
                    .foregroundStyle(HZ.Colors.ink)
                Spacer()
                HZCloseButton { dismiss() }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 20)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // Aperçu vivant de la pochette
                    ToneArtworkView(tone: .custom(previewTone), cornerRadius: 20)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .hzSoft()

                    // Nom
                    field(label: String(localized: "Nom"),
                          hint: "\(title.count)/24") {
                        TextField(String(localized: "Ex. « Poète du dimanche »"), text: $title)
                            .font(HZ.Fonts.headline)
                            .focused($focusedField, equals: .title)
                            .onChange(of: title) { _, v in
                                if v.count > 24 { title = String(v.prefix(24)) }
                            }
                    }

                    // Description courte
                    field(label: String(localized: "Description"),
                          hint: String(localized: "optionnelle")) {
                        TextField(String(localized: "En un mot, ce que ce ton dégage…"),
                                  text: $about, axis: .vertical)
                            .font(HZ.Fonts.body)
                            .lineLimit(1...3)
                            .focused($focusedField, equals: .about)
                            .onChange(of: about) { _, v in
                                if v.count > 120 { about = String(v.prefix(120)) }
                            }
                    }

                    // Pose de la MASCOTTE — remplace l'emoji : le ton créé
                    // partage la direction artistique des tons prédéfinis.
                    VStack(alignment: .leading, spacing: 10) {
                        HZKicker(text: String(localized: "Ta mascotte"))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                                  spacing: 10) {
                            ForEach(0..<MascotCatalog.count, id: \.self) { i in
                                Button {
                                    mascotIndex = i; mascotTouched = true
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(LinearGradient(colors: ToneArtPalette.colors(at: artIndex),
                                                                     startPoint: .topLeading,
                                                                     endPoint: .bottomTrailing))
                                            TapTapStillView(id: MascotCatalog.still(i).id, crop: MascotCatalog.still(i).crop)
                                                .padding(4)
                                        }
                                        .frame(height: 54)
                                        .overlay {
                                            if mascotIndex == i {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(HZ.Colors.ink, lineWidth: 2)
                                            }
                                        }
                                        Text(MascotCatalog.label(i))
                                            .font(HZ.Fonts.fig(10.5, .semibold))
                                            .foregroundStyle(mascotIndex == i ? HZ.Colors.ink : HZ.Colors.faint)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Couleur
                    VStack(alignment: .leading, spacing: 10) {
                        HZKicker(text: String(localized: "Couleur"))
                        HStack(spacing: 12) {
                            ForEach(0..<ToneArtPalette.all.count, id: \.self) { i in
                                Button {
                                    artIndex = i
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Circle()
                                        .fill(LinearGradient(colors: ToneArtPalette.colors(at: i),
                                                             startPoint: .topLeading,
                                                             endPoint: .bottomTrailing))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            if artIndex == i {
                                                Circle().strokeBorder(.white, lineWidth: 3)
                                                Circle().strokeBorder(HZ.Colors.ink, lineWidth: 1.5)
                                                    .padding(-3)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    // Prompt (l'ADN du ton)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HZKicker(text: String(localized: "Prompt"))
                            Spacer()
                            Text("\(instruction.count)/600")
                                .font(HZ.Fonts.caption)
                                .foregroundStyle(instruction.count > 600 ? HZ.Colors.alarm : HZ.Colors.faint)
                        }
                        TextEditor(text: $instruction)
                            .font(HZ.Fonts.body)
                            .foregroundStyle(HZ.Colors.ink)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .instruction)
                            .frame(minHeight: 130)
                            .padding(12)
                            .background(HZ.Colors.card,
                                        in: RoundedRectangle(cornerRadius: HZ.Radius.field, style: .continuous))
                            .onChange(of: instruction) { _, v in
                                if v.count > 600 { instruction = String(v.prefix(600)) }
                            }
                        Text(String(localized: "Décris comment l'IA doit écrire avec tes mots : registre, longueur, emojis, expressions fétiches…"))
                            .font(HZ.Fonts.caption)
                            .foregroundStyle(HZ.Colors.faint)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.alarm)
                    }

                    // Suppression (édition uniquement)
                    if editing != nil {
                        Button {
                            confirmDelete = true
                        } label: {
                            Text(String(localized: "Supprimer ce ton"))
                                .font(HZ.Fonts.strong)
                                .foregroundStyle(HZ.Colors.alarm)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, HZ.Spacing.gutter)
                .padding(.bottom, 20)
            }

            // Enregistrer
            HZPrimaryButton(title: editing == nil
                            ? String(localized: "Créer le ton")
                            : String(localized: "Enregistrer"),
                            enabled: isValid) {
                save()
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 14)
        }
        .background(HZ.Colors.sheet)
        .presentationDragIndicator(.visible)
        .confirmationDialog(String(localized: "Supprimer ce ton ?"),
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button(String(localized: "Supprimer"), role: .destructive) {
                if let editing {
                    CustomToneStore.delete(id: editing.id)
                    NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
                }
                dismiss()
            }
            Button(String(localized: "Annuler"), role: .cancel) {}
        }
        .customToneGate($gateAlert)  // dans l'éditeur : pas de « Modifier mon ton » (on y est déjà)
    }

    // MARK: - Champ étiqueté (kicker + surface gris perle)

    private func field<Content: View>(label: String,
                                      hint: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HZKicker(text: label)
                Spacer()
                if let hint {
                    Text(hint)
                        .font(HZ.Fonts.caption)
                        .foregroundStyle(HZ.Colors.faint)
                }
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(HZ.Colors.card,
                            in: RoundedRectangle(cornerRadius: HZ.Radius.field, style: .continuous))
        }
    }

    // MARK: - Aperçu / validation / sauvegarde

    private var previewTone: CustomTone {
        var t = CustomTone(title: title.isEmpty ? String(localized: "Ton ton") : title,
                           instruction: instruction,
                           artIndex: artIndex,
                           emoji: emoji,
                           about: about,
                           mascotIndex: chosenMascot)
        if let editing {
            t = editing
            t.title = title
            t.emoji = emoji
            t.artIndex = artIndex
            t.mascotIndex = chosenMascot
        }
        return t
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var trimmedInstruction: String {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateTitle: Bool {
        CustomToneStore.all.contains {
            $0.title.compare(trimmedTitle, options: [.caseInsensitive]) == .orderedSame
                && $0.id != editing?.id
        }
    }

    private var validationMessage: String? {
        if !trimmedTitle.isEmpty && isDuplicateTitle {
            return String(localized: "Un ton porte déjà ce nom.")
        }
        if !trimmedInstruction.isEmpty && trimmedInstruction.count < 10 {
            return String(localized: "Le prompt doit faire au moins 10 caractères.")
        }
        return nil
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty
            && !isDuplicateTitle
            && trimmedInstruction.count >= 10
    }

    private func save() {
        guard isValid else { return }
        if var existing = editing {
            existing.title = trimmedTitle
            existing.instruction = trimmedInstruction
            existing.emoji = emoji
            existing.artIndex = artIndex
            existing.mascotIndex = chosenMascot
            existing.about = about.trimmingCharacters(in: .whitespacesAndNewlines)
            CustomToneStore.update(existing)
        } else {
            guard CustomToneStore.canCreate(hasPro: CustomToneAccess.hasPro) else { gateAlert = .limit; return }
            let tone = CustomTone(title: trimmedTitle,
                                  instruction: trimmedInstruction,
                                  artIndex: artIndex,
                                  emoji: emoji,
                                  about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                                  mascotIndex: chosenMascot)
            CustomToneStore.add(tone)
        }
        NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
