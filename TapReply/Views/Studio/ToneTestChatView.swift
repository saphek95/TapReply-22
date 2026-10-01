import SwiftUI

/// MODE TEST D'UN TON — refonte Horizon 1.2.0.
/// Un chat plein écran : tu écris comme si tu étais l'AUTRE personne, l'IA te
/// répond avec le ton testé — en temps réel, via la même Edge Function que le
/// double tap. Si le ton ne sonne pas juste : retour à l'éditeur, et on reteste.
///
/// Coût : chaque envoi est un appel réel (débité comme une génération).
/// Pour un ton personnalisé, le premier échange réussi est mis en cache comme
/// EXEMPLE de la fiche du ton.
struct ToneTestChatView: View {
    let tone: ToneItem

    @Environment(\.dismiss) private var dismiss

    private struct ChatMessage: Identifiable {
        enum Role { case user, ai, error }
        let id = UUID()
        let role: Role
        let text: String
        /// Plus de crédits : on propose directement les offres (on est déjà dans l'app).
        var needsPaywall = false
    }

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isThinking = false
    @State private var showConsent = false
    @State private var showPaywall = false
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false
    @FocusState private var inputFocused: Bool

    /// Suggestions de départ, variées (amical / logistique / pro / rencontre).
    private let suggestions: [String] = [
        String(localized: "Salut, ça va ?"),
        String(localized: "On mange quoi ce soir ?"),
        String(localized: "Peux-tu m'envoyer le dossier avant demain ?"),
        String(localized: "T'es libre samedi ?"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        intro
                            .padding(.top, 8)
                            .padding(.bottom, 12)

                        ForEach(messages) { message in
                            bubble(message)
                        }

                        if isThinking {
                            typingBubble
                        }

                        // Suggestions tant que la conversation n'a pas commencé
                        if messages.isEmpty && !isThinking {
                            suggestionsBlock
                                .padding(.top, 14)
                        }

                        Color.clear.frame(height: 1).id("chat.bottom")
                    }
                    .padding(.horizontal, HZ.Spacing.gutter)
                    .padding(.bottom, 12)
                }
                // Même traitement que le terrain d'essai : on referme le
                // clavier en défilant, et le champ remonte quand il s'ouvre.
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: inputFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("chat.bottom", anchor: .bottom)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("chat.bottom", anchor: .bottom) }
                }
                .onChange(of: isThinking) { _, _ in
                    withAnimation { proxy.scrollTo("chat.bottom", anchor: .bottom) }
                }
                .onTapGesture { inputFocused = false }
            }

            inputBar
        }
        .background(HZ.Colors.sheet)
        .sheet(isPresented: $showConsent) { ConsentSheet(accepted: $consentAccepted) }
        .sheet(isPresented: $showPaywall) { ProPaywall { showPaywall = false } }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                // Badge TEST MODE
                Text(String(localized: "TEST MODE"))
                    .font(HZ.Fonts.fig(13, .heavy))
                    .kerning(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(HZ.Gradients.spark, in: Capsule())
                    .hzSoft()

                HStack {
                    ToneDotView(tone: tone, size: 34)
                    Spacer()
                    HZCloseButton { dismiss() }
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.top, 14)

            VStack(spacing: 3) {
                Text(String(localized: "Test du ton « \(tone.title) »"))
                    .font(HZ.Fonts.section)
                    .foregroundStyle(HZ.Colors.ink)
                Text(String(localized: "Écris un message reçu : l'IA te répond avec ce ton, comme elle le fera en vrai."))
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.bottom, 10)

            HZHairline()
        }
    }

    private var intro: some View {
        Text(String(localized: "Nouveaux messages"))
            .font(HZ.Fonts.caption)
            .foregroundStyle(HZ.Colors.faint)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Bulles

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            // MOI qui écris → bulle à DROITE (comme dans une vraie conversation)
            HZChatBubble(text: message.text, kind: .outgoing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .ai:
            // La réponse générée par l'IA dans le ton testé → bulle à GAUCHE,
            // avec la mascotte et le nom du ton pour qu'on comprenne d'où
            // elle vient.
            HStack(alignment: .bottom, spacing: 8) {
                ToneDotView(tone: tone, size: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) {
                        Text(String(localized: "Généré · ton \(tone.title)"))
                            .font(HZ.Fonts.fig(11, .semibold))
                            .foregroundStyle(HZ.Colors.faint)
                        // Signalement visible (guideline 1.2 / contenu IA), pas
                        // seulement dans le menu d'appui long.
                        Button { AIReport.open(reply: message.text) } label: {
                            Label(String(localized: "Signaler"), systemImage: "flag")
                                .font(HZ.Fonts.fig(11, .semibold))
                                .foregroundStyle(HZ.Colors.faint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 4)
                    HZChatBubble(text: message.text, kind: .incoming)
                        .contextMenu {
                            Button { UIPasteboard.general.string = message.text } label: {
                                Label(String(localized: "Copier"), systemImage: "doc.on.doc")
                            }
                            Button { AIReport.open(reply: message.text) } label: {
                                Label(String(localized: "Signaler cette réponse"), systemImage: "exclamationmark.bubble")
                            }
                        }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .error:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(HZ.Colors.alarm)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.alarm)
                    if message.needsPaywall {
                        Button { showPaywall = true } label: {
                            Text(String(localized: "Voir les offres"))
                                .font(HZ.Fonts.fig(13, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(HZ.Colors.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(HZ.Colors.alarm.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var typingBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ToneDotView(tone: tone, size: 28)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(HZ.Colors.sub.opacity(0.55))
                        .frame(width: 7, height: 7)
                        .modifier(TypingDotBounce(delay: Double(i) * 0.18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(HZ.Colors.card,
                        in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6,
                                                   bottomTrailingRadius: 20, topTrailingRadius: 20,
                                                   style: .continuous))
            Spacer(minLength: 48)
        }
    }

    // MARK: - Suggestions

    /// Suggestions = des messages que J'ENVOIE → alignées à droite.
    private var suggestionsBlock: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(suggestions, id: \.self) { s in
                Button {
                    send(s)
                } label: {
                    Text(s)
                        .font(HZ.Fonts.strong)
                        .foregroundStyle(HZ.Colors.blue)
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(HZ.Colors.blue.opacity(0.45), lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Barre de saisie

    private var inputBar: some View {
        VStack(spacing: 0) {
            HZHairline()
            HStack(spacing: 10) {
                TextField(String(localized: "Message…"), text: $input, axis: .vertical)
                    .font(HZ.Fonts.body)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(HZ.Colors.card,
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    send(input)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(canSend ? HZ.Colors.blue : HZ.Colors.faint, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.vertical, 10)
        }
        .background(HZ.Colors.sheet)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    // MARK: - Envoi (appel réel de l'Edge Function, avec LE ton testé)

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        // Le test de ton envoie aussi du texte à l'IA tierce : même accord que le double tap (guideline 5.1.2(i)).
        guard consentAccepted else { showConsent = true; return }
        input = ""
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(ChatMessage(role: .user, text: text))
            isThinking = true
        }

        Task {
            do {
                let reply = try await ToneTestClient.reply(tone: tone, history: chatHistory())
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isThinking = false
                        messages.append(ChatMessage(role: .ai, text: reply))
                    }
                    // Ton personnalisé : le dernier échange réussi devient
                    // l'exemple de la fiche.
                    if case .custom(let custom) = tone {
                        CustomToneStore.recordExample(toneID: custom.id, them: text, me: reply)
                        NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isThinking = false
                        let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        var noCredits = false
                        if case .noCredits = error as? GenerationClient.GenerationError { noCredits = true }
                        messages.append(ChatMessage(role: .error, text: msg, needsPaywall: noCredits))
                    }
                }
            }
        }
    }

    /// La conversation de test vue du pipeline : ce que TU écris joue le rôle
    /// de l'AUTRE (THEM) ; les réponses de l'IA sont les tiennes (ME).
    private func chatHistory() -> [(sender: String, text: String)] {
        messages.compactMap { m -> (sender: String, text: String)? in
            switch m.role {
            case .user: return (sender: "them", text: m.text)
            case .ai: return (sender: "me", text: m.text)
            case .error: return nil
            }
        }
    }
}

/// Rebond des points de frappe.
private struct TypingDotBounce: ViewModifier {
    let delay: Double
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .offset(y: up ? -4 : 2)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay),
                       value: up)
            .onAppear { up = true }
    }
}

// MARK: - Client du mode Test

/// Appelle la MÊME Edge Function que le double tap, mais avec le ton TESTÉ
/// (préréglage → `tone`, personnalisé → `tone: auto` + `customToneInstruction`,
/// convention identique à GenerationClient). Texte seul, jamais d'image.
enum ToneTestClient {

    private struct Body: Encodable {
        struct Msg: Encodable { let sender: String; let text: String }
        let messages: [Msg]
        let tone: String
        let customToneInstruction: String?
        let targetLocale: String?
        let appSource: String?
        let inputFieldState: String?
        let appUserId: String?
    }

    private struct Response: Decodable {
        let reply: String?
        let error: String?
        let detail: String?
    }

    static func reply(tone: ToneItem,
                      history: [(sender: String, text: String)]) async throws -> String {
        guard AppSettings.consentAccepted else { throw ReplyPipeline.PipelineError.consentMissing }
        guard let uid = await PurchaseService.appUserID else { throw GenerationClient.GenerationError.notReady }
        let locales = AppSettings.replyLocales
        let body = Body(
            messages: history.map { .init(sender: $0.sender, text: $0.text) },
            // Fact Checker : « auto » + son instruction, comme le double tap (sinon le test RÉPONDAIT au message).
            tone: tone.backendTone.backendValue,
            customToneInstruction: tone.customInstruction ?? tone.backendTone.presetInstruction,
            targetLocale: locales.isEmpty ? nil : locales.joined(separator: ","),
            appSource: "unknown",
            // Déterministe : pas de brouillon, réponds au dernier message.
            inputFieldState: ParsedConversation.InputFieldState.emptyWithPlaceholder.rawValue,
            appUserId: uid
        )

        return GenerationClient.withoutEmDash(try await GenerationClient.send(body, timeout: 25))
    }
}
