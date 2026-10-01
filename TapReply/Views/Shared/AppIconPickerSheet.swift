import SwiftUI

/// Sélecteur d'ICÔNE D'APP (écran d'accueil iOS) — DA Horizon 1.2.0.
///
/// L'icône TapReply est la mascotte qui « peek » du bas avec sa bulle de
/// message. Deux familles :
/// - GRATUITES : 5 déclinaisons de couleur (violet = icône principale).
/// - PREMIUM : 4 icônes exclusives, réservées aux abonnés Pro. Verrouillées
///   avec un CADENAS or si l'abonnement est absent ; marquées d'une COURONNE
///   or (même langage fait main) dès qu'il est actif.
///
/// Utilise UIApplication.setAlternateIconName (nil = icône principale).
/// ⚠️ Nécessite dans Xcode : Build Settings → « Include All App Icon Assets » = Yes.
struct AppIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = HZTheme.shared
    @ObservedObject private var purchases = PurchaseService.shared
    @State private var current: String? = UIApplication.shared.alternateIconName
    @State private var showPaywall = false
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 12

    private struct IconOption: Identifiable {
        let id: String              // nom d'asset alternatif ("" = principale)
        let label: String
        let preview: String
        var premium: Bool = false
        var alternateName: String? { id.isEmpty ? nil : id }
    }

    private let freeOptions: [IconOption] = [
        IconOption(id: "", label: String(localized: "Violet"), preview: "IconPreviewViolet"),
        IconOption(id: "AppIconBleu", label: String(localized: "Bleu"), preview: "IconPreviewBleu"),
        IconOption(id: "AppIconVert", label: String(localized: "Vert"), preview: "IconPreviewVert"),
        IconOption(id: "AppIconCorail", label: String(localized: "Corail"), preview: "IconPreviewCorail"),
        IconOption(id: "AppIconEncre", label: String(localized: "Encre"), preview: "IconPreviewEncre"),
    ]

    private let premiumOptions: [IconOption] = [
        IconOption(id: "AppIconMenthe", label: String(localized: "Menthe"), preview: "IconPreviewMenthe", premium: true),
        IconOption(id: "AppIconRose", label: String(localized: "Bonbon"), preview: "IconPreviewRose", premium: true),
        IconOption(id: "AppIconRoyal", label: String(localized: "Royal"), preview: "IconPreviewRoyal", premium: true),
        IconOption(id: "AppIconFlamme", label: String(localized: "Flamme"), preview: "IconPreviewFlamme", premium: true),
    ]

    private var isPro: Bool { purchases.isConfigured && purchases.isPro }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Icône de l'app"))
                            .font(HZ.Fonts.title)
                            .foregroundStyle(HZ.Colors.ink)
                        Text(String(localized: "Elle apparaîtra sur ton écran d'accueil."))
                            .font(HZ.Fonts.sub)
                            .foregroundStyle(HZ.Colors.sub)
                    }
                    Spacer()
                    HZCloseButton { dismiss() }
                }
                .padding(.bottom, 22)

                // ① Icônes incluses
                HZKicker(text: String(localized: "Incluses"))
                    .padding(.bottom, 12)
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(freeOptions) { tile($0) }
                }
                .padding(.bottom, 28)

                // ② Icônes PREMIUM
                HStack(spacing: 7) {
                    HZKicker(text: String(localized: "Exclusives Pro"))
                    HZCrownMark(size: 13)
                        .offset(y: -1)
                }
                .padding(.bottom, 4)
                Text(isPro
                     ? String(localized: "Débloquées par ton abonnement. Merci ✨")
                     : String(localized: "Réservées aux abonnés Pro."))
                    .font(HZ.Fonts.caption)
                    .foregroundStyle(isPro ? HZ.Colors.goldDeep : HZ.Colors.faint)
                    .padding(.bottom, 12)

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(premiumOptions) { tile($0) }
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(HZ.Colors.sheet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            ProPaywall { showPaywall = false }
                .background(DS.Colors.page)
        }
    }

    // MARK: - Vignette d'icône

    @ViewBuilder
    private func tile(_ option: IconOption) -> some View {
        let locked = option.premium && !isPro
        let selected = current == option.alternateName

        Button {
            if locked {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showPaywall = true
            } else {
                select(option)
            }
        } label: {
            VStack(spacing: 8) {
                Image(option.preview)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    // Verrouillée : voile blanc + cadenas or à main levée
                    .overlay {
                        if locked {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.62))
                            HZLockMark(size: 26)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected ? HZ.Colors.blue
                                          : (option.premium ? HZ.Colors.gold.opacity(0.55) : HZ.Colors.line),
                                          lineWidth: selected ? 3 : 1.2)
                    }
                    // Débloquée par l'abonnement : la couronne se perche
                    .overlay(alignment: .topTrailing) {
                        if option.premium && isPro {
                            HZCrownMark(size: 16)
                                .offset(x: 3, y: -7)
                        }
                    }
                    .hzSoft()

                Text(option.label)
                    .font(HZ.Fonts.fig(12.5, .semibold))
                    .foregroundStyle(locked ? HZ.Colors.faint
                                     : (selected ? HZ.Colors.ink : HZ.Colors.sub))
            }
        }
        .buttonStyle(.plain)
    }

    private func select(_ option: IconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateName) { error in
            if error == nil {
                DispatchQueue.main.async {
                    withAnimation(.snappy) { current = option.alternateName }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}
