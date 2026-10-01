import SwiftUI

/// BIBLIOTHÈQUE DES TONS — « Voir tout » du Studio (refonte Horizon 1.2.0).
/// Une sheet montante : les favoris d'abord, puis « Les autres tons » avec la
/// grande carte « Générer un nouveau ton ». Pas de marketplace pour l'instant :
/// tout est fluide, à la suite.
///
/// Deux modes d'entrée (doc de structure §5) :
/// - context == nil : exploration LIBRE (depuis « Voir tout »)
/// - context != nil : entrée CONTEXTUELLE depuis le « + » d'un déclencheur —
///   la fiche ouverte proposera « Assigner à <déclencheur> » présélectionné.
struct ToneLibrarySheet: View {
    let context: ToneTrigger?
    @Environment(\.dismiss) private var dismiss

    @State private var favorites: [ToneItem] = []
    @State private var others: [ToneItem] = []
    @State private var favoriteIds: Set<String> = []
    @State private var detailRoute: ToneDetailRoute?
    @State private var editorRoute: ToneEditorRoute?
    @State private var gateAlert: ToneGateAlert?
    @ObservedObject private var purchases = PurchaseService.shared
    private var hasPro: Bool { purchases.isPro || ProAccess.isKnownPro }
    private func lockedCustom(_ tone: ToneItem) -> CustomTone? {
        if case .custom(let c) = tone, CustomToneStore.isLocked(c, hasPro: hasPro) { return c }
        return nil
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible())]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // En-tête : contexte éventuel + fermeture
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Bibliothèque des tons"))
                            .font(HZ.Fonts.title)
                            .foregroundStyle(HZ.Colors.ink)
                        if let context {
                            Text(String(localized: "Choisis le ton à assigner au \(context.label)."))
                                .font(HZ.Fonts.sub)
                                .foregroundStyle(HZ.Colors.sub)
                        }
                    }
                    Spacer()
                    HZCloseButton { dismiss() }
                }
                .padding(.top, 22)
                .padding(.bottom, 22)

                // ① Favoris
                if !favorites.isEmpty {
                    Text(String(localized: "Vos tons favoris"))
                        .font(HZ.Fonts.section)
                        .foregroundStyle(HZ.Colors.ink)
                        .padding(.bottom, 14)

                    grid(for: favorites)
                        .padding(.bottom, 30)
                }

                // ② Les autres tons (+ création)
                Text(String(localized: "Les autres tons"))
                    .font(HZ.Fonts.section)
                    .foregroundStyle(HZ.Colors.ink)
                    .padding(.bottom, 14)

                LazyVGrid(columns: columns, spacing: 18) {
                    createCard
                    ForEach(others) { tone in
                        tile(for: tone)
                    }
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 34)
        }
        .background(HZ.Colors.sheet)
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .tapReplyTonesChanged)) { _ in
            withAnimation(.snappy) { reload() }
        }
        // ASSIGNATION FAITE → on se referme derrière la fiche. Avant, seule la
        // fiche se fermait et on retombait sur la bibliothèque, qu'il fallait
        // quitter à la main pour revoir le Studio : deux gestes pour une tâche
        // terminée. Le différé laisse la fiche jouer son « Assigné ✓ » puis se
        // retirer (0,7 s + animation) — deux dismiss simultanés et iOS en
        // ignore un.
        .onReceive(NotificationCenter.default.publisher(for: .tapReplyToneAssigned)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { dismiss() }
        }
        .sheet(item: $detailRoute) { route in
            ToneDetailView(tone: route.tone, context: route.context)
        }
        .sheet(item: $editorRoute) { route in
            ToneEditorView(editing: route.editing)
        }
        .customToneGate($gateAlert) { free in editorRoute = ToneEditorRoute(editing: free) }
    }

    // MARK: - Données (instantané rechargé sur notification — pas de .id())

    private func reload() {
        let all = ToneItem.presets + ToneItem.customs
        favoriteIds = Set(ToneFavorites.ids)
        favorites = ToneFavorites.ids.compactMap { ToneItem.resolve(id: $0) }
        others = all.filter { !favoriteIds.contains($0.id) }
    }

    // MARK: - Grille

    private func grid(for tones: [ToneItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(tones) { tone in
                tile(for: tone)
            }
        }
    }

    private func tile(for tone: ToneItem) -> some View {
        Button {
            // Ton verrouillé : on explique (et on ne l'assigne pas à un geste) au lieu d'ouvrir sa fiche.
            if let locked = lockedCustom(tone) { gateAlert = .locked(locked) }
            else { detailRoute = ToneDetailRoute(tone: tone, context: context) }
        } label: {
            ToneTileView(tone: tone,
                         isFavorite: favoriteIds.contains(tone.id),
                         locked: lockedCustom(tone) != nil) {
                withAnimation(.snappy) { ToneFavorites.toggle(tone.id) }
                NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if case .custom(let custom) = tone {
                if lockedCustom(tone) == nil {
                    Button {
                        editorRoute = ToneEditorRoute(editing: custom)
                    } label: {
                        Label(String(localized: "Modifier"), systemImage: "pencil")
                    }
                }
                Button(role: .destructive) {
                    CustomToneStore.delete(id: custom.id)
                    NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
                } label: {
                    Label(String(localized: "Supprimer"), systemImage: "trash")
                }
            }
        }
    }

    /// La grande carte « + » : générer un nouveau ton. Sans Pro, une fois le ton gratuit créé : cadenas, et le
    /// toucher EXPLIQUE la règle (1 ton gratuit) avant de proposer Pro ou de modifier le ton existant.
    private var createCard: some View {
        let allowed = CustomToneStore.canCreate(hasPro: hasPro)
        let atCap = hasPro && !allowed
        return Button {
            if allowed { editorRoute = ToneEditorRoute(editing: nil) }
            else if !atCap { gateAlert = .limit }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: HZ.Radius.tile, style: .continuous)
                        .fill(allowed || atCap ? HZ.Colors.card : HZ.Colors.gold.opacity(0.06))
                    RoundedRectangle(cornerRadius: HZ.Radius.tile, style: .continuous)
                        .strokeBorder(allowed || atCap ? HZ.Colors.dash : HZ.Colors.gold.opacity(0.6),
                                      style: StrokeStyle(lineWidth: 1.6, dash: [6, 6]))
                    if allowed || atCap {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(atCap ? HZ.Colors.faint : HZ.Colors.ink)
                    } else {
                        HZLockMark(size: 26)
                    }
                }
                .aspectRatio(1.45, contentMode: .fit)
                Text(atCap
                     ? String(localized: "Limite de tons atteinte")
                     : allowed ? String(localized: "Générer un nouveau ton")
                               : String(localized: "Tons illimités avec Pro"))
                    .font(HZ.Fonts.strong)
                    .foregroundStyle(atCap ? HZ.Colors.faint : allowed ? HZ.Colors.ink : HZ.Colors.goldDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(atCap)
    }
}
