import SwiftUI

// =============================================================================
// TAPTAP DIRECTOR — la continuité de TapTap entre les écrans de l'onboarding
// =============================================================================
//
// TapTap n'appartient à AUCUN écran. Il vit dans le routeur, en une seule
// instance (TapTapStage), au-dessus du contenu. Chaque écran DÉCLARE la scène
// qu'il veut — où TapTap se pose, à quelle échelle, ce qu'il joue — via une
// préférence SwiftUI ; le metteur en scène l'y emmène.
//
// Quand la scène change d'ancre, le DÉPLACEMENT a un sens (bible, principe 3) :
//   · `.walk`  — il marche (V07) pendant que l'app le translate : même sujet ;
//   · `.exit`  — il sort par la droite en marchant et rentre par la gauche du
//                nouvel écran (T1) ;
//   · `.pouf`  — il disparaît dans trois ronds lavande et réapparaît ailleurs,
//                souvent plus petit : il laisse la place (T5, T6) ;
//   · `.cut`   — fondu sur place (150 ms) : les silhouettes se correspondent.
//
// Les écrans réservent sa place avec `TapTapSlot` (un `Color.clear` de la bonne
// hauteur qui publie son cadre) ou plaquent un objet du canvas sur une vue avec
// `TapTapRectSlot` (l'iPhone géant, la carte de membre).
// =============================================================================

let onb3Space = "onboarding3Stage"

enum TapTapTransit: Equatable { case cut, walk, exit, pouf }

struct TapTapScene: Equatable {
    var placement: TapTapPlacement
    var beats: [TapTapBeat]
    var accent: Color? = nil
    var hidden: Bool = false
    /// Comment ARRIVER à cette scène depuis la précédente (si l'ancre a bougé).
    var transit: TapTapTransit = .cut
    /// Conservé pour compatibilité : la couche est TOUJOURS au-dessus du contenu (une seule instance).
    var behindContent: Bool = false
    /// Un rectangle (repère onb3Space) qui CACHE TapTap : l'iPhone géant vu de face — il est « derrière ».
    var occluder: CGRect? = nil
    var occluderRadius: CGFloat = 0
}

struct TapTapSceneKey: PreferenceKey {
    static let defaultValue: TapTapScene? = nil
    static func reduce(value: inout TapTapScene?, nextValue: () -> TapTapScene?) {
        if let next = nextValue() { value = next }
    }
}

extension View {
    func tapTapScene(_ scene: TapTapScene) -> some View { preference(key: TapTapSceneKey.self, value: scene) }
}

/// La place de TapTap dans la mise en page d'un écran : un carré de `height` points ; ses jambes se posent au
/// centre-bas de ce carré. Publie la scène au routeur.
struct TapTapSlot: View {
    var height: CGFloat
    var beats: [TapTapBeat]
    var accent: Color? = nil
    var hidden: Bool = false
    var transit: TapTapTransit = .cut
    /// Décale l'ancre (en fraction de la hauteur) — ex. pour poser TapTap un peu plus bas que le cadre.
    var anchorOffset: CGSize = .zero
    var onTap: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let f = geo.frame(in: .named(onb3Space))
            Color.clear
                .preference(key: TapTapSceneKey.self,
                            value: TapTapScene(placement: .ground(anchor: CGPoint(x: f.midX + anchorOffset.width * height,
                                                                                    y: f.maxY + anchorOffset.height * height),
                                                                  height: height),
                                               beats: beats, accent: accent, hidden: hidden, transit: transit))
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .allowsHitTesting(onTap != nil)
        }
        .frame(width: height * 1.15, height: height)
        // VoiceOver : toucher TapTap doit être atteignable (sinon « Coucou » est une impasse ; audit 26/09, C1).
        .accessibilityElement()
        .accessibilityLabel(String(localized: "TapTap"))
        .accessibilityHint(String(localized: "Touche pour continuer"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap?() }
        .accessibilityHidden(onTap == nil)
    }
}

/// Plaque un rectangle du canvas (ex. la dalle de l'iPhone géant) sur la vue qui porte ce modificateur.
struct TapTapRectSlot<Content: View>: View {
    var canvasRect: CGRect
    var beats: [TapTapBeat]
    var accent: Color? = nil
    var transit: TapTapTransit = .cut
    var behindContent: Bool = true
    /// Rayon de l'objet quand il CACHE TapTap (behindContent = true → l'objet est devant lui : carte, pancarte).
    var occluderRadius: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                GeometryReader { geo in
                    let f = geo.frame(in: .named(onb3Space))
                    Color.clear.preference(key: TapTapSceneKey.self,
                                           value: TapTapScene(placement: .mapRect(canvas: canvasRect, screen: f),
                                                              beats: beats, accent: accent, transit: transit,
                                                              behindContent: behindContent,
                                                              occluder: behindContent ? f : nil,
                                                              occluderRadius: occluderRadius))
                }
            )
    }
}

// MARK: - Le metteur en scène

/// Dessine TapTap à la scène publiée, et joue les déplacements entre deux scènes.
struct TapTapDirectorLayer: View {
    let scene: TapTapScene?
    let viewSize: CGSize

    @State private var placement: TapTapPlacement? = nil
    @State private var beats: [TapTapBeat] = []
    @State private var visible = true
    private struct PoufMark: Identifiable { let id: UUID; let at: CGPoint; let size: CGFloat }
    @State private var poufs: [PoufMark] = []
    @State private var moving = false
    @State private var occluder: CGRect? = nil
    @State private var occluderRadius: CGFloat = 0
    /// Génération de scène : invalide les tâches différées des scènes précédentes.
    @State private var generation = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let p = placement, let scene, !scene.hidden, visible {
                TapTapStage(beats: beats, placement: p, accent: scene.accent)
                    .mask {
                        // L'occulteur : un trou aux dimensions de l'iPhone (TapTap passe derrière).
                        ZStack {
                            Rectangle().fill(.white)
                            if let o = occluder {
                                RoundedRectangle(cornerRadius: occluderRadius, style: .continuous)
                                    .fill(.black)
                                    .frame(width: o.width, height: o.height)
                                    .position(x: o.midX, y: o.midY)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                        .frame(width: viewSize.width, height: viewSize.height, alignment: .topLeading)
                    }
            }
            ForEach(poufs) { p in
                TapTapPouf(size: p.size)
                    .position(p.at)
            }
        }
        .frame(width: viewSize.width, height: viewSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onChange(of: scene) { old, new in apply(from: old, to: new) }
        .onAppear { if let scene { placement = scene.placement; beats = scene.beats } }
    }

    private func apply(from old: TapTapScene?, to new: TapTapScene?) {
        guard let new else { return }
        // Génération : toute tâche différée d'une scène précédente s'arrête dès qu'une nouvelle scène arrive
        // (sinon un vieux « pouf » ou une fin de marche écrasait la scène courante ; audit 26/09, M7).
        generation += 1
        let gen = generation
        // L'occulteur suit la scène (l'iPhone est devant lui ou pas) ; il change quand il ARRIVE à la nouvelle place.
        let delay = (new.occluder == nil) ? 0 : 280
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard gen == generation else { return }
            occluder = new.occluder; occluderRadius = new.occluderRadius
        }
        guard let current = placement, let old else {
            placement = new.placement; beats = new.beats; return
        }
        let a = current.point(TapTapPlacement.legs), b = new.placement.point(TapTapPlacement.legs)
        // Un écran qui cache TapTap (scène locale : lampe, iPhone géant) : il part dans un pouf, jamais en coupe.
        if new.hidden && !old.hidden && visible {
            pouf(at: a, size: current.transform.unit * 380)
            withAnimation(.easeIn(duration: 0.12)) { visible = false }
            return
        }
        if !new.hidden && old.hidden {
            placement = new.placement; beats = new.beats
            if new.transit == .pouf { pouf(at: b, size: new.placement.transform.unit * 380) }
            withAnimation(.easeOut(duration: 0.18)) { visible = true }
            return
        }
        let travelled = hypot(a.x - b.x, a.y - b.y)
        let scaleChanged = abs(current.transform.unit - new.placement.transform.unit) > 0.02
        // Même endroit, même échelle : on change seulement ce qu'il joue (la scène fond les deux clips).
        if travelled < 40 && !scaleChanged {
            beats = new.beats
            if !visible { withAnimation(.easeOut(duration: 0.18)) { visible = true } }
            return
        }
        if new.transit != .pouf && !visible { visible = true }   // un pouf précédent a été interrompu
        switch new.transit {
        case .pouf:
            pouf(at: a, size: current.transform.unit * 380)
            visible = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                guard gen == generation else { return }
                placement = new.placement; beats = new.beats
                pouf(at: b, size: new.placement.transform.unit * 380)
                try? await Task.sleep(for: .milliseconds(120))
                guard gen == generation else { visible = true; return }
                withAnimation(.easeOut(duration: 0.18)) { visible = true }
            }
        case .walk:
            // Il marche à ~190 pt/s (pas de course) ; à l'arrivée il s'arrête (V08) puis joue la scène.
            let dur = min(1.7, max(0.7, Double(travelled) / 190))
            beats = [.loop(TapTapClips.marche, speed: 1.0)]
            withAnimation(.easeInOut(duration: dur)) { placement = new.placement }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(dur * 1000) - 60))
                guard gen == generation else { return }
                beats = [.play(TapTapClips.arretMarche, speed: 1.2)] + new.beats
            }
        case .exit:
            // Sort par la droite en marchant, rentre par la gauche du nouvel écran, s'arrête.
            let h = current.transform.unit * TapTapPlacement.standingHeight
            beats = [.loop(TapTapClips.marche, speed: 1.0)]
            withAnimation(.linear(duration: 0.9)) { placement = .ground(anchor: CGPoint(x: viewSize.width + h, y: a.y), height: h) }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(920))
                guard gen == generation else { return }
                let h2 = new.placement.transform.unit * TapTapPlacement.standingHeight
                placement = .ground(anchor: CGPoint(x: -h2, y: b.y), height: h2)
                try? await Task.sleep(for: .milliseconds(40))
                guard gen == generation else { return }
                withAnimation(.linear(duration: 1.0)) { placement = new.placement }
                try? await Task.sleep(for: .milliseconds(960))
                guard gen == generation else { return }
                beats = [.play(TapTapClips.arretMarche, speed: 1.2)] + new.beats
            }
        case .cut:
            // Il glisse vers la nouvelle place avec le nouveau geste : même sujet, mouvement continu. S'il MARCHE,
            // la vitesse est celle d'un pas (≈ 230 pt/s) ; sinon un ressort doux.
            beats = new.beats
            if new.beats.first?.clipID == TapTapClips.marche {
                withAnimation(.linear(duration: min(1.6, max(0.6, Double(travelled) / 230)))) { placement = new.placement }
            } else {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) { placement = new.placement }
            }
        }
    }

    private func pouf(at p: CGPoint, size: CGFloat) {
        let id = UUID()
        poufs.append(PoufMark(id: id, at: CGPoint(x: p.x, y: p.y - size * 0.35), size: size))
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            poufs.removeAll { $0.id == id }
        }
    }
}
