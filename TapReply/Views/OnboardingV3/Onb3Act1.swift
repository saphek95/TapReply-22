import SwiftUI

// =============================================================================
// ACTE 1 — LE PROBLÈME, PUIS LA MAGIE (autour de l'iPhone géant)
// =============================================================================
//
// S4 : la bulle de Marie tombe, le champ reste vide, 40 secondes passent.
//      TapTap (Guide, en bas à gauche) sursaute, sort une montre à gousset
//      géante, la range. Un gag, puis le calme.
// S5 : l'iPhone géant apparaît (dessiné par l'app), TapTap le présente.
// S6 : la démo en quatre temps : conversation → l'iPhone se retourne, TapTap
//      tape deux fois le dos (deux fois de suite, pour que le geste se lise) →
//      retour face, il lit, la réponse s'écrit, il la désigne → à toi de relire
//      et d'envoyer. Chaque temps est séparé par « Suivant ».
// S7 : à toi : l'iPhone est déjà retourné, TapTap invite (V15). Tu tapes deux
//      fois sur son dos. Même enchaînement, réponse dans le champ.
//
// RÈGLE : les quatre écrans iPhone (S5, S6, S7, S8) partagent EXACTEMENT la
// même mise en page (PhoneActScaffold) : l'iPhone et TapTap ne bougent pas
// d'un écran à l'autre — seuls les textes changent.
// =============================================================================

// MARK: - S4 · Ça t'arrive ?

struct Onb3Situation: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var dropped = false
    @State private var seconds = 0
    @State private var gag = 0      // 0 = arrive · 1 = sursaut + montre · 2 = calme
    @State private var showText = false

    private var accent: Color { draft.accent }

    var body: some View {
        GeometryReader { geo in
            let guide = TapTapScale.guide(geo.size)
            VStack(alignment: .leading, spacing: 0) {
                OnbTypewriter(text: String(localized: "Tu sais quoi dire.\nPas comment le dire."),
                              font: HZ.Fonts.fig(28, .heavy))
                    .padding(.top, 10)

                GiantIncomingBubble(text: String(localized: "On se voit ce soir ?"),
                                    sender: String(localized: "Marie"),
                                    dropped: dropped, accent: accent)
                    .padding(.top, 22)

                WaitingField(seconds: seconds, accent: accent)
                    .padding(.top, 14)
                    .opacity(dropped ? 1 : 0)

                if showText {
                    Text(String(localized: "Tu as l'idée : « pas ce soir, plutôt demain ». La phrase, elle, ne vient pas. 40 secondes, et rien d'envoyé."))
                        .font(HZ.Fonts.fig(15, .semibold))
                        .foregroundStyle(HZ.Colors.sub)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 10)

                HStack(alignment: .bottom, spacing: 14) {
                    // TapTap arrive en marchant depuis la gauche (T1), s'arrête, puis réagit à la bulle.
                    TapTapSlot(height: guide, beats: beats, accent: accent, transit: .exit)
                    if showText {
                        TapTapBubble(text: String(localized: "C'est là que j'interviens : j'écris la réponse, toi tu l'envoies."),
                                     accent: accent, tail: .none, typing: false)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 14)

                OnbButton(title: String(localized: "Montre-moi"), icon: "sparkles", fill: accent,
                          enabled: showText, action: onNext)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 26)
            .task {
                // T1 : l'arrivée en marchant prend ~1,5 s. La bulle tombe ensuite, et il sursaute en la voyant.
                try? await Task.sleep(for: .milliseconds(1_700))
                withAnimation { dropped = true }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                try? await Task.sleep(for: .milliseconds(220))
                gag = 1
                // Le compteur monte pendant qu'il sort sa montre.
                for s in stride(from: 4, through: 40, by: 4) {
                    try? await Task.sleep(for: .milliseconds(260))
                    withAnimation(.easeOut(duration: 0.2)) { seconds = s }
                }
                withAnimation(.spring(duration: 0.5)) { showText = true }
            }
        }
    }

    private var beats: [TapTapBeat] {
        switch gag {
        case 0:  return [.loop(TapTapClips.idle)]
        default: return [.play(TapTapClips.sursaut, speed: 1.1, holdMs: 350), .play(TapTapClips.montreSortie, speed: 1.15),
                         .play(TapTapClips.montreRange, speed: 1.15), .loop(TapTapClips.idle)]
        }
    }
}

// MARK: - La mise en page commune des écrans iPhone

/// Hauteur de l'en-tête des quatre écrans iPhone (S5 → S8) : identique pour que l'iPhone ne bouge pas.
let phoneActHeaderHeight: CGFloat = 132

/// En-tête de hauteur FIXE, iPhone géant à droite (même place sur les quatre écrans), pied libre.
struct PhoneActScaffold<Header: View, Front: View, Footer: View>: View {
    var stage: PhoneStage
    var accent: Color
    var tapEnabled: Bool = false
    var ripple: Int = 0
    var onDoubleTap: () -> Void = {}
    var arrival: Bool = false
    @ViewBuilder var header: Header
    @ViewBuilder var front: Front
    @ViewBuilder var footer: Footer

    /// Hauteur fixe de l'en-tête (une propriété statique stockée est interdite dans un type générique → constante libre).
    private var headerHeight: CGFloat { phoneActHeaderHeight }
    /// L'écran arrive : l'iPhone est déjà là (il ne bouge pas) ; le TEXTE glisse depuis la droite et la DALLE
    /// se rafraîchit (léger zoom) — c'est le contenu qui change d'écran, pas le décor.
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let w = GiantPhone.frameWidth(for: geo.size)
            VStack(spacing: 0) {
                header
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: headerHeight, alignment: .topLeading)
                    .padding(.top, 4)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 28)

                HStack {
                    Spacer(minLength: 0)
                    PhoneStageView(stage: stage, frameWidth: w, accent: accent, tapEnabled: tapEnabled,
                                   ripple: ripple, onDoubleTap: onDoubleTap, arrival: arrival) {
                        front
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.94)
                    }
                        .padding(.trailing, geo.size.width * 0.02)
                }
                .padding(.top, 6)

                Spacer(minLength: 8)

                footer
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { appeared = true } }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - S5 · L'iPhone géant

struct Onb3Phone: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var out = false
    @State private var stage: PhoneStage = .front
    private var accent: Color { draft.accent }

    var body: some View {
        PhoneActScaffold(stage: stage, accent: accent, arrival: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "TapReply, c'est moi dans ta poche."))
                    .font(HZ.Fonts.fig(26, .heavy))
                    .foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "Je vis derrière ton téléphone. Quand tu m'appelles, je lis la conversation à l'écran et j'écris la réponse."))
                    .font(HZ.Fonts.fig(15, .medium)).foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(out ? 1 : 0)
            }
            .padding(.top, 8)
        } front: {
            // L'écran d'accueil du téléphone (pas encore la conversation : c'est la démo qui l'ouvre) — un badge
            // sur Messages : quelqu'un a écrit.
            GeometryReader { g in
                PhoneHomeScreen(width: g.size.width, accent: accent, highlightMessages: out)
                    .opacity(out ? 1 : 0)
            }
        } footer: {
            OnbButton(title: String(localized: "Montre-moi"), icon: "arrow.right", fill: accent, enabled: out, action: onNext)
        }
        .task {
            // Il arrive (pouf), présente l'iPhone, la conversation apparaît.
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.35)) { out = true }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// MARK: - S6 · La démo

struct Onb3Demo: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    /// 0 conversation · 1 deux taps au dos · 2 il lit et écrit · 3 à toi de relire et d'envoyer
    @State private var beat = 0
    @State private var stage: PhoneStage = .front
    @State private var typed = ""
    @State private var working = false
    @State private var ripple = 0
    @State private var seenOnce = false
    @State private var busy = false
    @State private var sent = false
    @State private var loopTask: Task<Void, Never>? = nil

    private var accent: Color { draft.accent }
    private let question = String(localized: "On se voit ce soir ?")
    private let reply = String(localized: "Je ne peux pas ce soir, mais demain avec plaisir !")

    private var captions: [String] {
        [String(localized: "Quelqu'un t'écrit. Tu ne sais pas quoi répondre."),
         String(localized: "Tu tapes deux fois au dos de ton téléphone. Sans rien ouvrir."),
         String(localized: "Je lis la conversation affichée, et j'écris la réponse."),
         String(localized: "Elle est prête. Tu relis, tu ajustes, tu envoies.")]
    }

    var body: some View {
        PhoneActScaffold(stage: stage, accent: accent, ripple: ripple) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(String(localized: "VOICI COMMENT ÇA MARCHE"))
                        .font(HZ.Fonts.fig(12.5, .bold)).tracking(1.3).foregroundStyle(accent)
                    Spacer()
                    Text(String(localized: "Démonstration"))
                        .font(HZ.Fonts.fig(11.5, .bold)).foregroundStyle(HZ.Colors.faint)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(HZ.Colors.cardDeep))
                }
                Text(captions[beat])
                    .font(HZ.Fonts.fig(22, .bold))
                    .foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(beat)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .padding(.top, 6)
            .animation(.spring(duration: 0.45), value: beat)
        } front: {
            GeometryReader { g in
                GiantConversation(width: g.size.width, received: [question],
                                  reply: beat >= 2 && !typed.isEmpty ? typed : nil,
                                  replySent: sent, working: working, accent: accent)
            }
        } footer: {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<captions.count, id: \.self) { i in
                        Capsule().fill(i == beat ? accent : accent.opacity(0.24)).frame(width: i == beat ? 20 : 7, height: 7)
                    }
                }
                .animation(.spring(duration: 0.35), value: beat)
                .padding(.bottom, 12)

                if seenOnce {
                    OnbButton(title: String(localized: "J'ai compris"), fill: accent, action: onNext).transition(.opacity)
                    OnbLink(title: String(localized: "Revoir depuis le début")) { restart() }.padding(.top, 10)
                } else {
                    OnbButton(title: String(localized: "Suivant"), icon: "arrow.right", fill: accent, enabled: !busy, action: advance)
                }
            }
        }
        .onAppear { TapTapClip.preload([TapTapClips.tapDosIphone, TapTapClips.litEtHoche, TapTapClips.invite]) }
        .onDisappear { loopTask?.cancel() }
    }

    /// Chaque temps enchaîne un geste précis de TapTap, dans l'ordre du récit.
    private func advance() {
        guard !busy else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch beat {
        case 0:
            busy = true
            withAnimation { beat = 1 }
            // L'iPhone se retourne (TapTap passe devant au même instant), il tape deux fois — deux lectures du geste.
            stage = .backInvite
            loopTask?.cancel()
            loopTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                stage = .backTap            // en BOUCLE : il tape tant qu'on est sur ce temps
                var loop = 0
                while !Task.isCancelled && stage == .backTap && beat == 1 {
                    var elapsed = 0
                    for t in PhoneStage.tapMoments {
                        try? await Task.sleep(for: .milliseconds(t - elapsed)); elapsed = t
                        guard stage == .backTap && beat == 1 else { break }
                        ripple += 1
                        if loop == 0 { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }   // ça vibre au PREMIER double tap seulement
                    }
                    if loop == 0 { busy = false }
                    try? await Task.sleep(for: .milliseconds(PhoneStage.tapLoopMs - elapsed))
                    loop += 1
                }
            }
        case 1:
            busy = true
            withAnimation { beat = 2 }
            stage = .front                // retour face : il lit, crayon à la main ; l'iPhone « réfléchit »
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation { working = true }
                try? await Task.sleep(for: .milliseconds(1_700))
                withAnimation { working = false }
                await typeReply()
                busy = false
            }
        case 2:
            // Temps 3 : tu relis, tu envoies — la réponse PART (bulle dans la conversation), c'est ce qui distingue ce temps.
            busy = true
            withAnimation { beat = 3 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.spring(duration: 0.45)) { sent = true }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(duration: 0.45)) { seenOnce = true }
                busy = false
            }
        default:
            withAnimation(.spring(duration: 0.45)) { seenOnce = true }
        }
    }

    @MainActor private func typeReply() async {
        typed = ""
        for ch in reply {
            typed.append(ch)
            try? await Task.sleep(for: .milliseconds(24))
        }
    }

    private func restart() {
        beat = 0; typed = ""; working = false; stage = .front; seenOnce = false; busy = false; sent = false
    }
}

// MARK: - S7 · À toi d'essayer

struct Onb3TryIt: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    private enum Phase { case waiting, working, done }
    @State private var phase: Phase = .waiting
    @State private var stage: PhoneStage = .backInvite
    @State private var typed = ""
    @State private var working = false
    @State private var ripple = 0
    @State private var speaks = false

    private var accent: Color { draft.accent }
    private let received = [String(localized: "Salut ! On se voit toujours demain ?"), String(localized: "Tu confirmes ?")]
    private let reply = String(localized: "Oui carrément, 18h comme prévu. Hâte !")

    var body: some View {
        PhoneActScaffold(stage: stage, accent: accent, tapEnabled: phase == .waiting, ripple: ripple, onDoubleTap: trigger) {
            VStack(alignment: .leading, spacing: 7) {
                Text(phase == .done ? String(localized: "Elle est prête. Et tu n'as rien tapé.") : String(localized: "À toi d'essayer."))
                    .font(HZ.Fonts.fig(27, .heavy))
                    .foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(phase == .done
                     ? String(localized: "Et je le ferai dans toutes tes applications de messages.")
                     : String(localized: "Tape deux fois au dos de l'iPhone dessiné, comme tu le feras au dos du tien."))
                    .font(HZ.Fonts.fig(15, .medium))
                    .foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .animation(.spring(duration: 0.5), value: phase)
        } front: {
            GeometryReader { g in
                GiantConversation(width: g.size.width, received: received,
                                  reply: phase == .done ? typed : nil, replySent: false,
                                  working: working, accent: accent)
            }
        } footer: {
            VStack(spacing: 0) {
                if phase == .waiting {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 14, weight: .bold))
                        Text(String(localized: "Tape deux fois sur le dos")).font(HZ.Fonts.fig(15, .bold))
                    }
                    .foregroundStyle(accent)
                    .padding(.bottom, 14)
                }
                if speaks {
                    TapTapBubble(text: String(localized: "Zéro réglage. Et c'était déjà ça."), accent: accent, tail: .none, typing: true)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                if phase == .done {
                    OnbButton(title: String(localized: "Il y a mieux encore"), icon: "arrow.right", fill: accent, action: onNext)
                        .transition(.opacity)
                }
            }
        }
    }

    private func trigger() {
        guard phase == .waiting else { return }
        phase = .working
        ripple += 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            ripple += 1
            try? await Task.sleep(for: .milliseconds(700))
            stage = .front                // retour face : il lit et écrit derrière l'iPhone
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation { working = true }
            try? await Task.sleep(for: .milliseconds(1_600))
            withAnimation { working = false }
            typed = ""
            withAnimation(.spring(duration: 0.4)) { phase = .done }
            for ch in reply { typed.append(ch); try? await Task.sleep(for: .milliseconds(22)) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.spring(duration: 0.45)) { speaks = true }
        }
    }
}
