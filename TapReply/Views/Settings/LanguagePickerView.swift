import SwiftUI

/// Sélecteur de langues de réponse — recherche + multi-sélection.
/// 0 langue = automatique · 1 = forcée · 2+ = l'IA choisit la plus adaptée
/// au contexte parmi la sélection.
struct LanguagePickerView: View {
    @AppStorage(SettingsKeys.replyLanguages) private var replyLanguages = ""
    @State private var search = ""

    private var selected: Set<String> {
        Set(replyLanguages.split(separator: ",").map(String.init))
    }

    private var filtered: [AppLanguage] {
        let q = search.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !q.isEmpty else { return AppLanguage.all }
        return AppLanguage.all.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(q)
                || $0.native.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(q)
        }
    }

    var body: some View {
        List {
            // Mode automatique — toujours en tête, hors recherche
            if search.isEmpty {
                Section {
                    Button { setSelection([]) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Automatique"))
                                    .font(DS.Fonts.body(16, weight: .semibold))
                                    .foregroundColor(DS.Colors.ink)
                                Text(String(localized: "Répond dans la langue de la conversation"))
                                    .font(DS.Fonts.body(12))
                                    .foregroundColor(DS.Colors.inkTertiary)
                            }
                            Spacer()
                            if selected.isEmpty {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DS.Colors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                } footer: {
                    Text(String(localized: "Sélectionne une langue pour toujours répondre dans celle-ci. Sélectionnes-en plusieurs et TapReply choisira la plus adaptée au contexte de chaque conversation."))
                }
            }

            Section(search.isEmpty ? String(localized: "Langues") : String(localized: "Résultats")) {
                ForEach(filtered) { lang in
                    Button { toggle(lang.code) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.name)
                                    .font(DS.Fonts.body(16))
                                    .foregroundColor(DS.Colors.ink)
                                if lang.native != lang.name {
                                    Text(lang.native)
                                        .font(DS.Fonts.body(12))
                                        .foregroundColor(DS.Colors.inkTertiary)
                                }
                            }
                            Spacer()
                            if selected.contains(lang.code) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DS.Colors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .searchable(text: $search,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: String(localized: "Rechercher une langue"))
        .navigationTitle(String(localized: "Langues de réponse"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ code: String) {
        var s = selected
        if s.contains(code) { s.remove(code) } else { s.insert(code) }
        setSelection(s)
    }

    private func setSelection(_ s: Set<String>) {
        // Ordre stable = ordre du catalogue
        replyLanguages = AppLanguage.all.map(\.code).filter { s.contains($0) }.joined(separator: ",")
    }
}

/// Résumé affiché dans la ligne des Réglages ("Automatique", "Français",
/// "Français + Anglais", "3 langues"…)
enum LanguageSummary {
    static func text(for stored: String) -> String {
        let codes = stored.split(separator: ",").map(String.init)
        let names = codes.compactMap { AppLanguage.named($0)?.name }
        switch names.count {
        case 0: return String(localized: "Automatique")
        case 1: return names[0]
        case 2: return "\(names[0]) + \(names[1])"
        default: return String(localized: "\(names.count) langues")
        }
    }
}
