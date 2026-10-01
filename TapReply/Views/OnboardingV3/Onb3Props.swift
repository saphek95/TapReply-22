import SwiftUI
import AVFoundation

// =============================================================================
// LES OBJETS DESSINÉS PAR L'APP — lampe, carte de membre, pancarte, arc de couleurs
// =============================================================================
//
// Ces objets étaient dessinés par Veo dans les clips (et vectorisés avec eux) :
// bords tremblants, blanc dans la poignée de la lampe, traits pas droits sur la
// carte. Ils sont maintenant retirés des clips et dessinés ici, en SwiftUI :
// nets, animables séparément de TapTap, et recolorés avec sa couleur.
// =============================================================================

// MARK: - La lampe de génie

struct GenieLamp: View {
    var width: CGFloat
    /// Balancement (degrés) appliqué autour de la base.
    var rock: Double = 0
    var glow: Bool = false

    private let gold = Color(hex: 0xF1A12A)
    private let goldDeep = Color(hex: 0xD68D32)
    private let goldLight = Color(hex: 0xF6C55C)

    var body: some View {
        let h = width * 0.62
        ZStack {
            if glow {
                Ellipse().fill(RadialGradient(colors: [goldLight.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: width * 0.55))
                    .frame(width: width * 1.3, height: h * 1.3)
                    .offset(y: -h * 0.1)
                    .blendMode(.screen)
            }
            Canvas { gc, size in
                let W = size.width, H = size.height
                // Base
                var base = Path()
                base.addEllipse(in: CGRect(x: W * 0.30, y: H * 0.86, width: W * 0.40, height: H * 0.12))
                gc.fill(base, with: .color(goldDeep))
                // Pied
                var foot = Path()
                foot.move(to: CGPoint(x: W * 0.42, y: H * 0.90))
                foot.addLine(to: CGPoint(x: W * 0.58, y: H * 0.90))
                foot.addLine(to: CGPoint(x: W * 0.55, y: H * 0.74))
                foot.addLine(to: CGPoint(x: W * 0.45, y: H * 0.74))
                foot.closeSubpath()
                gc.fill(foot, with: .color(gold))
                // Corps (galbe)
                var body = Path()
                body.move(to: CGPoint(x: W * 0.22, y: H * 0.52))
                body.addCurve(to: CGPoint(x: W * 0.78, y: H * 0.52), control1: CGPoint(x: W * 0.30, y: H * 0.22), control2: CGPoint(x: W * 0.70, y: H * 0.22))
                body.addCurve(to: CGPoint(x: W * 0.50, y: H * 0.80), control1: CGPoint(x: W * 0.82, y: H * 0.72), control2: CGPoint(x: W * 0.68, y: H * 0.80))
                body.addCurve(to: CGPoint(x: W * 0.22, y: H * 0.52), control1: CGPoint(x: W * 0.32, y: H * 0.80), control2: CGPoint(x: W * 0.18, y: H * 0.72))
                body.closeSubpath()
                gc.fill(body, with: .linearGradient(Gradient(colors: [goldLight, gold, goldDeep]), startPoint: CGPoint(x: W * 0.3, y: H * 0.3), endPoint: CGPoint(x: W * 0.7, y: H * 0.8)))
                // Bec
                var spout = Path()
                spout.move(to: CGPoint(x: W * 0.24, y: H * 0.48))
                spout.addCurve(to: CGPoint(x: W * 0.02, y: H * 0.26), control1: CGPoint(x: W * 0.16, y: H * 0.44), control2: CGPoint(x: W * 0.06, y: H * 0.36))
                spout.addLine(to: CGPoint(x: W * 0.10, y: H * 0.22))
                spout.addCurve(to: CGPoint(x: W * 0.30, y: H * 0.40), control1: CGPoint(x: W * 0.14, y: H * 0.30), control2: CGPoint(x: W * 0.22, y: H * 0.38))
                spout.closeSubpath()
                gc.fill(spout, with: .color(gold))
                // Anse (anneau creux : un seul chemin en even-odd, aucun blanc dedans)
                var handle = Path()
                handle.addEllipse(in: CGRect(x: W * 0.70, y: H * 0.30, width: W * 0.26, height: H * 0.34))
                handle.addEllipse(in: CGRect(x: W * 0.75, y: H * 0.36, width: W * 0.16, height: H * 0.22))
                gc.fill(handle, with: .color(goldDeep), style: FillStyle(eoFill: true))
                // Couvercle + bouton
                var lid = Path()
                lid.addEllipse(in: CGRect(x: W * 0.36, y: H * 0.20, width: W * 0.28, height: H * 0.12))
                gc.fill(lid, with: .color(goldDeep))
                var knob = Path()
                knob.addEllipse(in: CGRect(x: W * 0.46, y: H * 0.12, width: W * 0.08, height: H * 0.12))
                gc.fill(knob, with: .color(goldLight))
                // Reflet
                var shine = Path()
                shine.addEllipse(in: CGRect(x: W * 0.36, y: H * 0.36, width: W * 0.10, height: H * 0.16))
                gc.fill(shine, with: .color(.white.opacity(0.28)))
            }
            .frame(width: width, height: h)
        }
        .frame(width: width, height: h)
        .rotationEffect(.degrees(rock), anchor: .bottom)
    }

    /// Le bout du bec, dans le repère de la lampe (d'où TapTap sort).
    static func spout(_ width: CGFloat) -> CGPoint { CGPoint(x: width * 0.06, y: width * 0.62 * 0.24) }
}

// MARK: - La carte de membre

struct MemberCard: View {
    @Binding var name: String
    var accent: Color
    var width: CGFloat
    var focused: FocusState<Bool>.Binding

    var body: some View {
        let h = width * (268.0 / 443.0)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: width * 0.03, weight: .heavy)).foregroundStyle(.white)
                Text(verbatim: "TapReply").font(HZ.Fonts.fig(width * 0.036, .heavy)).foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(String(localized: "MEMBRE")).font(HZ.Fonts.fig(width * 0.028, .heavy)).tracking(1.2).foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, width * 0.055).padding(.vertical, width * 0.03)
            .background(accent)

            Spacer(minLength: 0)

            TextField("", text: $name, prompt: Text(String(localized: "ton prénom")).foregroundColor(HZ.Colors.faint))
                .font(HZ.Fonts.fig(width * 0.085, .heavy))
                .foregroundStyle(HZ.Colors.ink)
                .tint(accent)
                .focused(focused)
                .submitLabel(.done)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onSubmit { focused.wrappedValue = false }
                .onChange(of: name) { _, n in if n.count > 20 { name = String(n.prefix(20)) } }
                .padding(.horizontal, width * 0.055)

            Spacer(minLength: 0)

            HStack {
                Text(String(localized: "membre depuis aujourd'hui"))
                    .font(HZ.Fonts.fig(width * 0.03, .semibold)).foregroundStyle(HZ.Colors.faint)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, width * 0.055).padding(.bottom, width * 0.04)
        }
        .frame(width: width, height: h)
        .background(RoundedRectangle(cornerRadius: width * 0.055, style: .continuous).fill(.white))
        .clipShape(RoundedRectangle(cornerRadius: width * 0.055, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: width * 0.055, style: .continuous)
            .strokeBorder(focused.wrappedValue ? accent : HZ.Colors.line, lineWidth: focused.wrappedValue ? 2 : 1))
        .shadow(color: accent.opacity(focused.wrappedValue ? 0.22 : 0.12), radius: 16, y: 8)
        // Ses MAINS : les bras du clip montent jusque sous la carte (x 0,17 et 0,85 de sa largeur, larges de 0,13) ;
        // ici, le bout de chaque bras — la même forme arrondie que ses bras — passe DEVANT le bord bas et s'y
        // referme : il tient la carte. Le bas du bout est dans le prolongement exact du bras dessous.
        .overlay(alignment: .topLeading) {
            ForEach([0.169, 0.849], id: \.self) { fx in
                let hw = width * 0.128
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: hw / 2, style: .continuous)
                        .fill(accent)
                        .frame(width: hw, height: width * 0.15)
                    // le bord de la carte qui « rentre » dans la main : une fine ombre du bord sur le bras
                    Capsule().fill(HZ.Colors.ink.opacity(0.12))
                        .frame(width: hw * 0.72, height: width * 0.014)
                        .offset(y: width * 0.022)
                }
                .offset(x: width * fx - hw / 2, y: h - width * 0.035)   // le bout chevauche le bord, le reste se fond dans le bras
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = true }
    }
}

// MARK: - La pancarte

struct SignBoard: View {
    var text: String
    var width: CGFloat
    var accent: Color

    var body: some View {
        let h = width * (277.0 / 389.0)
        Text(text)
            .font(HZ.Fonts.fig(width * 0.13, .heavy))
            .foregroundStyle(HZ.Colors.ink)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .padding(width * 0.06)
            .frame(width: width, height: h)
            .background(RoundedRectangle(cornerRadius: width * 0.06, style: .continuous).fill(Color(hex: 0xFFFDF7)))
            .overlay(RoundedRectangle(cornerRadius: width * 0.06, style: .continuous).strokeBorder(Color(hex: 0xC58F5A), lineWidth: width * 0.025))
            .overlay(alignment: .top) {
                Capsule().fill(accent).frame(width: width * 0.5, height: width * 0.03).offset(y: width * 0.10)
            }
            .shadow(color: HZ.Colors.ink.opacity(0.12), radius: 10, y: 5)
    }
}

// MARK: - L'arc des neuf couleurs

/// Neuf pastilles sur un arc au-dessus de TapTap : de gauche à droite, dans l'ordre de HZTheme.presets.
struct ColorArc: View {
    var selected: Int
    var radius: CGFloat
    var chip: CGFloat = 40
    var onPick: (Int) -> Void

    var body: some View {
        let n = HZTheme.presets.count
        ZStack {
            ForEach(Array(HZTheme.presets.enumerated()), id: \.offset) { i, hex in
                let color = Color(hex: UInt(hex))
                // de 196° (gauche, un peu sous l'horizontale) à −16° (droite)
                let a = (196 - Double(i) * (212.0 / Double(n - 1))) * .pi / 180
                let on = selected == i
                Button { onPick(i) } label: {
                    Circle().fill(color)
                        .frame(width: chip, height: chip)
                        .overlay { if on { Circle().strokeBorder(.white, lineWidth: 3).padding(3) } }
                        .overlay { Circle().strokeBorder(color, lineWidth: 2.5).padding(-5).opacity(on ? 1 : 0) }
                        .shadow(color: color.opacity(on ? 0.5 : 0.18), radius: on ? 10 : 4, y: 3)
                        .scaleEffect(on ? 1.12 : 1)
                }
                .buttonStyle(.plain)
                .offset(x: CGFloat(cos(a)) * radius, y: -CGFloat(sin(a)) * radius)
                .animation(.spring(duration: 0.35), value: selected)
            }
        }
        .frame(width: radius * 2 + chip + 16, height: radius + chip + 16)
        .offset(y: (radius + chip / 2) / 2 - 4)
    }
}

// MARK: - La vidéo de la lampe (séquence approuvée du 08/09, nuage « pouf rond »)


/// Lit `TapTap-lampe-pop.mp4` (3 s, 24 i/s, fond blanc) sans aucun contrôle : image 0 figée tant que `play` est faux,
/// puis lecture unique. `onTime` reçoit la position (s) à chaque image ; `onEnd` à la fin.
struct LampVideoPlayer: UIViewRepresentable {
    var play: Bool
    var onTime: ((Double) -> Void)? = nil
    var onEnd: (() -> Void)? = nil

    final class PlayerView: UIView {
        let playerLayer = AVPlayerLayer()
        var player: AVPlayer?
        var started = false
        var timeObserver: Any?
        var endObserver: NSObjectProtocol?
        var activeObserver: NSObjectProtocol?
        override func layoutSubviews() { super.layoutSubviews(); playerLayer.frame = bounds }
        deinit {
            if let o = timeObserver { player?.removeTimeObserver(o) }
            if let e = endObserver { NotificationCenter.default.removeObserver(e) }
            if let a = activeObserver { NotificationCenter.default.removeObserver(a) }
        }
    }

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.backgroundColor = .clear
        v.playerLayer.videoGravity = .resizeAspect
        v.layer.addSublayer(v.playerLayer)
        guard let url = Bundle.main.url(forResource: "TapTap-lampe-pop", withExtension: "mp4") else {
            assertionFailure("Vidéo de la lampe introuvable"); return v
        }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.actionAtItemEnd = .pause
        p.isMuted = true
        v.player = p
        v.playerLayer.player = p
        p.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        let onTime = onTime, onEnd = onEnd
        v.timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 24), queue: .main) { t in
            onTime?(t.seconds)
        }
        v.endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            onEnd?()
        }
        // Retour au premier plan pendant la lecture : iOS a mis l'AVPlayer en pause, on reprend.
        v.activeObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak v] _ in
            guard let v, v.started, let p = v.player, p.rate == 0,
                  let item = p.currentItem, item.currentTime() < item.duration else { return }
            p.play()
        }
        return v
    }

    func updateUIView(_ v: PlayerView, context: Context) {
        if play, !v.started, let p = v.player {
            v.started = true
            p.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in p.play() }
        }
    }
}

/// Géométrie de la vidéo (1080 × 1920) : où TapTap se pose à la fin (mesuré sur le montage approuvé).
enum LampVideo {
    static let size = CGSize(width: 1080, height: 1920)
    /// Le bec de la lampe (d'où il sort).
    static let spout = CGPoint(x: 836, y: 892)
    /// Ses jambes à la position finale (centre 550 × 530, hauteur 320 px → bas des jambes ≈ 688).
    static let finalLegs = CGPoint(x: 550, y: 688)
    /// Hauteur de TapTap debout à la fin (dôme → jambes), en pixels vidéo.
    static let finalHeight: CGFloat = 311
    /// Instant où il est posé et immobile.
    static let settledAt: Double = 1.95
    /// Les PNG de l'image 0 (lampe seule / ombre seule), chargés par chemin : ils sont dans TapTapAssets, pas dans un
    /// catalogue d'assets (Image("nom") ne les trouvait pas).
    static func image(_ name: String) -> UIImage {
        if let p = Bundle.main.path(forResource: name, ofType: "png"), let img = UIImage(contentsOfFile: p) { return img }
        assertionFailure("Image de la lampe introuvable : \(name)"); return UIImage()
    }
}

// MARK: - L'écran d'accueil de l'iPhone géant (S5 : « c'est moi dans ta poche »)

/// Une grille d'icônes stylisées et un dock : on comprend que c'est un téléphone, avant d'ouvrir la conversation.
struct PhoneHomeScreen: View {
    var width: CGFloat
    var accent: Color
    var highlightMessages: Bool = false

    private let tints: [Color] = [Color(hex: 0xFF9F0A), Color(hex: 0x30D158), Color(hex: 0x64D2FF), Color(hex: 0xFF375F),
                                  Color(hex: 0xBF5AF2), Color(hex: 0xFFD60A), Color(hex: 0x5E5CE6), Color(hex: 0xFF6B6B),
                                  Color(hex: 0x8E8E93), Color(hex: 0x34C759), Color(hex: 0x0A84FF), Color(hex: 0xAC8E68)]

    var body: some View {
        let s = width / 230
        let icon = 34 * s
        VStack(spacing: 14 * s) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12 * s), count: 4), spacing: 12 * s) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: icon * 0.26, style: .continuous)
                        .fill(tints[i].opacity(0.85))
                        .frame(width: icon, height: icon)
                        .overlay {
                            if i == 1 {
                                Image(systemName: "message.fill").font(.system(size: icon * 0.5, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if i == 1 && highlightMessages {
                                Text(verbatim: "1").font(HZ.Fonts.fig(9 * s, .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 5 * s).padding(.vertical, 2 * s)
                                    .background(Capsule().fill(HZ.Colors.mRed))
                                    .offset(x: 5 * s, y: -5 * s)
                            }
                        }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 12 * s) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: icon * 0.26, style: .continuous)
                        .fill([Color(hex: 0x30D158), accent, Color(hex: 0xFF9F0A), Color(hex: 0x8E8E93)][i].opacity(0.85))
                        .frame(width: icon, height: icon)
                        .overlay {
                            if i == 1 { Image(systemName: "bolt.fill").font(.system(size: icon * 0.5, weight: .bold)).foregroundStyle(.white) }
                        }
                }
            }
            .padding(10 * s)
            .background(RoundedRectangle(cornerRadius: 22 * s, style: .continuous).fill(HZ.Colors.ink.opacity(0.08)))
            .padding(.bottom, 10 * s)
        }
        .padding(.horizontal, 14 * s)
        .padding(.top, 6 * s)
    }
}
