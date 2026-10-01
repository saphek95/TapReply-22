import SwiftUI

/// Sélecteur de couleur de TAPTAP — feuille compacte. Indépendante de la couleur de l'app (l'onboarding met la
/// même aux deux ; ici on peut les dépareiller).
/// Accessible depuis l'avatar de l'Accueil ET depuis Réglages → Préférences.
struct AvatarColorPicker: View {
    @AppStorage(SettingsKeys.avatarColorIndex) private var savedIndex = 0
    @State private var selection = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "Ta mascotte"))
                .font(DS.Fonts.title2)
                .foregroundStyle(DS.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.s6)

            // L'aperçu est le TapTap vectoriel dans la couleur touchée ; il joue la pose de cette couleur.
            // La POSE de la couleur, fixe (dernière image de sa réaction) : dans les Réglages, pas de gag ni de saut.
            TapTapFigure(size: 150,
                         beats: [.still(TapTapClips.reactionCouleur[min(selection, 8)])],
                         accent: Color(hex: UInt(HZTheme.presets[min(selection, HZTheme.presets.count - 1)])))
                .id(selection)
                .padding(.top, DS.Spacing.s6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                      spacing: 12) {
                ForEach(0..<AvatarPalette.colors.count, id: \.self) { i in
                    Button {
                        selection = i
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Circle()
                            .fill(AvatarPalette.color(at: i))
                            .frame(width: 40, height: 40)
                            .overlay {
                                if selection == i {
                                    Circle()
                                        .stroke(AvatarPalette.color(at: i), lineWidth: 2.5)
                                        .frame(width: 50, height: 50)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.top, DS.Spacing.s6)

            Spacer(minLength: 0)

            WPrimaryButton(title: String(localized: "Enregistrer")) {
                // La couleur de TAPTAP seule (celle de l'app se règle juste en dessous, dans les Réglages).
                TapTapColor.applyMascot(index: selection)
                savedIndex = selection
                dismiss()
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.bottom, DS.Spacing.s5)
        }
        .background(DS.Colors.page)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .onAppear { selection = TapTapColor.index }
    }
}
