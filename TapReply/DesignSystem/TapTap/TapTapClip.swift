import SwiftUI
import Compression

// =============================================================================
// TAPTAP — CLIPS VECTORIELS (format TTAP v1)
// =============================================================================
//
// Un clip est une suite d'images vectorielles (flipbook) produites par le
// pipeline Anim8 → normalisation → compilation. Chaque forme porte un RÔLE :
// les rôles « accent » sont recolorés à l'exécution avec la couleur choisie par
// l'utilisateur ; les autres sont figés sur la palette canonique de TapTap.
//
// RÈGLE : ne jamais dessiner TapTap autrement que par ce lecteur. Une seule
// source de vérité géométrique (canvas 675×1200, sol à y = 748,5, centre des
// jambes à x = 343,5, TapTap debout = 300 unités de haut) garantit qu'il a la
// même silhouette sur tous les écrans.
// =============================================================================

enum TapTapRole: UInt8 {
    case accent = 0, accentLight = 1, accentDark = 2, body = 3, legs = 4, ink = 5, blush = 6, shadow = 7, white = 8, prop = 9
}

struct TapTapShape {
    let role: TapTapRole
    let propColor: Color?
    let path: Path
}

struct TapTapFrame {
    /// Nombre d'images vidéo (à `fps`) pendant lesquelles cette image reste affichée.
    let hold: Int
    let shapes: [TapTapShape]
}

enum TapTapClipType: UInt8 { case action = 0, loop = 1, transit = 2 }

final class TapTapClip {
    let id: String
    let fps: Int
    let width: CGFloat
    let height: CGFloat
    let type: TapTapClipType
    let holdsEnd: Bool
    let frames: [TapTapFrame]
    /// Index d'image où la boucle reprend (les images [0, loopStart) forment une intro jouée une seule fois :
    /// c'est elle qui assure le raccord avec le clip précédent).
    let loopStartFrame: Int

    /// Nombre total d'images vidéo (holds compris).
    let totalTicks: Int
    /// Tick correspondant à `loopStartFrame`.
    let loopStartTick: Int
    /// Index d'image pour chaque tick, précalculé pour un accès O(1).
    private let tickToFrame: [Int]

    var durationSeconds: Double { Double(totalTicks) / Double(fps) }

    init(id: String, fps: Int, width: CGFloat, height: CGFloat, type: TapTapClipType, holdsEnd: Bool, frames: [TapTapFrame], loopStartFrame: Int = 0) {
        self.id = id; self.fps = fps; self.width = width; self.height = height
        self.type = type; self.holdsEnd = holdsEnd; self.frames = frames
        self.loopStartFrame = min(max(0, loopStartFrame), max(0, frames.count - 1))
        var map: [Int] = []; var lst = 0
        for (i, f) in frames.enumerated() {
            if i == self.loopStartFrame { lst = map.count }
            for _ in 0..<max(1, f.hold) { map.append(i) }
        }
        tickToFrame = map; totalTicks = map.count; loopStartTick = lst
    }

    /// Tick à afficher pour un temps écoulé brut (en ticks) selon le type de clip.
    func tick(forElapsed raw: Int) -> Int {
        switch type {
        case .loop:
            if raw < totalTicks { return raw }
            let span = max(1, totalTicks - loopStartTick)
            return loopStartTick + (raw - totalTicks) % span
        default:
            return min(raw, totalTicks - 1)
        }
    }

    func frame(atTick tick: Int) -> TapTapFrame {
        let t = max(0, min(totalTicks - 1, tick))
        return frames[tickToFrame[t]]
    }

    // MARK: - Chargement

    /// Cache global : un clip n'est décodé qu'une fois par processus.
    private static var cache: [String: TapTapClip] = [:]
    private static let lock = NSLock()
    /// Sous pression mémoire, on vide le cache : les clips se redécodent à la demande (≈ 2 ms chacun).
    private static let memoryObserver: Void = {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil, queue: .main) { _ in
            lock.lock(); cache.removeAll(); lock.unlock()
        }
    }()

    static func named(_ id: String) -> TapTapClip? {
        _ = memoryObserver
        lock.lock(); defer { lock.unlock() }
        if let c = cache[id] { return c }
        guard let url = Bundle.main.url(forResource: id, withExtension: "ttap") ?? Bundle.main.url(forResource: id, withExtension: "ttapz"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("TapTap clip introuvable : \(id)"); return nil
        }
        let clip = decode(data, id: id)
        cache[id] = clip
        return clip
    }

    /// Précharge une liste de clips en arrière-plan (à appeler au démarrage d'un acte).
    static func preload(_ ids: [String]) {
        DispatchQueue.global(qos: .userInitiated).async { ids.forEach { _ = named($0) } }
    }

    // MARK: - Décodage TTAP v1

    static func decode(_ raw: Data, id: String) -> TapTapClip? {
        var data = raw
        if data.count < 4 || data[data.startIndex] != 0x54 /* T */ {
            // fichier compressé (zlib) → on décompresse
            guard let d = inflate(data) else { return nil }
            data = d
        }
        var r = ByteReader(data)
        guard r.string(4) == "TTAP" else { return nil }
        let version = r.u8()
        guard version == 2 else { assertionFailure("TTAP v\(version) non supporté (attendu v2, coordonnées en deltas)"); return nil }
        let fps = Int(r.u8()); let w = CGFloat(r.u16()); let h = CGFloat(r.u16())
        let type = TapTapClipType(rawValue: r.u8()) ?? .action
        let hold = r.u8() == 1
        _ = r.u8(); _ = r.u8(); _ = r.u8()      // accent par défaut (informative)
        let frameCount = Int(r.u16()); let loopStart = Int(r.u16())
        var frames: [TapTapFrame] = []; frames.reserveCapacity(frameCount)
        for _ in 0..<frameCount {
            let t = Int(r.u8()); let n = Int(r.u16())
            var shapes: [TapTapShape] = []; shapes.reserveCapacity(n)
            for _ in 0..<n {
                let role = TapTapRole(rawValue: r.u8()) ?? .prop
                let cr = r.u8(), cg = r.u8(), cb = r.u8()
                let tokens = Int(r.u16())
                var path = Path()
                var i = 0
                // v2 : chaque coordonnée est un delta (en dixièmes de pixel) par rapport au point précédent,
                // y compris entre les points de contrôle d'une courbe. Le point courant persiste entre commandes.
                var cur = CGPoint.zero
                while i < tokens {
                    let cmd = r.u8(); i += 1
                    switch cmd {
                    case 0: cur = r.delta(from: cur); path.move(to: cur); i += 2
                    case 1: cur = r.delta(from: cur); path.addLine(to: cur); i += 2
                    case 2:
                        let c1 = r.delta(from: cur); let c2 = r.delta(from: c1); cur = r.delta(from: c2)
                        path.addCurve(to: cur, control1: c1, control2: c2); i += 6
                    case 3:
                        let c = r.delta(from: cur); cur = r.delta(from: c)
                        path.addQuadCurve(to: cur, control: c); i += 4
                    default: path.closeSubpath()
                    }
                }
                let color: Color? = role == .prop ? Color(red: Double(cr) / 255, green: Double(cg) / 255, blue: Double(cb) / 255) : nil
                shapes.append(TapTapShape(role: role, propColor: color, path: path))
            }
            frames.append(TapTapFrame(hold: max(1, t), shapes: shapes))
        }
        return TapTapClip(id: id, fps: fps, width: w, height: h, type: type, holdsEnd: hold, frames: frames, loopStartFrame: loopStart)
    }

    private static func inflate(_ data: Data) -> Data? {
        // zlib avec en-tête (RFC 1950) : on saute les 2 octets d'en-tête pour COMPRESSION_ZLIB (deflate brut)
        let src = data.dropFirst(2)
        let dstSize = 16 * 1024 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize); defer { dst.deallocate() }
        let n = src.withUnsafeBytes { p -> Int in
            compression_decode_buffer(dst, dstSize, p.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
        }
        return n > 0 ? Data(bytes: dst, count: n) : nil
    }
}

/// Lecteur binaire little-endian minimal.
private struct ByteReader {
    let d: Data; var o: Int
    init(_ d: Data) { self.d = d; o = d.startIndex }
    mutating func u8() -> UInt8 { defer { o += 1 }; return d[o] }
    mutating func u16() -> UInt16 { let v = UInt16(d[o]) | UInt16(d[o + 1]) << 8; o += 2; return v }
    mutating func i16() -> Int16 { Int16(bitPattern: u16()) }
    mutating func string(_ n: Int) -> String { defer { o += n }; return String(decoding: d[o..<o + n], as: UTF8.self) }
    /// Coordonnée stockée en dixièmes de pixel, en delta par rapport au point précédent.
    mutating func delta(from p: CGPoint) -> CGPoint {
        let dx = CGFloat(i16()) / 10, dy = CGFloat(i16()) / 10
        return CGPoint(x: p.x + dx, y: p.y + dy)
    }
}

// MARK: - Palette

struct TapTapPalette {
    var accent: Color
    static let body   = Color(hex: 0xFCF6EA)
    static let legs   = Color(hex: 0xE8DBD6)
    static let ink    = Color(hex: 0x2F2855)
    static let blush  = Color(hex: 0xF7757E)
    static let shadow = Color(hex: 0xEDEBF7)

    func color(for shape: TapTapShape) -> Color {
        switch shape.role {
        case .accent:      return accent
        case .accentLight: return accent.mixed(with: .white, amount: 0.28)
        case .accentDark:  return accent.mixed(with: .black, amount: 0.22)
        case .body:        return Self.body
        case .legs:        return Self.legs
        case .ink:         return Self.ink
        case .blush:       return Self.blush
        case .shadow:      return Self.shadow
        case .white:       return .white
        case .prop:        return shape.propColor ?? Self.ink
        }
    }
}

extension Color {
    // `Color(hex: UInt)` est fourni par DesignSystem.swift — on ne le redéfinit pas.
    /// Mélange linéaire en sRGB — identique à la formule du pipeline (lighten/darken).
    func mixed(with other: Color, amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1); b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(amount)
        return Color(red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k), blue: Double(b1 + (b2 - b1) * k))
    }
}
