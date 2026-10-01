import SwiftUI
import SwiftData

/// HISTORIQUE COMPLET — refonte Horizon 1.2.0.
/// Présenté en fullScreenCover (glisse depuis le bas, comme avant).
/// Façon boîte de réception : chips de FILTRE PAR TON en tête, groupement
/// par jour, lignes pastille + badge horaire, marqueur de fin de liste.
/// Swipe conservé : cœur (favori) et suppression.
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ReplyRecord.createdAt, order: .reverse) private var records: [ReplyRecord]

    /// Filtre actif : nil = tous · "fav" = favoris · sinon id de ton
    @State private var filter: String? = nil
    @State private var showToast = false

    var body: some View {
        VStack(spacing: 0) {
            // En-tête : titre + fermeture
            HStack {
                Text(String(localized: "Historique"))
                    .font(HZ.Fonts.title)
                    .foregroundStyle(HZ.Colors.ink)
                Spacer()
                HZCloseButton { dismiss() }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Chips : Tous · Favoris · un chip par ton utilisé
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HZFilterChip(label: String(localized: "Tous"),
                                 selected: filter == nil) {
                        withAnimation(.snappy) { filter = nil }
                    }
                    HZFilterChip(label: String(localized: "Favoris"),
                                 emoji: "❤️",
                                 selected: filter == "fav") {
                        withAnimation(.snappy) { filter = "fav" }
                    }
                    ForEach(usedToneIds, id: \.self) { toneId in
                        HZFilterChip(label: ToneDisplay.label(for: toneId),
                                     emoji: ToneItem.resolve(id: toneId)?.emoji,
                                     selected: filter == toneId) {
                            withAnimation(.snappy) { filter = toneId }
                        }
                    }
                }
                .padding(.horizontal, HZ.Spacing.gutter)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 4)

            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(HZ.Colors.page)
        .overlay(alignment: .top) {
            if showToast {
                ToastView(message: String(localized: "Copiée"))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Données filtrées

    /// Les tons réellement présents dans l'historique (ordre d'apparition).
    private var usedToneIds: [String] {
        var seen: [String] = []
        for r in records where !seen.contains(r.tone) {
            seen.append(r.tone)
        }
        return seen
    }

    private var filtered: [ReplyRecord] {
        switch filter {
        case nil: return records
        case "fav": return records.filter(\.isFavorite)
        case let toneId?: return records.filter { $0.tone == toneId }
        }
    }

    /// Groupes (jour, réponses) — du plus récent au plus ancien.
    private var groups: [(day: Date, items: [ReplyRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return String(localized: "Aujourd'hui") }
        if Calendar.current.isDateInYesterday(day) { return String(localized: "Hier") }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
            .capitalized(with: .current)
    }

    // MARK: - Liste (List native conservée : le swipe système est irremplaçable)

    private var list: some View {
        List {
            ForEach(groups, id: \.day) { group in
                Section {
                    ForEach(group.items) { record in
                        HistoryRowView(record: record) { copy(record) }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: HZ.Spacing.gutter,
                                                      bottom: 5, trailing: HZ.Spacing.gutter))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    context.delete(record)
                                    try? context.save()
                                } label: {
                                    Label(String(localized: "Supprimer"), systemImage: "trash.fill")
                                }
                                .tint(HZ.Colors.alarm)
                                Button {
                                    record.isFavorite.toggle()
                                    try? context.save()
                                } label: {
                                    Label(String(localized: "Favori"),
                                          systemImage: record.isFavorite ? "heart.slash.fill" : "heart.fill")
                                }
                                .tint(Color(hex: 0xE8324F))
                            }
                            // Réponse générée par IA : on peut la signaler (contenu inapproprié, faux, choquant).
                            .contextMenu {
                                Button { copy(record) } label: {
                                    Label(String(localized: "Copier"), systemImage: "doc.on.doc")
                                }
                                Button { AIReport.open(reply: record.reply) } label: {
                                    Label(String(localized: "Signaler cette réponse"), systemImage: "exclamationmark.bubble")
                                }
                            }
                    }
                } header: {
                    Text(dayLabel(group.day))
                        .font(HZ.Fonts.strong)
                        .foregroundStyle(HZ.Colors.ink)
                        .textCase(nil)
                        .padding(.leading, 2)
                }
            }

            // Fin de liste, façon boîte de réception
            HZEndMarker(title: String(localized: "Tu as tout vu."),
                        subtitle: String(localized: "Aucune réponse plus ancienne."))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(HZ.Colors.faint)
            Text(String(localized: "Rien ici pour l'instant"))
                .font(HZ.Fonts.section)
                .foregroundStyle(HZ.Colors.ink)
            Text(filter == nil
                 ? String(localized: "Tes réponses générées apparaîtront ici.")
                 : String(localized: "Aucune réponse ne correspond à ce filtre."))
                .font(HZ.Fonts.body)
                .foregroundStyle(HZ.Colors.sub)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HZ.Spacing.gutter)
    }

    // MARK: - Copie

    private func copy(_ record: ReplyRecord) {
        UIPasteboard.general.string = record.reply
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showToast = false }
        }
    }
}

/// Signalement d'une réponse générée par l'IA : un e-mail prérempli vers le support (l'utilisateur voit et
/// choisit ce qu'il envoie). Guideline 1.2 / contenu généré par IA : un moyen de signaler doit exister.
enum AIReport {
    static func open(reply: String) {
        let subject = String(localized: "Signalement d'une réponse TapReply")
        let body = String(localized: "Réponse signalée :") + "\n\n" + String(reply.prefix(1_200)) + "\n\n" + String(localized: "Ce qui ne va pas :") + "\n"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = "contact@saphek.com"
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        // Pas d'app Mail configurée (fréquent sur les appareils de test) :
        // repli sur la page d'assistance, qui donne l'adresse de contact.
        guard let url = c.url else { UIApplication.shared.open(Config.supportURL); return }
        UIApplication.shared.open(url) { ok in
            if !ok { UIApplication.shared.open(Config.supportURL) }
        }
    }
}
