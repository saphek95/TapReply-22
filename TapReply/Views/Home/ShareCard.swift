import SwiftUI

// =============================================================================
// LES VISUELS DE PARTAGE — refonte Horizon 1.2.0
// Carte 1080×1080 pensée pour les stories : grande carte blanche posée sur un
// fond coloré, chiffre héros en Figtree, mascotte illustrée, pastilles de
// statut, badge « Fait en 1 double tap » et pied de marque. Le texte s'adapte
// à la statistique partagée. AUCUNE donnée personnelle (agrégats seulement).
// =============================================================================

/// Les 3 statistiques partageables (mêmes que les cartes du palmarès).
enum ShareKind: String, CaseIterable, Identifiable {
    case time, replies, percentile
    var id: String { rawValue }
}

/// Palettes de fond au choix de l'utilisateur (couleurs de la DA Horizon).
enum SharePalette {
    static let gradients: [[Color]] = [
        [Color(hex: 0x7B7FF5), Color(hex: 0x4B4FD9)],   // 0 — violet (défaut)
        [Color(hex: 0x3E8BFF), Color(hex: 0x1B54D6)],   // 1 — bleu
        [Color(hex: 0x2FD98A), Color(hex: 0x00A25B)],   // 2 — vert
        [Color(hex: 0xFFD84D), Color(hex: 0xFDAB3D)],   // 3 — soleil
        [Color(hex: 0xFF8A7A), Color(hex: 0xE2445C)],   // 4 — corail
        [Color(hex: 0xFFA8C8), Color(hex: 0xF5709C)],   // 5 — rose
        [Color(hex: 0x22C7EE), Color(hex: 0x009AAA)],   // 6 — cyan
        [Color(hex: 0x3A3B48), Color(hex: 0x1D1E28)],   // 7 — encre
    ]
    static func gradient(at index: Int) -> [Color] {
        gradients[max(0, min(index, gradients.count - 1))]
    }
}

/// Le visuel partagé — carré 1080×1080.
struct ShareCard: View {
    let kind: ShareKind
    let paletteIndex: Int
    let timeSaved: String        // « 2 h 34 »
    let repliesCount: Int
    let percentile: Int          // ex. 5 → « Top 5 % »
    /// Mascotte de l'utilisateur (index de couleur).
    var avatarIndex: Int = 0

    private func fig(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "Figtree-ExtraBold"
        case .bold:          name = "Figtree-Bold"
        case .semibold:      name = "Figtree-SemiBold"
        case .medium:        name = "Figtree-Medium"
        default:             name = "Figtree-Regular"
        }
        return .custom(name, size: size)
    }

    private var accent: Color { SharePalette.gradient(at: paletteIndex)[1] }

    /// Le kicker au-dessus du chiffre.
    private var kickerText: String {
        switch kind {
        case .time:       return String(localized: "TEMPS GAGNÉ")
        case .replies:    return String(localized: "RÉPONSES ÉCRITES")
        case .percentile: return String(localized: "MON NIVEAU")
        }
    }

    private var heroText: String {
        switch kind {
        case .time:       return timeSaved
        case .replies:    return "\(repliesCount)"
        case .percentile: return ReplyLevel.name(for: repliesCount)
        }
    }

    /// La phrase qui donne du sens au chiffre.
    private var subtitleText: String {
        switch kind {
        case .time:
            return String(localized: "que je n'ai pas passé à chercher mes mots")
        case .replies:
            return String(localized: "rédigées pour moi, sans quitter mes conversations")
        case .percentile:
            return String(localized: "mon niveau sur TapReply")
        }
    }

    /// La ligne de preuve, en bas de la carte blanche.
    private var proofText: String {
        switch kind {
        case .time:
            return String(localized: "\(repliesCount) réponses · 1 double tap chacune")
        case .replies:
            return String(localized: "\(timeSaved) de gagné · 1 double tap chacune")
        case .percentile:
            return String(localized: "\(repliesCount) réponses · \(timeSaved) de gagné")
        }
    }

    var body: some View {
        ZStack {
            // FOND coloré + halos doux
            LinearGradient(colors: SharePalette.gradient(at: paletteIndex),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.10)).frame(width: 620).offset(x: 320, y: -300)
            Circle().fill(.white.opacity(0.07)).frame(width: 420).offset(x: -300, y: 340)

            VStack(spacing: 0) {
                // EN-TÊTE de marque
                HStack(spacing: 18) {
                    Image("AvatarM\(max(0, min(avatarIndex, 8)))")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                    Text("TapReply")
                        .font(fig(52, .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 78)
                .padding(.top, 76)

                Spacer(minLength: 0)

                // LA CARTE BLANCHE — le cœur du visuel
                VStack(alignment: .leading, spacing: 0) {
                    Text(kickerText)
                        .font(fig(34, .semibold))
                        .kerning(3)
                        .foregroundStyle(accent)

                    Text(heroText)
                        .font(fig(kind == .replies ? 232 : 176, .heavy))
                        .foregroundStyle(Color(hex: 0x32333E))
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                        .padding(.top, 10)

                    Text(subtitleText)
                        .font(fig(48, .regular))
                        .foregroundStyle(Color(hex: 0x676879))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    // Pastilles de statut : la signature « board »
                    HStack(spacing: 14) {
                        Capsule().fill(Color(hex: 0x00C875)).frame(width: 92, height: 20)
                        Capsule().fill(Color(hex: 0xFFCB00)).frame(width: 58, height: 20)
                        Capsule().fill(accent).frame(width: 132, height: 20)
                    }
                    .padding(.top, 44)

                    Rectangle().fill(Color(hex: 0xE6E9EF))
                        .frame(height: 2)
                        .padding(.top, 44)

                    Text(proofText)
                        .font(fig(38, .medium))
                        .foregroundStyle(Color(hex: 0x9BA0AC))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 30)
                }
                .padding(66)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 66, style: .continuous))
                .padding(.horizontal, 78)

                Spacer(minLength: 0)

                // PIED : l'invitation à télécharger
                VStack(spacing: 14) {
                    Text(String(localized: "La réponse parfaite en un double tap"))
                        .font(fig(46, .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(String(localized: "TapReply sur l'App Store"))
                        .font(fig(36, .medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.bottom, 82)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

/// Rendu bitmap à la demande (jamais à chaque rendu de l'Accueil).
@MainActor
func makeShareImage(kind: ShareKind, paletteIndex: Int,
                    timeSaved: String, replies: Int, percentile: Int,
                    avatarIndex: Int = 0) -> UIImage? {
    let renderer = ImageRenderer(content: ShareCard(kind: kind,
                                                    paletteIndex: paletteIndex,
                                                    timeSaved: timeSaved,
                                                    repliesCount: replies,
                                                    percentile: percentile,
                                                    avatarIndex: avatarIndex))
    renderer.scale = 1
    return renderer.uiImage
}

// MARK: - Feuille d'aperçu AVANT partage (visuel + choix de couleur)

struct SharePreviewSheet: View {
    let kind: ShareKind
    let timeSaved: String
    let repliesCount: Int
    let percentile: Int

    @AppStorage(SettingsKeys.avatarColorIndex) private var avatarColorIndex = 0
    @State private var paletteIndex = 0
    @State private var shareImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible()), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Ton visuel"))
                        .font(HZ.Fonts.title)
                        .foregroundStyle(HZ.Colors.ink)
                    Text(String(localized: "Prêt pour tes stories."))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                }
                Spacer()
                HZCloseButton { dismiss() }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 20)

            // Aperçu à l'échelle (le vrai rendu fait 1080×1080)
            ShareCard(kind: kind, paletteIndex: paletteIndex,
                      timeSaved: timeSaved, repliesCount: repliesCount,
                      percentile: percentile, avatarIndex: avatarColorIndex)
                .scaleEffect(0.29)
                .frame(width: 1080 * 0.29, height: 1080 * 0.29)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .hzFloating()
                .padding(.top, 20)
                .animation(.snappy, value: paletteIndex)

            // Choix de la couleur de fond
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<SharePalette.gradients.count, id: \.self) { i in
                    Button {
                        paletteIndex = i
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: SharePalette.gradient(at: i),
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if paletteIndex == i {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                    Circle().strokeBorder(HZ.Colors.ink.opacity(0.7), lineWidth: 1.2)
                                        .padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 22)

            Spacer(minLength: 0)

            HZPrimaryButton(title: String(localized: "Partager"),
                            systemIcon: "square.and.arrow.up") {
                shareImage = makeShareImage(kind: kind, paletteIndex: paletteIndex,
                                            timeSaved: timeSaved, replies: repliesCount,
                                            percentile: percentile,
                                            avatarIndex: avatarColorIndex)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 18)
        }
        .background(HZ.Colors.sheet)
        .presentationDetents([.height(620)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: Binding(get: { shareImage != nil },
                                    set: { if !$0 { shareImage = nil } })) {
            if let img = shareImage {
                ActivityShareSheet(items: [shareText, img])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// Le texte qui accompagne l'image — pensé pour donner envie.
    private var shareText: String {
        switch kind {
        case .time:
            return String(localized: "\(timeSaved) que je n'ai pas passés à chercher mes mots. TapReply écrit mes réponses en un double tap ⚡️")
        case .replies:
            return String(localized: "\(repliesCount) réponses écrites pour moi sans quitter mes conversations. Un double tap, c'est tout ⚡️")
        case .percentile:
            return String(localized: "Niveau \(ReplyLevel.name(for: repliesCount)) sur TapReply. Merci TapReply ⚡️")
        }
    }
}

/// Niveau PERSONNEL, calculé sur ses seules réponses. Aucune comparaison avec d'autres utilisateurs : l'ancien
/// « Top X % des utilisateurs » était une estimation inventée présentée comme un fait (guideline 2.3.1).
enum ReplyLevel {
    static func name(for replies: Int) -> String {
        switch replies {
        case 0...5:     return String(localized: "Débutant")
        case 6...20:    return String(localized: "Habitué")
        case 21...50:   return String(localized: "Rapide")
        case 51...120:  return String(localized: "Expert")
        case 121...300: return String(localized: "Virtuose")
        default:        return String(localized: "Légende")
        }
    }
}
