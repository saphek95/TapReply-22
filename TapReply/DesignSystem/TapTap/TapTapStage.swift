import SwiftUI

// =============================================================================
// TAPTAP STAGE — LA seule façon de mettre TapTap à l'écran
// =============================================================================
//
// Une scène joue une SÉQUENCE de temps (« beats ») : chaque beat est un clip et
// la manière de le jouer. La scène garantit :
//
//   1. UNE SEULE GÉOMÉTRIE. Tous les clips partagent le canvas 675×1200 où
//      TapTap debout mesure 300 unités et pose ses jambes en (343,5 ; 748,5).
//      Le PLACEMENT dit comment ce canvas se pose dans la vue :
//        · `.ground(anchor, height)` — TapTap debout de `height` points, jambes
//          posées sur `anchor` (la règle pour tous les écrans « TapTap seul ») ;
//        · `.mapRect(canvas, screen)` — un rectangle du canvas (l'écran de
//          l'iPhone géant, la carte de membre) est plaqué sur un rectangle de
//          la vue : c'est l'OBJET qui est ancré, TapTap suit.
//
//   2. DES RACCORDS PAR COUPE. Quand un clip enchaîne sur un autre, la première
//      image du suivant remplace la dernière du précédent, sans superposition :
//      les clips commencent et finissent sur la même pose de repos (mesuré), donc
//      la coupe est invisible — et deux poses superposées se liraient comme deux
//      TapTap. UN SEUL TapTap à l'écran, toujours.
//
//   3. UN SEUL POINT DE RECOLORATION : la palette dérive de HZTheme (ou d'un
//      accent explicite, pour l'écran de choix de couleur).
//
// Utilisation :
//   TapTapStage(beats: [.play("V03", speed: 1.4), .loop("V04a")],
//               placement: .ground(anchor: CGPoint(x: 200, y: 500), height: 220))
// =============================================================================

struct TapTapBeat: Equatable, Identifiable {
    enum Mode: Equatable { case once, loop, holdLast, still }
    /// Identité PAR CONTENU : une séquence reconstruite à chaque rendu avec les mêmes beats ne doit jamais
    /// relancer le clip (un UUID régénéré recréait la vue à chaque passe de layout).
    var id: String { "\(clipID)|\(mode)|\(speed)" }
    let clipID: String
    var mode: Mode = .once
    var speed: Double = 1
    /// Garde la dernière image pendant ce délai (ms) avant de passer au beat suivant.
    var holdMs: Double = 0

    static func play(_ id: String, speed: Double = 1, holdMs: Double = 0) -> TapTapBeat { .init(clipID: id, mode: .once, speed: speed, holdMs: holdMs) }
    static func loop(_ id: String, speed: Double = 1) -> TapTapBeat { .init(clipID: id, mode: .loop, speed: speed) }
    /// Dernière image d'un clip, figée (= un still).
    static func still(_ id: String) -> TapTapBeat { .init(clipID: id, mode: .holdLast) }
    /// Première image d'un clip, figée.
    static func first(_ id: String) -> TapTapBeat { .init(clipID: id, mode: .still) }

    static func == (a: TapTapBeat, b: TapTapBeat) -> Bool {
        a.clipID == b.clipID && a.mode == b.mode && a.speed == b.speed && a.holdMs == b.holdMs
    }
}

/// Comment le canvas 675×1200 se pose dans la vue.
enum TapTapPlacement: Equatable {
    /// TapTap debout de `height` points, jambes sur `anchor` (dans la vue).
    case ground(anchor: CGPoint, height: CGFloat)
    /// Le rectangle `canvas` (unités du clip) est plaqué sur `screen` (points).
    case mapRect(canvas: CGRect, screen: CGRect)

    static let legs = CGPoint(x: 343.5, y: 748.5)
    static let standingHeight: CGFloat = 300
    static let canvasSize = CGSize(width: 675, height: 1200)

    /// (échelle canvas → points, origine du canvas dans la vue)
    var transform: (unit: CGFloat, origin: CGPoint) {
        switch self {
        case .ground(let anchor, let height):
            let u = height / Self.standingHeight
            return (u, CGPoint(x: anchor.x - Self.legs.x * u, y: anchor.y - Self.legs.y * u))
        case .mapRect(let canvas, let screen):
            let u = screen.width / max(1, canvas.width)
            return (u, CGPoint(x: screen.minX - canvas.minX * u, y: screen.minY - canvas.minY * u))
        }
    }

    /// Position d'un point du canvas dans la vue.
    func point(_ p: CGPoint) -> CGPoint {
        let t = transform; return CGPoint(x: t.origin.x + p.x * t.unit, y: t.origin.y + p.y * t.unit)
    }
    func rect(_ r: CGRect) -> CGRect {
        let t = transform
        return CGRect(x: t.origin.x + r.minX * t.unit, y: t.origin.y + r.minY * t.unit, width: r.width * t.unit, height: r.height * t.unit)
    }
}

/// Échelles de TapTap par rôle scénique (bible v2). Hauteur de TapTap DEBOUT en points.
enum TapTapScale {
    /// Héros : rencontre, couleur, victoire.
    static func hero(_ screen: CGSize) -> CGFloat { min(screen.height * 0.30, 290) }
    /// Guide : démos, réglages.
    static func guide(_ screen: CGSize) -> CGFloat { min(screen.height * 0.20, 190) }
    /// Compagnon : consentement, paywall, app quotidienne.
    static func companion(_ screen: CGSize) -> CGFloat { min(screen.height * 0.125, 118) }
}

struct TapTapStage: View {
    var beats: [TapTapBeat]
    var placement: TapTapPlacement
    /// Couleur d'accent explicite ; nil = thème de l'app.
    var accent: Color? = nil
    var crossfade: Double = 0.15
    /// Appelé à la fin de chaque beat (index), puis quand toute la séquence est finie (nil).
    var onBeat: ((Int?) -> Void)? = nil

    @ObservedObject private var theme = HZTheme.shared
    @State private var index = 0
    @State private var holdTask: Task<Void, Never>? = nil

    private var palette: TapTapPalette { TapTapPalette(accent: accent ?? Color(hex: UInt(theme.mascotHex))) }

    var body: some View {
        let t = placement.transform
        let canvasSize = CGSize(width: TapTapPlacement.canvasSize.width * t.unit, height: TapTapPlacement.canvasSize.height * t.unit)
        // Le canvas est POSITIONNÉ (centre) dans le repère de la vue hôte : la scène prend la taille que son
        // parent lui donne (un carré de 54 pt dans l'en-tête de l'accueil, tout l'écran dans l'onboarding) et
        // l'origine du canvas ne dépend jamais de la taille de la scène. (Un ZStack aligné topLeading centrait
        // le canvas dans les petits cadres : TapTap sortait du carré — l'avatar de l'accueil était invisible.)
        let center = CGPoint(x: t.origin.x + canvasSize.width / 2, y: t.origin.y + canvasSize.height / 2)
        ZStack {
            Color.clear
            // Le CONTENEUR positionné ne change jamais d'identité : c'est lui qui glisse (animation de `placement`).
            // Le lecteur, dedans, est recréé à chaque changement de clip (`.id`) — s'il portait lui-même la position,
            // un nouveau clip apparaissait directement à la position CIBLE (aucune animation : « il disparaît »).
            ZStack {
                // L'index est borné : quand la séquence change, on montre déjà le premier beat de la nouvelle DANS LA
                // MÊME passe (sinon, une image vide, et le nouveau lecteur naissait après le départ de l'animation).
                if !beats.isEmpty, let clip = TapTapClip.named(beats[min(index, beats.count - 1)].clipID) {
                    let beat = beats[min(index, beats.count - 1)]
                    Group {
                        switch beat.mode {
                        case .still:    FlipbookStill(clip: clip, palette: palette, last: false)
                        case .holdLast: FlipbookStill(clip: clip, palette: palette, last: true)
                        default:
                            FlipbookPlayer(clip: clip, palette: palette, speed: beat.speed, loops: beat.mode == .loop,
                                           onFinished: { finished(beat) })
                        }
                    }
                    .id("\(min(index, beats.count - 1))|\(beat.id)")
                    .transition(.identity)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(center)
        }
        .allowsHitTesting(false)
        .onChange(of: beats) { _, _ in
            // Nouvelle séquence : COUPE nette sur la première image (aucune image superposée : deux poses qui se
            // chevauchent, même 150 ms, se lisent comme deux TapTap — retour du 24/09).
            holdTask?.cancel()
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { index = 0 }
        }
    }

    private func finished(_ beat: TapTapBeat) {
        guard beat.mode == .once else { return }
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            if beat.holdMs > 0 { try? await Task.sleep(for: .milliseconds(beat.holdMs)) }
            guard !Task.isCancelled else { return }
            onBeat?(index)
            if index + 1 < beats.count {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { index += 1 }
            } else {
                onBeat?(nil)
            }
        }
    }
}

// MARK: - Le pouf

/// Trois ronds lavande qui naissent, s'écartent et se dissipent (bible : exactement trois, pas de volutes).
/// `appearing` = pouf d'apparition (TapTap arrive) ; sinon pouf de disparition.
struct TapTapPouf: View {
    var size: CGFloat = 160
    var color: Color = HZ.Colors.shadowSoft
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let a = Double(i) * 2.1 + 0.6
                Circle()
                    .fill(color)
                    .frame(width: size * [0.62, 0.48, 0.40][i], height: size * [0.62, 0.48, 0.40][i])
                    .offset(x: go ? CGFloat(cos(a)) * size * 0.30 : 0, y: go ? CGFloat(sin(a)) * size * 0.22 : 0)
                    .scaleEffect(go ? 1.25 : 0.2)
                    .opacity(go ? 0 : 0.95)
                    .animation(.easeOut(duration: 0.42).delay(Double(i) * 0.03), value: go)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}

// MARK: - Le hochement (animation SwiftUI sur une image figée)

/// Deux petits hochements de tout le corps, pivot au sol. Veo n'a jamais su faire un hochement seul ;
/// SwiftUI le fait en 250 ms, identique partout.
struct TapTapNod: ViewModifier {
    var trigger: Int
    @State private var angle: Double = 0
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle), anchor: .bottom)
            .onChange(of: trigger) { _, _ in
                Task { @MainActor in
                    for _ in 0..<2 {
                        withAnimation(.easeOut(duration: 0.07)) { angle = 6 }
                        try? await Task.sleep(for: .milliseconds(80))
                        withAnimation(.easeIn(duration: 0.09)) { angle = 0 }
                        try? await Task.sleep(for: .milliseconds(95))
                    }
                }
            }
    }
}

/// Le « non-non » : petite oscillation gauche-droite.
struct TapTapShake: ViewModifier {
    var trigger: Int
    @State private var x: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: x)
            .onChange(of: trigger) { _, _ in
                Task { @MainActor in
                    for k in 0..<3 {
                        withAnimation(.easeInOut(duration: 0.07)) { x = k % 2 == 0 ? -5 : 5 }
                        try? await Task.sleep(for: .milliseconds(75))
                    }
                    withAnimation(.easeOut(duration: 0.08)) { x = 0 }
                }
            }
    }
}

extension View {
    func tapTapNod(_ trigger: Int) -> some View { modifier(TapTapNod(trigger: trigger)) }
    func tapTapShake(_ trigger: Int) -> some View { modifier(TapTapShake(trigger: trigger)) }
}

// MARK: - Bibliothèque

/// Identifiants des clips et stills embarqués (fichiers .ttapz du bundle).
enum TapTapClips {
    // Acte 0 / idle
    static let sortieLampe = "V02f", coucou = "V03", idle = "V04a", idleRegard = "V04b", idleEtirement = "V04c"
    static let marche = "V07", arretMarche = "V08", sursaut = "V09", montreSortie = "V10a", montreRange = "V10b", rangeLampe = "V06d"
    // Actes 1–2 (scènes iPhone géant : ancrées sur l'iPhone)
    static let sortIphone = "V11", cacheCache1 = "V12a", cacheCache2 = "V12b", tapDosIphone = "V13b", invite = "V15", presente = "V51"
    static let litEtHoche = "V22", sautPerche = "V24"
    // Acte 3
    static let tendLaCarte = "V22b", miroir = "V34"
    static let reactionCouleur: [String] = ["V25", "V26", "V27", "V28", "V29", "V30", "V31", "V32", "V33"]   // ordre HZTheme.presets
    // Actes 4–5
    static let regardBas = "V36", hausseEpaules = "V37", metLunettes = "V39", pointe = "V40", attendLaPorte = "V41", coche = "V42"
    static let branditPancarte = "V44", nonNon = "V38", cloche = "V45", rangeLunettesPlongeon = "V46"
    // Acte 6 / app
    static let jaillitDuSol = "V47", danseClap = "V48", reposHeureux = "V49", pousseEpaule = "V58", souleveCarte = "V59"
    static let jetteCarte = "V60", designe = "V51b", tapisVolant = "V61", retireNoeudCoucou = "V52", miniDanse = "V56"
    // Stills (1 image)
    static let stillBase = "A0-0", stillBaseClosed = "A0-0-closed", stillProfesseur = "A4-1", stillAssisCarte = "A3_2_Assis_sur_la_carte_de_membre"
    static let stillReflexion = "A6_7_R_flexion_bras_au_menton", stillHistoriqueVide = "APP_1_Historique_vide_carnet_vide"
    static let stillErreur = "APP_2_Erreur_bulle_brouill_e", stillCredits = "APP_3_Cr_dits_puis_s_coffre_vide"
    static let stillPalmaresTemps = "PAL_1c_Palmar_s_temps_hamac_TapTap_assis", stillPalmaresReponses = "PAL_2_Palmar_s_r_ponses_avion_en_papier"
    static let stillPalmaresRang = "PAL_3_Palmar_s_classement_podium_et_cour"
    static let stillToneClassique = "TON_1_Classique_enveloppe", stillTonePro = "TON_2_Pro_n_ud_papillon_et_porte_documen"
    static let stillToneRigolo = "TON_3_Rigolo_nez_de_clown", stillToneCharmeur = "TON_4b_Charmeur_Cupidon"
    static let stillToneFact = "TON_5_FactChecker"

    /// Idle : trois variantes, jamais deux fois la même de suite.
    static func randomIdle(after previous: String? = nil) -> String {
        let pool = [idle, idle, idle, idleRegard, idleEtirement].filter { $0 != previous || $0 == idle }
        return pool.randomElement() ?? idle
    }

    // MARK: Rectangles mesurés dans le canvas (pipeline v3, image de référence de chaque clip)

    /// Le CADRE de l'iPhone géant dans le canvas de chaque clip (l'iPhone dessiné par Veo a été retiré des clips :
    /// l'app le dessine, net et stable, et plaque ce rectangle sur son propre iPhone → TapTap est exactement là
    /// où il doit être par rapport au téléphone). x, y, largeur, hauteur.
    static func phoneFrame(_ clip: String) -> CGRect {
        switch clip {
        case cacheCache1: return CGRect(x: 260, y: 231, width: 364, height: 711)
        case cacheCache2: return CGRect(x: 261, y: 211, width: 364, height: 733)
        case tapDosIphone, invite: return CGRect(x: 294, y: 142, width: 344, height: 715)
        case litEtHoche:  return CGRect(x: 260, y: 231, width: 367, height: 711)
        default:          return CGRect(x: 260, y: 231, width: 366, height: 712)
        }
    }
    /// Où TapTap pose ses jambes, en fraction du cadre de l'iPhone (x, y), pour les clips « debout » qui ne
    /// contiennent pas d'iPhone (idle, présente, sursaut…) : la relation mesurée dans V13b/V15 (il se tient à gauche,
    /// le bras atteint le dos). Jambes du canvas (343,5 ; 748,5) vs cadre (294, 142, 344 × 715).
    static let phoneSideLegs = CGPoint(x: (343.5 - 294) / 344, y: (748.5 - 142) / 344)
    static let phoneSideHeight: CGFloat = 300 / 344   // hauteur de TapTap debout, en largeurs de cadre
    /// La carte de membre tenue au-dessus de la tête (V22b, dernière image) : face de la carte (retirée du clip).
    static let memberCardFace = CGRect(x: 114, y: 167, width: 443, height: 268)
    /// La pancarte brandie (V44, dernière image) : planche (retirée du clip).
    static let signBoard = CGRect(x: 45, y: 144, width: 389, height: 277)

    // MARK: Stills in-app : cadrages (le personnage occupe la même hauteur partout)

    /// Cadrage carré d'un still de TON : la boîte du personnage ET de ses accessoires, mesurée dans le pipeline
    /// (marge 10 %) — le TapTap remplit la carte sans jamais être coupé, à la même échelle pour les cinq tons.
    static func toneCrop(_ id: String) -> CGRect {
        switch id {
        case stillToneClassique: return CGRect(x: 108, y: 110, width: 459, height: 459)
        case stillTonePro:       return CGRect(x: 118, y: 103, width: 460, height: 460)
        case stillToneRigolo:    return CGRect(x: 129, y: 134, width: 443, height: 443)
        case stillToneCharmeur:  return CGRect(x: 60, y: 49, width: 551, height: 551)
        case stillToneFact:      return CGRect(x: 12, y: -26, width: 661, height: 661)
        default:                 return CGRect(x: 0, y: 0, width: 675, height: 675)
        }
    }
    /// Cadrage « médaillon » (pastilles rondes de l'Historique et des slots) : le même cadrage, élargi de 8 %
    /// (un rond coupe les coins d'un carré : on garde le personnage entier).
    static func toneFaceCrop(_ id: String) -> CGRect {
        let c = toneCrop(id); return c.insetBy(dx: -c.width * 0.04, dy: -c.height * 0.04)
    }
    static func toneStill(forAsset asset: String) -> String? {
        switch asset {
        case "ToneClassique": return stillToneClassique
        case "TonePro":       return stillTonePro
        case "ToneRigolo":    return stillToneRigolo
        case "ToneCharmeur":  return stillToneCharmeur
        case "ToneFact":      return stillToneFact
        default: return nil
        }
    }
}

// MARK: - Vues utilitaires in-app

/// Un still (ou la dernière image d'un clip) qui REMPLIT une vue, recoloré : palmarès, tons, états d'app.
/// Le canvas est recadré sur la boîte du dessin (les stills ont des marges) via `crop`, en unités du canvas.
struct TapTapStillView: View {
    let id: String
    var accent: Color? = nil
    /// Zone du canvas à montrer (par défaut : tout le canvas du still).
    var crop: CGRect? = nil
    var last: Bool = true
    @ObservedObject private var theme = HZTheme.shared

    var body: some View {
        GeometryReader { geo in
            if let clip = TapTapClip.named(id) {
                let region = crop ?? CGRect(x: 0, y: 0, width: clip.width, height: clip.height)
                let scale = min(geo.size.width / region.width, geo.size.height / region.height)
                let origin = CGPoint(x: (geo.size.width - region.width * scale) / 2 - region.minX * scale,
                                     y: (geo.size.height - region.height * scale) / 2 - region.minY * scale)
                FlipbookStill(clip: clip, palette: TapTapPalette(accent: accent ?? Color(hex: UInt(theme.mascotHex))), last: last)
                    .frame(width: clip.width * scale, height: clip.height * scale)
                    .offset(x: origin.x, y: origin.y)
            }
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

/// TapTap debout dans un carré : avatar de l'accueil, grand TapTap des Réglages, île simulée.
/// `beats` par défaut : repos-clignement en boucle.
struct TapTapFigure: View {
    var size: CGFloat
    var beats: [TapTapBeat] = [.loop(TapTapClips.idle)]
    var accent: Color? = nil
    var onBeat: ((Int?) -> Void)? = nil

    var body: some View {
        // TapTap debout = 300 unités : dans un carré de `size`, il mesure size × 0,80, jambes posées à 92 % de la
        // hauteur. Le cadre n'est PAS rogné : un bras levé (coucou, danse) dépasse du carré au lieu d'être coupé
        // « comme dans une boîte » (retour du 25/09). Le carré ne sert qu'à la mise en page et au toucher.
        TapTapStage(beats: beats,
                    placement: .ground(anchor: CGPoint(x: size / 2, y: size * 0.92), height: size * 0.80),
                    accent: accent, onBeat: onBeat)
            .frame(width: size, height: size)
    }
}

/// L'avatar de l'accueil (54 pt) : il respire et cligne ; au retour dans l'app il fait coucou ; s'il y a eu
/// une nouvelle réponse depuis la dernière visite, mini-danse UNE fois ; un tap = un gag au hasard.
struct TapTapAvatar: View {
    var size: CGFloat = 54
    /// Passe à true pour déclencher la mini-danse (nouvelle réponse) ; remis à false par la vue.
    var celebrate: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.scenePhase) private var scenePhase
    @State private var beats: [TapTapBeat] = [.loop(TapTapClips.idle)]
    @State private var lastIdle = TapTapClips.idle

    var body: some View {
        TapTapFigure(size: size, beats: beats, onBeat: { i in if i == nil { rest() } })
            .contentShape(Circle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                gag()
                onTap?()
            }
            .onChange(of: scenePhase) { _, p in
                // Retour au premier plan après une vraie absence (> 10 min) : il salue. Pas à chaque onglet.
                if p == .active, Date().timeIntervalSince(Self.lastWave) > 600 { wave() }
            }
            .onChange(of: celebrate) { _, on in if on { dance() } }
            .onAppear {
                if celebrate { dance() }
                else if !Self.wavedThisLaunch { wave() }
            }
    }

    /// Le coucou d'accueil : UNE fois par lancement (l'accueil est reconstruit à chaque retour d'onglet).
    private static var wavedThisLaunch = false
    private static var lastWave = Date.distantPast

    private func rest() {
        lastIdle = TapTapClips.randomIdle(after: lastIdle)
        beats = [.loop(lastIdle)]
    }
    private func wave()  {
        Self.wavedThisLaunch = true; Self.lastWave = Date()
        beats = [.play(TapTapClips.coucou, speed: 1.6), .loop(TapTapClips.idle)]
    }
    private func dance() { beats = [.play(TapTapClips.miniDanse, speed: 1.2), .loop(TapTapClips.idle)] }
    private func gag() {
        let pool = [TapTapClips.idleEtirement, TapTapClips.miroir, TapTapClips.idleRegard, TapTapClips.coucou]
        beats = [.play(pool.randomElement()!, speed: 1.3), .loop(TapTapClips.idle)]
    }
}

// MARK: - UNE couleur pour TapTap et pour l'app

/// La couleur de TapTap EST la couleur de l'app. Un seul point d'entrée pour la changer : il met à jour le thème
/// (toute l'interface) et l'index de couleur (assets PNG hérités : Live Activity, notification, carte de partage).
enum TapTapColor {
    /// L'onboarding : UNE couleur pour TapTap ET pour l'app.
    static func apply(index: Int) {
        let i = max(0, min(index, HZTheme.presets.count - 1))
        HZTheme.shared.accentHex = HZTheme.presets[i]
        HZTheme.shared.mascotIndex = i
    }
    /// Les Réglages : la couleur de TapTap seule.
    static func applyMascot(index: Int) { HZTheme.shared.mascotIndex = max(0, min(index, HZTheme.presets.count - 1)) }
    static var mascotIndex: Int { HZTheme.shared.mascotIndex }
    /// L'index courant de la couleur de TapTap.
    static var index: Int { HZTheme.shared.mascotIndex }
}
