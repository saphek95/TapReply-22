import SwiftUI

// =============================================================================
// L'IPHONE GÉANT — dessiné par l'app, TapTap autour
// =============================================================================
//
// v3 (24/09) : l'iPhone n'est PLUS celui des clips Veo (encoche qui clignotait,
// écran qui débordait, cadre qui bougeait d'un clip à l'autre). Le pipeline a
// retiré l'iPhone dessiné de tous les clips ; l'app dessine le sien — face et
// dos — net, stable, et TapTap est posé À CÔTÉ par une règle unique :
//
//   · ses jambes sont à une position FIXE relative au cadre (phoneSideLegs),
//     la même pour tous les gestes → il ne saute jamais d'un clip à l'autre ;
//   · il est TOUJOURS devant l'iPhone et entièrement visible : à gauche du cadre
//     quand la face est visible (il ne cache jamais la conversation), un pas plus
//     près quand le dos est visible (sa main atteint le dos pour taper).
//
// La scène TapTap est LOCALE (pas le metteur en scène) : c'est le seul moyen
// d'avoir un ordre de plans exact autour de l'objet. Le metteur en scène est
// masqué pendant ces écrans (il part et revient dans un pouf).
// =============================================================================

enum GiantPhone {
    /// Cadre : 344 × 715 dans le canvas → hauteur = 2,079 × largeur.
    static let frameRatio: CGFloat = 715.0 / 344.0
    static let frameRadius: CGFloat = 0.165
    static let screenInset: CGFloat = 0.045
    static let screenRadius: CGFloat = 0.125
    /// Hauteur réservée à l'île dynamique en haut de la dalle (fraction de la largeur du cadre).
    static let islandInset: CGFloat = 0.15
    static let frameColor = Color(hex: 0x2F2855)
    static let backColor = Color(hex: 0x4A3B6B)

    /// Largeur du CADRE (points) pour qu'il occupe `fraction` de la largeur d'écran.
    static func frameWidth(for screen: CGSize, fraction: CGFloat = 0.47) -> CGFloat {
        min(screen.width * fraction, 210)
    }
    static func screenWidth(frame w: CGFloat) -> CGFloat { w * (1 - 2 * screenInset) }
}

/// La FACE : cadre, dalle crème, île dynamique, et le contenu SwiftUI dans la dalle.
struct GiantPhoneFront<Content: View>: View {
    var width: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        let h = width * GiantPhone.frameRatio
        let inset = width * GiantPhone.screenInset
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: width * GiantPhone.frameRadius, style: .continuous)
                .fill(GiantPhone.frameColor)
            RoundedRectangle(cornerRadius: width * GiantPhone.screenRadius, style: .continuous)
                .fill(HZ.Colors.mascotCream)
                .padding(inset)
            // le contenu, rogné à la dalle
            content
                .padding(.top, width * GiantPhone.islandInset)
                .frame(width: width - 2 * inset, height: h - 2 * inset, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: width * GiantPhone.screenRadius, style: .continuous))
                .padding(inset)
            // l'île dynamique
            Capsule().fill(GiantPhone.frameColor)
                .frame(width: width * 0.30, height: width * 0.075)
                .padding(.top, inset + width * 0.035)
        }
        .frame(width: width, height: h)
    }
}

/// Le DOS : cadre, plaque, module caméra, pomme ; la zone de double tap, et les ondes de l'impact.
struct GiantPhoneBack: View {
    var width: CGFloat
    var accent: Color
    var tapEnabled: Bool = false
    /// Incrémenter pour faire partir une onde depuis la pomme (à chaque tap de TapTap ou de l'utilisateur).
    var ripple: Int = 0
    var onDoubleTap: () -> Void = {}

    var body: some View {
        let h = width * GiantPhone.frameRatio
        let inset = width * 0.03
        DoubleTapZone(enabled: tapEnabled, onDoubleTap: onDoubleTap) {
            ZStack {
                RoundedRectangle(cornerRadius: width * GiantPhone.frameRadius, style: .continuous)
                    .fill(GiantPhone.frameColor)
                RoundedRectangle(cornerRadius: width * (GiantPhone.frameRadius - 0.02), style: .continuous)
                    .fill(GiantPhone.backColor)
                    .padding(inset)
                // module caméra
                VStack { HStack { cameraModule; Spacer() }; Spacer() }
                    .padding(width * 0.085)
                // (pas de logo Apple : la licence SF Symbols le réserve à la désignation des produits Apple ; le module
                // caméra suffit à lire « le dos de l'iPhone »)
                TapRipples(trigger: ripple, accent: accent, size: width * 0.9)
                    .offset(y: -h * 0.02)
                if tapEnabled {
                    DoubleTapPulse(accent: accent, size: width * 0.46)
                        .offset(y: -h * 0.02)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: h)
        }
        // VoiceOver : une activation simule les deux taps au dos (sinon l'étape est impossible ; audit 26/09, C1).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Dos de l'iPhone"))
        .accessibilityHint(String(localized: "Active pour simuler les deux taps au dos"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if tapEnabled { onDoubleTap() } }
    }

    private var cameraModule: some View {
        let m = width * 0.36
        return RoundedRectangle(cornerRadius: m * 0.26, style: .continuous)
            .fill(GiantPhone.frameColor)
            .frame(width: m, height: m)
            .overlay {
                ZStack {
                    lens.offset(x: -m * 0.2, y: -m * 0.2)
                    lens.offset(x: -m * 0.2, y: m * 0.2)
                    lens.offset(x: m * 0.2, y: 0)
                    Circle().fill(Color(hex: 0xF3E7C3).opacity(0.9)).frame(width: m * 0.1, height: m * 0.1).offset(x: m * 0.26, y: -m * 0.28)
                }
            }
    }
    private var lens: some View {
        let d = width * 0.11
        return Circle().fill(Color(hex: 0x1A1630))
            .frame(width: d, height: d)
            .overlay(Circle().strokeBorder(Color(hex: 0x6E6297), lineWidth: d * 0.12))
            .overlay(Circle().fill(.white.opacity(0.35)).frame(width: d * 0.22, height: d * 0.22).offset(x: -d * 0.18, y: -d * 0.18))
    }
}

/// Deux anneaux qui partent du point d'impact à chaque tap.
struct TapRipples: View {
    var trigger: Int
    var accent: Color
    var size: CGFloat
    @State private var rings: [UUID] = []

    var body: some View {
        ZStack {
            ForEach(rings, id: \.self) { id in
                RippleRing(color: accent, size: size).id(id)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let id = UUID(); rings.append(id)
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(700)); rings.removeAll { $0 == id } }
        }
    }
    private struct RippleRing: View {
        var color: Color; var size: CGFloat
        @State private var go = false
        var body: some View {
            Circle().strokeBorder(color, lineWidth: go ? 1.5 : 5)
                .frame(width: go ? size : size * 0.18, height: go ? size : size * 0.18)
                .opacity(go ? 0 : 0.95)
                .animation(.easeOut(duration: 0.62), value: go)
                .onAppear { go = true }
        }
    }
}

/// Face ↔ dos : un flip 3D de 550 ms. Les deux faces sont des vues distinctes ; la scène TapTap, elle, ne
/// tourne pas : elle change de plan (devant/derrière) au même instant.
struct PhoneFlip<Front: View, Back: View>: View {
    var showBack: Bool
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back

    var body: some View {
        ZStack {
            front.opacity(showBack ? 0 : 1)
            back.opacity(showBack ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(showBack ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
        .animation(.spring(duration: 0.55, bounce: 0.12), value: showBack)
    }
}

// MARK: - Ce que TapTap fait autour de l'iPhone

/// TROIS boucles, et rien d'autre : chaque état est UNE boucle dont la fin rejoint le début. Aucun « repos » entre
/// deux gestes (le repos n'a pas la même place que le geste : il donnait un TapTap qui saute). La position de
/// TapTap est celle du clip lui-même par rapport à l'iPhone (mapRect sur le cadre mesuré) : derrière la face avec
/// son crayon (V22), devant le dos pour inviter (V15) ou taper (V13b).
enum PhoneStage: Equatable {
    /// Face : derrière l'iPhone, crayon à la main, il lit et hoche (boucle V22).
    case front
    /// Dos : il invite à taper (boucle V15).
    case backInvite
    /// Dos : il tape deux fois, en boucle (V13b).
    case backTap

    var isBack: Bool { self != .front }

    var clip: String {
        switch self {
        case .front:      return TapTapClips.litEtHoche
        case .backInvite: return TapTapClips.invite
        case .backTap:    return TapTapClips.tapDosIphone
        }
    }
    var beats: [TapTapBeat] { [.loop(clip)] }

    /// Instants (ms, après le début du beat) où la main touche le dos dans V13b (×1,15) : deux taps par lecture.
    static let tapMoments: [Int] = [780, 1_020]
    /// Durée d'une lecture de V13b à ×1,15.
    static let tapLoopMs: Int = 2_500
}

/// L'iPhone (face ou dos) ; TapTap est dessiné par le METTEUR EN SCÈNE (une seule instance dans tout l'onboarding),
/// à qui cette vue publie la scène : le cadre du téléphone à l'écran, et l'occulteur quand la face est visible.
struct PhoneStageView<Front: View>: View {
    var stage: PhoneStage
    var frameWidth: CGFloat
    var accent: Color
    var tapEnabled: Bool = false
    var ripple: Int = 0
    var onDoubleTap: () -> Void = {}
    var arrival: Bool = false
    @ViewBuilder var front: Front

    /// Marges autour du cadre : TapTap dépasse à gauche et un peu en haut.
    static func stageSize(_ w: CGFloat) -> CGSize { CGSize(width: w * 1.72, height: w * GiantPhone.frameRatio + w * 0.16) }
    static func phoneOrigin(_ w: CGFloat) -> CGPoint { CGPoint(x: w * 0.70, y: w * 0.16) }

    var body: some View {
        let w = frameWidth
        let size = Self.stageSize(w)
        let origin = Self.phoneOrigin(w)
        ZStack(alignment: .topLeading) {
            Color.clear
            PhoneFlip(showBack: stage.isBack) {
                GiantPhoneFront(width: w) { front }
            } back: {
                GiantPhoneBack(width: w, accent: accent, tapEnabled: tapEnabled, ripple: ripple, onDoubleTap: onDoubleTap)
            }
            .shadow(color: HZ.Colors.ink.opacity(0.16), radius: 18, y: 10)
            .offset(x: origin.x, y: origin.y)
            .background(
                GeometryReader { geo in
                    let f = geo.frame(in: .named(onb3Space))
                    // f = le cadre du téléphone dans le repère de l'onboarding (le background a la taille du flip).
                    Color.clear.preference(key: TapTapSceneKey.self,
                                           value: TapTapScene(placement: .mapRect(canvas: TapTapClips.phoneFrame(stage.clip), screen: f),
                                                              beats: stage.beats, accent: accent, hidden: false,
                                                              transit: arrival ? .pouf : .cut,
                                                              occluder: stage.isBack ? nil : f,
                                                              occluderRadius: w * GiantPhone.frameRadius))
                }
                .offset(x: origin.x, y: origin.y)
            )
        }
        .frame(width: size.width, height: size.height)
    }
}
