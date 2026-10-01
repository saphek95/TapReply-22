import SwiftUI

// =============================================================================
// ACTE 2 — LE BROUILLON, EN TROIS TEMPS
// =============================================================================
//
// L'ordre est impératif (validé le 13/09) : on CHOISIT l'idée → elle s'écrit
// dans le champ et on comprend que c'est le brouillon → on fait le GESTE → et
// seulement ensuite la réponse apparaît, avec les mots du brouillon surlignés.
// Chaque temps est séparé par une action de l'utilisateur ; rien ne se
// superpose.
//
// TapTap reste à sa place autour de l'iPhone géant (même mise en page que S5–S7) :
// il lit le brouillon (V22), attend qu'on tape le dos (V15), lit et écrit (V22),
// désigne la phrase (V51). Puis il part dans un pouf vers l'acte 3.
// =============================================================================

struct Onb3Draft: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    private enum Phase { case choose, gesture, writing, done }
    @State private var phase: Phase = .choose
    @State private var stage: PhoneStage = .front
    @State private var chosen: [String] = []
    @State private var typedDraft = ""
    @State private var typedReply = ""
    @State private var working = false
    @State private var ripple = 0
    @State private var typingTask: Task<Void, Never>? = nil
    @State private var gestureFired = false

    private var accent: Color { draft.accent }
    private let question = String(localized: "On se voit ce soir ?")
    private let chips = [String(localized: "pas ce soir"), String(localized: "demain plutôt"), String(localized: "trop fatigué")]

    /// La phrase produite reprend les idées choisies : on VOIT que le brouillon est conservé et habillé.
    private var produced: String {
        let has = { (i: Int) in chosen.contains(chips[i]) }
        switch (has(0), has(1), has(2)) {
        case (_, true, true):      return String(localized: "Pas ce soir, je suis trop fatigué… mais demain plutôt, avec plaisir !")
        case (true, true, false):  return String(localized: "Pas ce soir, mais demain plutôt, avec plaisir !")
        case (true, false, true):  return String(localized: "Pas ce soir, je suis trop fatigué. On se rattrape très vite ?")
        case (false, true, false): return String(localized: "Ce soir c'est compliqué, demain plutôt ? Je suis libre.")
        case (false, false, true): return String(localized: "Je suis trop fatigué ce soir, désolé. On remet ça ?")
        default:                   return String(localized: "Pas ce soir malheureusement, mais bientôt promis !")
        }
    }

    var body: some View {
        PhoneActScaffold(stage: stage, accent: accent,
                         tapEnabled: phase == .gesture, ripple: ripple, onDoubleTap: gesture) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "TES IDÉES. SES MOTS."))
                    .font(HZ.Fonts.fig(12.5, .bold)).tracking(1.3).foregroundStyle(accent)
                Text(headline)
                    .font(HZ.Fonts.fig(21, .bold))
                    .foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(phase)
                    .transition(.opacity)
            }
            .padding(.top, 6)
            .animation(.spring(duration: 0.45), value: phase)
        } front: {
            GeometryReader { g in
                GiantConversation(width: g.size.width, received: [question],
                                  typedDraft: typedDraft, draftLabel: true,
                                  reply: (phase == .writing || phase == .done) && !typedReply.isEmpty ? typedReply : nil,
                                  replySent: false,
                                  working: working,
                                  accent: accent,
                                  highlightWords: chosen)
            }
        } footer: {
            footer
                .animation(.spring(duration: 0.45), value: phase)
        }
    }

    @ViewBuilder private var footer: some View {
        switch phase {
        case .choose:
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Ton brouillon : choisis ce que tu veux lui dire, en un mot."))
                    .font(HZ.Fonts.fig(14, .semibold)).foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { c in
                        let on = chosen.contains(c)
                        Button { toggle(c) } label: {
                            Text(c)
                                .font(HZ.Fonts.fig(13.5, .bold))
                                .foregroundStyle(on ? .white : accent)
                                .padding(.horizontal, 13).frame(height: 34)
                                .background(Capsule().fill(on ? accent : accent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .disabled(chosen.count >= 2 && !on)
                    }
                    Spacer(minLength: 0)
                }
                OnbButton(title: String(localized: "C'est mon idée"), icon: "arrow.right", fill: accent,
                          enabled: !chosen.isEmpty) { toGesture() }
                    .padding(.top, 6)
            }
            .transition(.opacity)
        case .gesture:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 14, weight: .bold))
                    Text(String(localized: "Maintenant, appelle-moi : deux taps au dos.")).font(HZ.Fonts.fig(16, .bold))
                }
                .foregroundStyle(accent)
                .multilineTextAlignment(.center)
                Text(String(localized: "Ton brouillon reste dans le champ, il ne part pas."))
                    .font(HZ.Fonts.fig(13.5, .medium)).foregroundStyle(HZ.Colors.sub)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
            .transition(.opacity)
        case .writing:
            Text(String(localized: "J'écris…"))
                .font(HZ.Fonts.fig(15, .bold)).foregroundStyle(HZ.Colors.sub)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                .transition(.opacity)
        case .done:
            VStack(spacing: 12) {
                Text(String(localized: "Ton brouillon ne part jamais tel quel : il me sert de consigne. Tu relis, tu ajustes, tu envoies."))
                    .font(HZ.Fonts.fig(14.5, .semibold)).foregroundStyle(HZ.Colors.sub)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                OnbButton(title: String(localized: "J'ai compris, on continue"), icon: "arrow.right", fill: accent) { leave() }
                OnbLink(title: String(localized: "Revoir")) { restart() }
            }
            .transition(.opacity)
        }
    }

    private var headline: String {
        switch phase {
        case .choose:  return String(localized: "Tu sais quoi dire, pas comment le dire ? Écris juste l'idée. Je fais la phrase.")
        case .gesture: return String(localized: "Ton idée est dans le champ. C'est ton brouillon.")
        case .writing: return String(localized: "Je garde ton idée, et je l'habille.")
        case .done:    return String(localized: "Voilà. Le fond est le tien, la forme est la mienne.")
        }
    }

    /// Temps 1 : chaque chip s'écrit dans le champ, lettre par lettre ; TapTap lit.
    private func toggle(_ chip: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let i = chosen.firstIndex(of: chip) { chosen.remove(at: i) } else { chosen.append(chip) }
        let target = chosen.joined(separator: ", ")
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            typedDraft = ""
            for ch in target {
                guard !Task.isCancelled else { return }
                typedDraft.append(ch); try? await Task.sleep(for: .milliseconds(22))
            }
        }
    }

    /// Temps 2 : l'iPhone se retourne, TapTap invite.
    private func toGesture() {
        withAnimation { phase = .gesture }
        stage = .backInvite
    }

    private func gesture() {
        guard phase == .gesture, !gestureFired else { return }
        gestureFired = true
        ripple += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            ripple += 1
            try? await Task.sleep(for: .milliseconds(650))
            // Temps 3 : retour face, il lit le brouillon, ça travaille, la phrase s'écrit.
            withAnimation { phase = .writing }
            stage = .front
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation { working = true }
            try? await Task.sleep(for: .milliseconds(1_600))
            withAnimation { working = false }
            typedReply = ""
            let sentence = produced
            for ch in sentence { typedReply.append(ch); try? await Task.sleep(for: .milliseconds(24)) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { phase = .done }
        }
    }

    /// Vers l'acte 3 : le metteur en scène le fera réapparaître dans un pouf (la scène iPhone se démonte ici).
    private func leave() {
        guard phase == .done else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onNext()
    }

    private func restart() {
        typingTask?.cancel(); gestureFired = false
        chosen = []; typedDraft = ""; typedReply = ""; working = false; stage = .front
        withAnimation { phase = .choose }
    }
}
