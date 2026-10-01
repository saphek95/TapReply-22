import SwiftUI

// =============================================================================
// ACTE 0 — LA LAMPE, PUIS « COUCOU »
// =============================================================================
//
// S0 : la lampe de génie — la séquence vidéo approuvée par Pierre le 08/09
//      (TapTap-N01 « pouf rond », 3 s, fond blanc) : la lampe seule, TapTap sort
//      du bec avec effort, POP du nuage à 1,17 s, il monte et se pose au-dessus
//      de la lampe. En attente : image 0 (lampe seule) qui frémit toutes les 3 s.
//      On la touche deux fois — c'est déjà le geste.
// S1 : à 1,95 s (posé), le TapTap VECTORIEL prend le relais exactement à sa
//      place, la vidéo s'efface, et le metteur en scène le fait glisser au
//      centre pour « Coucou » (S2). Un seul personnage, du début à la fin.
// S2 : « Coucou ! Moi c'est TapTap. » Un toucher → « Pour m'appeler, pas
//      besoin de lampe : deux taps au dos de ton iPhone. » Un toucher → T1.
// =============================================================================

struct Onb3Lamp: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    private enum Phase { case waiting, playing, handoff }
    @State private var phase: Phase = .waiting
    @State private var rock: Double = 0
    @State private var nudged = false
    @State private var videoOpacity: Double = 1
    @State private var hint = false
    @State private var singleTapTask: Task<Void, Never>? = nil
    /// Publié au moment de la passation : la scène du metteur en scène, exactement sur le TapTap de la vidéo.
    @State private var handoffScene: TapTapScene? = nil

    var body: some View {
        GeometryReader { geo in
            // La vidéo (9:16) occupe toute la largeur, centrée verticalement dans la zone libre au-dessus des textes.
            let videoW = geo.size.width
            let videoH = videoW * LampVideo.size.height / LampVideo.size.width
            let videoTop = max(0, (geo.size.height - 150 - videoH) / 2)
            let scale = videoW / LampVideo.size.width
            let legs = CGPoint(x: LampVideo.finalLegs.x * scale, y: videoTop + LampVideo.finalLegs.y * scale)
            let height = LampVideo.finalHeight * scale
            ZStack(alignment: .topLeading) {
                Color.white
                // En attente : l'image 0 de la vidéo, en DEUX morceaux — l'ombre (fixe) et la lampe (qui frémit).
                // À la lecture, la vidéo (identique à l'image 0 au repos) prend le relais : aucun saut.
                if phase == .waiting {
                    Image(uiImage: LampVideo.image("TapTap-lampe-ombre"))
                        .resizable().interpolation(.high)
                        .frame(width: 282 * scale, height: 80 * scale)
                        .offset(x: 366 * scale, y: videoTop + 1122 * scale)
                    Image(uiImage: LampVideo.image("TapTap-lampe-corps"))
                        .resizable().interpolation(.high)
                        .frame(width: 648 * scale, height: 422 * scale)
                        .rotationEffect(.degrees(rock), anchor: UnitPoint(x: 0.5, y: 0.98))
                        .offset(x: 216 * scale, y: videoTop + 778 * scale)
                }
                LampVideoPlayer(play: phase != .waiting,
                                onTime: { t in if t >= LampVideo.settledAt && phase == .playing { handoff(legs: legs, height: height) } },
                                onEnd: { if phase == .playing { handoff(legs: legs, height: height) } })
                    .frame(width: videoW, height: videoH)
                    .offset(y: videoTop)
                    .opacity(phase == .waiting ? 0 : videoOpacity)
                Color.clear
                    .frame(width: videoW, height: videoH)
                    .offset(y: videoTop)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { summon() }
                    .onTapGesture { nudge() }
                    .accessibilityLabel(String(localized: "Lampe de génie"))
                    .accessibilityHint(String(localized: "Touche deux fois pour faire sortir TapTap"))

                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Text(String(localized: "Quelqu'un veut te rencontrer."))
                        .font(HZ.Fonts.fig(28, .heavy))
                        .foregroundStyle(HZ.Colors.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(hint ? String(localized: "Presque ! Deux touchers rapprochés, comme un double clic.") : String(localized: "Touche deux fois la lampe."))
                        .font(HZ.Fonts.fig(16.5, hint ? .bold : .medium))
                        .foregroundStyle(hint ? draft.accent : HZ.Colors.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(nudged ? 1.06 : 1)
                        .animation(.spring(duration: 0.3), value: nudged)
                        .animation(.easeOut(duration: 0.25), value: hint)
                    Button { summon() } label: {
                        Text(String(localized: "Faire sortir sans taper"))
                            .font(HZ.Fonts.fig(14, .semibold))
                            .foregroundStyle(HZ.Colors.faint)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(width: geo.size.width)
                .padding(.horizontal, HZ.Spacing.gutter)
                .padding(.bottom, 22)
                .frame(height: geo.size.height, alignment: .bottom)
                .opacity(phase == .waiting ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: phase == .waiting)
                .allowsHitTesting(phase == .waiting)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Pendant la vidéo, TapTap est dans l'image ; à la passation, le metteur en scène prend le relais au même endroit.
            .tapTapScene(handoffScene ?? TapTapScene(placement: .ground(anchor: .zero, height: 1), beats: [], hidden: true))
            .task { await rockLoop() }
            // Filet : vidéo interrompue (arrière-plan, appel, fichier illisible) → la passation se fait quand même,
            // sinon l'écran restait blanc sans issue (audit 26/09, M2).
            .task(id: phase) {
                guard phase == .playing else { return }
                try? await Task.sleep(for: .milliseconds(3_400))
                guard !Task.isCancelled, phase == .playing else { return }
                handoff(legs: legs, height: height)
            }
        }
    }

    /// La lampe seule frémit doucement toutes les 3 s : « il y a quelqu'un dedans ».
    private func rockLoop() async {
        try? await Task.sleep(for: .milliseconds(900))
        while !Task.isCancelled && phase == .waiting {
            await shake(strength: 2.2)
            try? await Task.sleep(for: .milliseconds(2_600))
        }
    }

    @MainActor private func shake(strength: Double) async {
        for k in 0..<4 {
            withAnimation(.easeInOut(duration: 0.07)) { rock = k % 2 == 0 ? -strength : strength }
            try? await Task.sleep(for: .milliseconds(75))
        }
        withAnimation(.easeOut(duration: 0.12)) { rock = 0 }
    }

    /// Un seul toucher : la lampe frémit ; si le second ne vient pas dans les 600 ms, on explique le double tap.
    private func nudge() {
        guard phase == .waiting else { return }
        nudged = true
        singleTapTask?.cancel()
        singleTapTask = Task { @MainActor in
            await shake(strength: 3.5); nudged = false
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, phase == .waiting else { return }
            hint = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    /// Le double tap : la vidéo approuvée se joue — il sort du bec, pop du nuage, il monte et se pose au-dessus de la lampe.
    private func summon() {
        guard phase == .waiting else { return }
        singleTapTask?.cancel()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        withAnimation(.easeOut(duration: 0.12)) { rock = 0 }
        phase = .playing
        // Le pop (image 28 = 1,17 s) : haptique de succès au même instant.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_170))
            guard phase == .playing else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Passation : le TapTap vectoriel apparaît exactement sur celui de la vidéo (même place, même taille), la
    /// vidéo s'efface, puis l'acte suivant le fait glisser au centre.
    private func handoff(legs: CGPoint, height: CGFloat) {
        guard phase == .playing else { return }
        phase = .handoff
        handoffScene = TapTapScene(placement: .ground(anchor: legs, height: height), beats: [.loop(TapTapClips.idle)],
                                   accent: draft.accent, hidden: false, transit: .cut)
        videoOpacity = 0    // coupe : jamais deux TapTap (la vidéo et le vectoriel) en même temps
        // Et on passe TOUT DE SUITE à « Coucou » : le metteur en scène part de la place de la vidéo et glisse vers
        // le centre — pas de TapTap intermédiaire posé à côté de la lampe.
        onNext()
    }
}

// MARK: - S2 · Coucou

struct Onb3Hello: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    private enum Beat: Int, Comparable {
        case arriving, firstLine, secondLine, leaving
        static func < (a: Beat, b: Beat) -> Bool { a.rawValue < b.rawValue }
    }
    @State private var beat: Beat = .arriving
    @State private var nod = 0

    private var accent: Color { draft.accent }

    var body: some View {
        GeometryReader { geo in
            let hero = TapTapScale.hero(geo.size)
            VStack(spacing: 0) {
                Spacer(minLength: 4)

                ZStack(alignment: .bottom) {
                    Color.clear.frame(height: 128)
                    if beat >= .firstLine {
                        TapTapBubble(text: line, accent: accent, tail: .bottomCenter, typing: true)
                            .id(lineIndex)
                            .transition(.asymmetric(insertion: .scale(scale: 0.86, anchor: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 12)

                // Sa place. Il GLISSE depuis l'endroit où la vidéo de la lampe l'a laissé (même personnage), et fait coucou.
                TapTapSlot(height: hero, beats: beats, accent: accent, transit: .cut,
                           anchorOffset: CGSize(width: beat == .leaving ? (geo.size.width / hero) : 0, height: 0),
                           onTap: { touch() })
                    .tapTapNod(nod)

                Spacer(minLength: 8)

                VStack(spacing: 14) {
                    if beat >= .firstLine && beat != .leaving {
                        TouchHint(label: beat == .firstLine ? String(localized: "Touche TapTap") : String(localized: "Encore une fois"),
                                  accent: accent)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        HStack(spacing: 7) {
                            ForEach(0..<2, id: \.self) { i in
                                Capsule().fill(i < beat.rawValue ? accent : accent.opacity(0.26))
                                    .frame(width: i < beat.rawValue ? 22 : 8, height: 8)
                            }
                        }
                        .animation(.spring(duration: 0.4), value: beat)
                    }
                }
                .frame(height: 96, alignment: .top)

                Spacer(minLength: 6)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .animation(.spring(duration: 0.45), value: beat)
            .task {
                // Le pouf d'arrivée dure ~0,5 s, le coucou 3,4 s (×1,4) : il finit de saluer, PUIS il parle.
                try? await Task.sleep(for: .milliseconds(1_300))
                beat = .firstLine
            }
        }
    }

    /// Les beats ne changent qu'UNE fois (au second message) : le repos continue sans redémarrer entre-temps.
    private var beats: [TapTapBeat] {
        switch beat {
        case .arriving, .firstLine: return [.play(TapTapClips.coucou, speed: 1.4), .loop(TapTapClips.idle)]
        // Bras levé et MAINTENU (pas de retour au repos) : quel que soit le moment du toucher, il part de cette pose.
        case .secondLine: return [.play(TapTapClips.presente, speed: 1.1), .still(TapTapClips.presente)]
        // Il part en marchant vers la droite, hors de l'écran — ici, en grand — puis l'écran suivant le fait entrer.
        case .leaving:    return [.loop(TapTapClips.marche, speed: 1.0)]
        }
    }

    private var lineIndex: Int { beat == .arriving || beat == .firstLine ? 0 : 1 }
    private var line: String {
        lineIndex == 0
        ? String(localized: "Coucou ! Moi c'est TapTap. Ton petit génie des messages.")
        : String(localized: "Pour m'appeler, pas besoin de lampe : deux taps au dos de ton iPhone, et j'arrive. On va activer ça ensemble.")
    }

    private func touch() {
        guard beat != .leaving, beat >= .firstLine else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if beat == .firstLine {
            nod += 1
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(330))
                beat = .secondLine
            }
        } else {
            beat = .leaving
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1_450))   // le temps de sortir du cadre en marchant (≈ 230 pt/s)
                onNext()
            }
        }
    }
}
