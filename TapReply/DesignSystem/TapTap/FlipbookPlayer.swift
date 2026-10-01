import SwiftUI

// =============================================================================
// FLIPBOOK PLAYER — lecture d'un TapTapClip dans un Canvas
// =============================================================================
//
// Le lecteur ne connaît ni les écrans ni la mise en scène : il joue UN clip,
// à une position et une échelle données par TapTapStage. Il gère :
//   • la cadence (24 i/s) via TimelineView, sans Timer ;
//   • les trois modes : action (gel de la dernière image), boucle, transit ;
//   • la vitesse (ex. coucou ×1,5) ;
//   • la fin de clip (callback), déclenchée une seule fois ;
//   • Réduire les animations : on n'affiche que la dernière image (pose finale).
//
// Le dessin est un Canvas : ~55 tracés par image, aucun coût de layout SwiftUI.
// =============================================================================

struct FlipbookPlayer: View {
    let clip: TapTapClip
    var palette: TapTapPalette
    /// Vitesse de lecture (1 = temps réel).
    var speed: Double = 1
    /// Démarre en pause sur la première image.
    var paused: Bool = false
    /// Rejouer en boucle (décidé par le beat : un clip ACTION peut être bouclé s'il finit sur sa pose de départ).
    var loops: Bool = false
    /// Appelé une fois quand une ACTION atteint sa dernière image.
    var onFinished: (() -> Void)? = nil
    /// Décalage temporel : permet de démarrer au milieu d'un clip (ms).
    var startOffsetMs: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tapTapCrowned) private var crowned
    @State private var startDate: Date? = nil
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Double(clip.fps), paused: paused || reduceMotion || (finished && !loops))) { ctx in
            let tick = currentTick(now: ctx.date)
            Canvas(rendersAsynchronously: false) { gc, size in
                // Le clip est dessiné dans son canvas natif (675×1200) mis à l'échelle de la vue.
                let sx = size.width / clip.width, sy = size.height / clip.height
                gc.scaleBy(x: sx, y: sy)
                let frame = clip.frame(atTick: tick)
                for shape in frame.shapes {
                    gc.fill(shape.path, with: .color(palette.color(for: shape)))
                }
                if crowned { TapTapCrown.draw(on: frame, in: &gc) }
            }
            .onChange(of: tick) { _, t in
                if !loops, !finished, t >= clip.totalTicks - 1 {
                    finished = true; onFinished?()
                }
            }
        }
        .onAppear {
            startDate = Date()
            // Réduire les animations : la dernière image est affichée d'emblée et `tick` ne change jamais → on
            // signale la fin tout de suite, sinon une séquence de gestes restait figée sur le premier.
            if reduceMotion, !loops, !finished { finished = true; DispatchQueue.main.async { onFinished?() } }
        }
        .onChange(of: clip.id) { _, _ in
            startDate = Date(); finished = false
            if reduceMotion, !loops { finished = true; DispatchQueue.main.async { onFinished?() } }
        }
    }

    private func currentTick(now: Date) -> Int {
        if reduceMotion { return clip.totalTicks - 1 }
        guard let s = startDate else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(s)) * speed + startOffsetMs / 1000
        let raw = Int(elapsed * Double(clip.fps))
        guard clip.totalTicks > 0 else { return 0 }
        if loops {
            if clip.type == .loop { return clip.tick(forElapsed: raw) }   // intro une fois, puis la boucle (loopStart)
            return raw % clip.totalTicks                                  // ACTION bouclée : du début à la fin, en continu
        }
        return min(raw, clip.totalTicks - 1)
    }
}

/// Image fixe d'un clip (première ou dernière) — pour les vignettes, l'île, les listes.
struct FlipbookStill: View {
    let clip: TapTapClip
    var palette: TapTapPalette
    var last: Bool = true
    @Environment(\.tapTapCrowned) private var crowned

    var body: some View {
        Canvas { gc, size in
            gc.scaleBy(x: size.width / clip.width, y: size.height / clip.height)
            let frame = last ? clip.frames[clip.frames.count - 1] : clip.frames[0]
            for shape in frame.shapes { gc.fill(shape.path, with: .color(palette.color(for: shape))) }
            if crowned { TapTapCrown.draw(on: frame, in: &gc) }
        }
    }
}


// MARK: - La couronne Pro, posée SUR le dôme (elle suit chaque image)

/// Active la couronne sur tous les TapTap de la sous-arborescence : `.environment(\.tapTapCrowned, isPro)`.
private struct TapTapCrownedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var tapTapCrowned: Bool {
        get { self[TapTapCrownedKey.self] }
        set { self[TapTapCrownedKey.self] = newValue }
    }
}

/// La couronne est dessinée DANS le canvas du clip, image par image : on repère le dôme (la plus grande forme
/// d'accent) et on la pose sur son sommet, un peu à droite, inclinée. Quand TapTap saute, se penche ou danse,
/// elle bouge avec lui — une couronne posée en superposition restait en l'air (retour du 25/09).
enum TapTapCrown {
    static let gold = Color(hex: 0xE9A93A)

    static func draw(on frame: TapTapFrame, in gc: inout GraphicsContext) {
        var dome: CGRect? = nil
        var domeShape: Path? = nil
        for shape in frame.shapes where shape.role == .accent || shape.role == .accentDark || shape.role == .accentLight {
            let r = shape.path.boundingRect
            // le dôme : large, plus large que haut, dans le haut du personnage
            guard r.width > 90, r.width > r.height * 1.1 else { continue }
            if dome == nil || r.width * r.height > dome!.width * dome!.height { dome = r; domeShape = shape.path }
        }
        guard let d = dome, let domePath = domeShape else { return }
        let w = d.width * 0.36, h = w * 0.82
        let cx = d.midX + d.width * 0.09
        // La SURFACE du dôme à l'aplomb de la couronne : on descend depuis le haut jusqu'à entrer dans la forme.
        // (Poser la couronne sur « minY + 10 % » la plantait dans le dôme dès qu'il était moins bombé à droite.)
        var surface = d.minY
        var y = d.minY
        while y < d.maxY {
            if domePath.contains(CGPoint(x: cx, y: y)) { surface = y; break }
            y += 2
        }
        // la couronne est posée AU-DESSUS de la surface (retour du 26/09 : elle paraissait enfoncée dans la tête).
        // 7 % de la largeur du dôme ≈ 20 unités : un écart qui se VOIT même sur l'avatar de 54 pt.
        let base = surface - d.width * 0.12
        var ctx = gc
        ctx.translateBy(x: cx, y: base)
        ctx.rotate(by: .degrees(9))
        // la base de la couronne (y = 0,92 h dans son tracé) tombe exactement sur `base`
        let rect = CGRect(x: -w / 2, y: -h * 0.92, width: w, height: h)
        let crown = CrownOutline().path(in: rect)
        ctx.fill(crown, with: .color(gold.opacity(0.22)))
        ctx.stroke(crown, with: .color(gold), style: StrokeStyle(lineWidth: max(6, w * 0.11), lineCap: .round, lineJoin: .round))
    }
}
