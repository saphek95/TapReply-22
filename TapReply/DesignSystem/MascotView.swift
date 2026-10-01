import SwiftUI

// =============================================================================
// TAPTAP — LA MASCOTTE
// =============================================================================
//
// RÈGLE D'ARCHITECTURE — à ne pas enfreindre :
//
//   Chaque partie du personnage est une `Shape` qui reçoit la frame ENTIÈRE
//   (size × size) et se dessine à ses coordonnées ABSOLUES dans le repère 600
//   du SVG de référence. Aucun `.position`, aucun `.offset` n'est utilisé pour
//   PLACER quoi que ce soit — uniquement pour ANIMER.
//
// Pourquoi cette règle existe : la version précédente plaçait les yeux avec
// `.position()` à l'intérieur d'une vue à laquelle aucune frame n'avait été
// imposée. SwiftUI n'avait donc aucune taille de référence, et les yeux comme
// les paupières atterrissaient n'importe où — la paupière, peinte de la couleur
// du dôme pour être invisible au repos, se lisait alors comme une barre bleue
// qui s'étirait au rythme du clignement. Un seul oubli de frame, et le
// personnage entier était cassé sur les seize écrans.
//
// SECONDE RÈGLE, apprise au prix de deux livraisons : sur une piste de
// keyframes dont les durées sont très inégales, n'utiliser QUE des
// LinearKeyframe. CubicKeyframe calcule ses tangentes d'après les segments
// voisins ; un battement de 0,07 s entouré de paliers de 3 s lui fait produire
// des dépassements massifs, et la valeur animée sort de ses bornes.
//
// Toutes les coordonnées ci-dessous sont transcrites du SVG validé
// (mascotte/tapreply-mascotte.svg, viewBox 0 0 600 600). Ne pas les « ajuster
// à l'œil » : si une proportion doit changer, elle change d'abord dans le SVG.
// =============================================================================

enum MascotAct: Equatable {
    /// Immobile — pour les vignettes et les icônes.
    case still
    /// Respire et flotte. L'état par défaut de tout écran.
    case idle
    /// Salue d'un bras, le corps en contrepoids.
    case wave
    /// Saut de joie, avec anticipation, apesanteur et deux rebonds.
    case celebrate
    /// Sursaut : détente verticale brutale, le regard part avant le corps.
    case surprise
    /// Deux hochements d'approbation.
    case nod
    /// Bascule lente : l'attente pendant une génération.
    case think
    /// Tombe du haut et rebondit. Une seule fois.
    case arrive
    /// Traverse en sautillant depuis la gauche, puis se pose. Une seule fois.
    /// C'est l'entrée en scène : elle a besoin d'un déplacement horizontal, que
    /// les autres actes n'utilisent pas.
    case hopIn
    /// Le TRANSIT entre deux écrans. Le corps s'étire dans le sens du trajet,
    /// les bras partent en arrière, et il pique légèrement du nez : c'est ce qui
    /// fait lire un déplacement plutôt qu'une réapparition ailleurs.
    case fly
}

enum MascotMouth: Equatable { case smile, neutral, surprised, happy }

enum MascotProp: Equatable { case none, glasses, crown, idea, sparkles, helmet, lock }

// MARK: - La vue

struct MascotView: View {
    var act: MascotAct = .idle
    var mouth: MascotMouth = .smile
    var prop: MascotProp = .none
    var color: Color = HZ.Colors.blue
    var size: CGFloat = 160
    /// Les clignements, indépendants de l'acte en cours.
    var blinks: Bool = true

    /// Déclencheur des cycles continus : respiration, accessoires qui pulsent.
    @State private var breathing = false

    /// Une unité du repère 600, en points.
    private var u: CGFloat { size / 600 }

    var body: some View {
        ZStack {
            // L'ombre vit HORS du personnage : elle reste au sol et pâlit quand
            // le corps s'élève. C'est ce décalage qui donne l'illusion de masse.
            MShadow()
                .fill(HZ.Colors.shadowSoft)
                .frame(width: size, height: size)
                .scaleEffect(breathing && act == .idle ? 0.96 : 1, anchor: .center)
                .animation(act == .idle
                           ? .easeInOut(duration: 4.3).repeatForever(autoreverses: true)
                           : .default,
                           value: breathing)

            character
        }
        .frame(width: size, height: size)
        .onAppear { breathing = true }
    }

    // MARK: Le personnage, acte par acte
    //
    // Le switch est ICI, dans un ViewBuilder, et surtout PAS dans le
    // constructeur de keyframes : KeyframesBuilder n'a pas de `buildEither`, il
    // refuse donc toute branche conditionnelle. ViewBuilder, lui, les gère.
    //
    // Effet secondaire heureux : chaque acte étant une vue distincte, changer
    // d'acte recrée l'animateur — le geste repart proprement de zéro au lieu
    // d'interpoler depuis la pose en cours.

    @ViewBuilder
    private var character: some View {
        switch act {
        case .still, .idle:
            // Le repos est porté par la respiration du corps et de l'ombre, sur
            // des durées premières entre elles pour que la boucle ne se lise
            // jamais. Pas de keyframes : rien à synchroniser.
            animator(false) {
                KeyframeTrack(\.lift) { CubicKeyframe(0, duration: 4.3) }
            }

        // ── COUCOU ────────────────────────────────────────────────────────
        // Le corps recule (anticipation), s'incline du côté OPPOSÉ au bras levé
        // — ce contrepoids est ce qui rend le geste crédible — le bras monte en
        // dépassant sa cible, agite deux fois, puis tout revient avec un léger
        // dépassement inverse.
        case .wave:
            animator(true) {
                KeyframeTrack(\.tilt) {
                    CubicKeyframe(3, duration: 0.21)
                    CubicKeyframe(-7, duration: 0.36)
                    CubicKeyframe(-8, duration: 0.73)
                    CubicKeyframe(-6, duration: 0.57)
                    CubicKeyframe(1.5, duration: 0.36)
                    CubicKeyframe(0, duration: 0.37)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(2, duration: 0.21)
                    CubicKeyframe(-6, duration: 0.36)
                    CubicKeyframe(-8, duration: 0.73)
                    CubicKeyframe(-4, duration: 0.57)
                    CubicKeyframe(0, duration: 0.73)
                }
                KeyframeTrack(\.armRight) {
                    // Amplitude tenue à 46° : au-delà, le bras se présente de
                    // profil et se lit comme un simple rectangle.
                    CubicKeyframe(8, duration: 0.21)
                    CubicKeyframe(-52, duration: 0.42)
                    CubicKeyframe(-42, duration: 0.21)
                    CubicKeyframe(-46, duration: 0.31)
                    CubicKeyframe(-30, duration: 0.31)
                    CubicKeyframe(-46, duration: 0.31)
                    CubicKeyframe(-34, duration: 0.31)
                    CubicKeyframe(4, duration: 0.31)
                    CubicKeyframe(0, duration: 0.21)
                }
                KeyframeTrack(\.armLeft) {
                    CubicKeyframe(-4, duration: 0.36)
                    CubicKeyframe(9, duration: 0.68)
                    CubicKeyframe(6, duration: 0.88)
                    CubicKeyframe(-2, duration: 0.47)
                    CubicKeyframe(0, duration: 0.21)
                }
            }

        // ── SAUT DE JOIE ──────────────────────────────────────────────────
        case .celebrate:
            animator(true) {
                KeyframeTrack(\.lift) {
                    CubicKeyframe(9, duration: 0.18)      // accroupi
                    SpringKeyframe(-96, duration: 0.39)   // envol
                    CubicKeyframe(-87, duration: 0.15)    // apesanteur
                    CubicKeyframe(0, duration: 0.33)      // impact
                    SpringKeyframe(-14, duration: 0.15)   // rebond 1
                    CubicKeyframe(0, duration: 0.15)
                    SpringKeyframe(-5, duration: 0.08)    // rebond 2
                    CubicKeyframe(0, duration: 0.07)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(0.90, duration: 0.18)
                    CubicKeyframe(1.10, duration: 0.27)
                    CubicKeyframe(1, duration: 0.27)
                    CubicKeyframe(0.86, duration: 0.33)
                    CubicKeyframe(1.04, duration: 0.18)
                    CubicKeyframe(1, duration: 0.27)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(1.09, duration: 0.18)
                    CubicKeyframe(0.92, duration: 0.27)
                    CubicKeyframe(1, duration: 0.27)
                    CubicKeyframe(1.12, duration: 0.33)
                    CubicKeyframe(0.97, duration: 0.18)
                    CubicKeyframe(1, duration: 0.27)
                }
                KeyframeTrack(\.armLeft) {
                    CubicKeyframe(14, duration: 0.18)
                    CubicKeyframe(-58, duration: 0.36)
                    CubicKeyframe(-18, duration: 0.51)
                    CubicKeyframe(6, duration: 0.24)
                    CubicKeyframe(0, duration: 0.21)
                }
                KeyframeTrack(\.armRight) {
                    CubicKeyframe(-14, duration: 0.18)
                    CubicKeyframe(58, duration: 0.36)
                    CubicKeyframe(18, duration: 0.51)
                    CubicKeyframe(-6, duration: 0.24)
                    CubicKeyframe(0, duration: 0.21)
                }
                KeyframeTrack(\.footSquash) {
                    CubicKeyframe(0.74, duration: 0.18)
                    CubicKeyframe(1.12, duration: 0.27)
                    CubicKeyframe(1, duration: 0.24)
                    CubicKeyframe(0.70, duration: 0.33)
                    CubicKeyframe(1, duration: 0.48)
                }
            }

        // ── SURSAUT ───────────────────────────────────────────────────────
        // Le visage monte PLUS que le corps : le regard part avant le reste.
        case .surprise:
            animator(true) {
                KeyframeTrack(\.lift) {
                    SpringKeyframe(-33, duration: 0.14)
                    CubicKeyframe(-6, duration: 0.22)
                    CubicKeyframe(-13, duration: 0.22)
                    CubicKeyframe(0, duration: 0.25)
                    CubicKeyframe(0, duration: 0.57)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(1.14, duration: 0.14)
                    CubicKeyframe(0.93, duration: 0.25)
                    CubicKeyframe(1.02, duration: 0.25)
                    CubicKeyframe(1, duration: 0.76)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(0.88, duration: 0.14)
                    CubicKeyframe(1.07, duration: 0.25)
                    CubicKeyframe(0.98, duration: 0.25)
                    CubicKeyframe(1, duration: 0.76)
                }
                KeyframeTrack(\.faceLift) {
                    CubicKeyframe(-10, duration: 0.14)
                    CubicKeyframe(0, duration: 0.34)
                    CubicKeyframe(0, duration: 0.92)
                }
                KeyframeTrack(\.armLeft) {
                    CubicKeyframe(-46, duration: 0.17)
                    CubicKeyframe(-12, duration: 0.31)
                    CubicKeyframe(0, duration: 0.36)
                    CubicKeyframe(0, duration: 0.56)
                }
                KeyframeTrack(\.armRight) {
                    CubicKeyframe(46, duration: 0.17)
                    CubicKeyframe(12, duration: 0.31)
                    CubicKeyframe(0, duration: 0.36)
                    CubicKeyframe(0, duration: 0.56)
                }
            }

        // ── APPROBATION ───────────────────────────────────────────────────
        case .nod:
            animator(true) {
                KeyframeTrack(\.lift) {
                    CubicKeyframe(9, duration: 0.25)
                    CubicKeyframe(-4, duration: 0.28)
                    CubicKeyframe(8, duration: 0.27)
                    CubicKeyframe(-1, duration: 0.25)
                    CubicKeyframe(0, duration: 0.20)
                }
                KeyframeTrack(\.tilt) {
                    CubicKeyframe(-1.5, duration: 0.25)
                    CubicKeyframe(0.8, duration: 0.28)
                    CubicKeyframe(-1, duration: 0.27)
                    CubicKeyframe(0, duration: 0.45)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(0.95, duration: 0.25)
                    CubicKeyframe(1.02, duration: 0.28)
                    CubicKeyframe(0.96, duration: 0.27)
                    CubicKeyframe(1, duration: 0.45)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(1.04, duration: 0.25)
                    CubicKeyframe(0.98, duration: 0.28)
                    CubicKeyframe(1.03, duration: 0.27)
                    CubicKeyframe(1, duration: 0.45)
                }
            }

        // ── HÉSITATION ────────────────────────────────────────────────────
        case .think:
            animator(true) {
                KeyframeTrack(\.tilt) {
                    CubicKeyframe(5, duration: 1.6)
                    CubicKeyframe(-5, duration: 1.6)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-4, duration: 1.6)
                    CubicKeyframe(0, duration: 1.6)
                }
                KeyframeTrack(\.armLeft) {
                    CubicKeyframe(-8, duration: 1.6)
                    CubicKeyframe(10, duration: 1.6)
                }
                KeyframeTrack(\.armRight) {
                    CubicKeyframe(10, duration: 1.6)
                    CubicKeyframe(-8, duration: 1.6)
                }
            }

        // ── ENTRÉE EN SCÈNE (une seule fois) ──────────────────────────────
        // Trois bonds depuis la gauche, d'amplitude décroissante, puis un
        // atterrissage écrasé et un dernier petit rebond. Le déplacement
        // horizontal est CONTINU pendant que les bonds se succèdent : c'est ce
        // décalage entre la trajectoire et le rythme qui fait « sautiller »
        // plutôt que « clignoter d'une position à l'autre ».
        case .hopIn:
            animator(false) {
                KeyframeTrack(\.driftX) {
                    CubicKeyframe(-430, duration: 0.01)
                    LinearKeyframe(-270, duration: 0.30)
                    LinearKeyframe(-140, duration: 0.28)
                    LinearKeyframe(-42, duration: 0.26)
                    SpringKeyframe(0, duration: 0.34, spring: .snappy)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.01)
                    CubicKeyframe(-104, duration: 0.15)   // bond 1
                    CubicKeyframe(0, duration: 0.15)
                    CubicKeyframe(-78, duration: 0.14)    // bond 2
                    CubicKeyframe(0, duration: 0.14)
                    CubicKeyframe(-52, duration: 0.13)    // bond 3
                    CubicKeyframe(0, duration: 0.13)
                    SpringKeyframe(-16, duration: 0.17)   // dernier rebond
                    CubicKeyframe(0, duration: 0.17)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(1, duration: 0.01)
                    CubicKeyframe(1.07, duration: 0.15)
                    CubicKeyframe(0.88, duration: 0.15)   // écrasé à l'appui
                    CubicKeyframe(1.05, duration: 0.14)
                    CubicKeyframe(0.90, duration: 0.14)
                    CubicKeyframe(1.03, duration: 0.13)
                    CubicKeyframe(0.92, duration: 0.13)
                    CubicKeyframe(1.02, duration: 0.17)
                    CubicKeyframe(1, duration: 0.17)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(1, duration: 0.01)
                    CubicKeyframe(0.95, duration: 0.15)
                    CubicKeyframe(1.12, duration: 0.15)
                    CubicKeyframe(0.96, duration: 0.14)
                    CubicKeyframe(1.10, duration: 0.14)
                    CubicKeyframe(0.97, duration: 0.13)
                    CubicKeyframe(1.08, duration: 0.13)
                    CubicKeyframe(0.99, duration: 0.17)
                    CubicKeyframe(1, duration: 0.17)
                }
                KeyframeTrack(\.tilt) {
                    // Il penche dans le sens de la marche, et se redresse en
                    // arrivant : sans cela, il a l'air de reculer.
                    CubicKeyframe(-7, duration: 0.01)
                    CubicKeyframe(-6, duration: 0.58)
                    CubicKeyframe(-3, duration: 0.40)
                    CubicKeyframe(2, duration: 0.20)
                    CubicKeyframe(0, duration: 0.20)
                }
                KeyframeTrack(\.footSquash) {
                    CubicKeyframe(1, duration: 0.16)
                    CubicKeyframe(0.72, duration: 0.14)
                    CubicKeyframe(1, duration: 0.14)
                    CubicKeyframe(0.76, duration: 0.13)
                    CubicKeyframe(1, duration: 0.13)
                    CubicKeyframe(0.80, duration: 0.13)
                    CubicKeyframe(1, duration: 0.30)
                }
                KeyframeTrack(\.armLeft) {
                    CubicKeyframe(-22, duration: 0.30)
                    CubicKeyframe(-8, duration: 0.30)
                    CubicKeyframe(-20, duration: 0.28)
                    CubicKeyframe(0, duration: 0.36)
                }
                KeyframeTrack(\.armRight) {
                    CubicKeyframe(20, duration: 0.30)
                    CubicKeyframe(6, duration: 0.30)
                    CubicKeyframe(18, duration: 0.28)
                    CubicKeyframe(0, duration: 0.36)
                }
            }

        // ── TRANSIT (une seule fois, pendant que le routeur le déplace) ───
        // La position est animée par le routeur ; ce qui est joué ici, c'est la
        // DÉFORMATION du vol. Étirement au décollage, corps tendu en vol, puis
        // écrasement à l'atterrissage : sans ces trois temps, un personnage qui
        // change de place se lit comme un personnage qui a été téléporté.
        case .fly:
            animator(false) {
                KeyframeTrack(\.squashY) {
                    LinearKeyframe(0.86, duration: 0.10)   // il se ramasse
                    LinearKeyframe(1.16, duration: 0.14)   // détente
                    LinearKeyframe(1.06, duration: 0.26)   // tendu en vol
                    LinearKeyframe(0.88, duration: 0.12)   // impact
                    LinearKeyframe(1.03, duration: 0.10)
                    LinearKeyframe(1, duration: 0.10)
                }
                KeyframeTrack(\.squashX) {
                    LinearKeyframe(1.12, duration: 0.10)
                    LinearKeyframe(0.90, duration: 0.14)
                    LinearKeyframe(0.96, duration: 0.26)
                    LinearKeyframe(1.14, duration: 0.12)
                    LinearKeyframe(0.98, duration: 0.10)
                    LinearKeyframe(1, duration: 0.10)
                }
                KeyframeTrack(\.tilt) {
                    LinearKeyframe(4, duration: 0.10)
                    LinearKeyframe(-9, duration: 0.16)     // pique du nez
                    LinearKeyframe(-7, duration: 0.24)
                    LinearKeyframe(3, duration: 0.16)
                    LinearKeyframe(0, duration: 0.16)
                }
                KeyframeTrack(\.armLeft) {
                    LinearKeyframe(18, duration: 0.12)     // bras en arrière
                    LinearKeyframe(26, duration: 0.28)
                    LinearKeyframe(-6, duration: 0.20)
                    LinearKeyframe(0, duration: 0.22)
                }
                KeyframeTrack(\.armRight) {
                    LinearKeyframe(-18, duration: 0.12)
                    LinearKeyframe(-26, duration: 0.28)
                    LinearKeyframe(6, duration: 0.20)
                    LinearKeyframe(0, duration: 0.22)
                }
                KeyframeTrack(\.footSquash) {
                    LinearKeyframe(0.70, duration: 0.24)   // pieds repliés
                    LinearKeyframe(0.70, duration: 0.26)
                    LinearKeyframe(1, duration: 0.32)
                }
            }

        // ── ARRIVÉE VERTICALE (une seule fois) ────────────────────────────
        case .arrive:
            animator(false) {
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-150, duration: 0.01)
                    SpringKeyframe(0, duration: 0.42, spring: .bouncy)
                    SpringKeyframe(-22, duration: 0.16)
                    CubicKeyframe(0, duration: 0.14)
                    SpringKeyframe(-6, duration: 0.08)
                    CubicKeyframe(0, duration: 0.07)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(1.08, duration: 0.30)
                    CubicKeyframe(0.85, duration: 0.14)
                    CubicKeyframe(1.04, duration: 0.17)
                    CubicKeyframe(1, duration: 0.27)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(0.94, duration: 0.30)
                    CubicKeyframe(1.14, duration: 0.14)
                    CubicKeyframe(0.97, duration: 0.17)
                    CubicKeyframe(1, duration: 0.27)
                }
                KeyframeTrack(\.footSquash) {
                    CubicKeyframe(1, duration: 0.30)
                    CubicKeyframe(0.68, duration: 0.14)
                    CubicKeyframe(1, duration: 0.44)
                }
            }
        }
    }

    /// Fabrique un animateur pour une partition. Le personnage est assemblé une
    /// seule fois — ici — pour que les partitions ne décrivent que le geste.
    private func animator<K>(
        _ repeats: Bool,
        @KeyframesBuilder<MascotPose> _ partition: @escaping () -> K
    ) -> some View where K: Keyframes, K.Value == MascotPose {
        KeyframeAnimator(initialValue: MascotPose(), repeating: repeats) { pose in
            posed(pose)
        } keyframes: { _ in
            partition()
        }
    }

    /// Le personnage complet dans une pose donnée.
    private func posed(_ pose: MascotPose) -> some View {
        ZStack {
            // Ordre de pile : bras DERRIÈRE le corps, pieds derrière aussi,
            // comme sur l'asset de référence.
            arms(pose)
            feet(pose)
            torso
            face(pose)
            propOverlay(pose)
        }
        .frame(width: size, height: size)
        // Le pivot des déformations est le SOL, pas le centre : un personnage
        // posé au sol qui s'écrase ne décolle pas.
        .scaleEffect(x: pose.squashX, y: pose.squashY, anchor: .bottom)
        .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
        .offset(x: pose.driftX * u, y: pose.lift * u)
    }

    // MARK: Corps

    private var torso: some View {
        ZStack {
            // Base crème, éclairée du HAUT-GAUCHE : c'est ce dégradé qui crée
            // le croissant plus foncé sur la droite du corps.
            MBody()
                .fill(
                    RadialGradient(colors: [Color(hex: 0xFFFDF7),
                                            HZ.Colors.mascotCream,
                                            Color(hex: 0xEADDD4)],
                                   center: UnitPoint(x: 0.38, y: 0.30),
                                   startRadius: 0,
                                   endRadius: 300 * u)
                )

            // Dôme coloré, découpé à la silhouette du corps : une seule source
            // de vérité pour le contour, donc aucun décalage possible entre les
            // deux couleurs pendant une déformation.
            MDome()
                .fill(LinearGradient(colors: [color, color, color.opacity(0.86)],
                                     startPoint: .top, endPoint: .bottom))
                .clipShape(MBody())

            // Les deux éclats de lumière. Le grand n'est pas une ellipse : son
            // bord haut-gauche est bombé, son bord bas-droit presque rectiligne.
            MGloss()
                .fill(.white)
                .opacity(0.26)
                .clipShape(MBody())
        }
        .frame(width: size, height: size)
        // La respiration : le corps s'amincit et s'allonge très légèrement.
        .scaleEffect(x: breathing && act == .idle ? 0.985 : 1,
                     y: breathing && act == .idle ? 1.018 : 1,
                     anchor: .bottom)
        .animation(act == .idle
                   ? .easeInOut(duration: 3.4).repeatForever(autoreverses: true)
                   : .default,
                   value: breathing)
    }

    // MARK: Bras

    private func arms(_ pose: MascotPose) -> some View {
        ZStack {
            MArm(side: .left)
                .fill(color)
                .frame(width: size, height: size)
                // Pivot à l'ÉPAULE, jamais au centre : au centre, le bras
                // tournerait comme une hélice.
                .rotationEffect(.degrees(pose.armLeft),
                                anchor: UnitPoint(x: 78 / 600, y: 292 / 600))
            MArm(side: .right)
                .fill(color)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(pose.armRight),
                                anchor: UnitPoint(x: 522 / 600, y: 292 / 600))
        }
    }

    // MARK: Pieds

    private func feet(_ pose: MascotPose) -> some View {
        MFeet()
            .fill(HZ.Colors.mascotCreamDeep)
            .frame(width: size, height: size)
            // Les pieds s'écrasent depuis leur SEMELLE (y = 557 dans le repère),
            // pas depuis le centre de la frame.
            .scaleEffect(y: pose.footSquash, anchor: UnitPoint(x: 0.5, y: 557 / 600))
    }

    // MARK: Visage

    private func face(_ pose: MascotPose) -> some View {
        ZStack {
            MBlush()
                .fill(HZ.Colors.mascotCoral)
                .opacity(0.92)
                .frame(width: size, height: size)

            // Le clignement a son PROPRE animateur : il doit pouvoir tomber au
            // milieu d'un saut, sur un rythme sans rapport avec le geste.
            BlinkingEyes(size: size, blinks: blinks && act != .still)

            mouthLayer
        }
        .frame(width: size, height: size)
        // Le visage suit le corps, amorti : sinon il « nage » dessus.
        .offset(y: pose.faceLift * u)
    }

    @ViewBuilder
    private var mouthLayer: some View {
        switch mouth {
        case .smile:
            ZStack {
                MMouthSmile()
                    .fill(HZ.Colors.mascotInk)
                    .frame(width: size, height: size)
                // Langue en CALISSON : losange aux pointes arrondies, incliné
                // de -11°, calé en bas à droite de la bouche.
                MTongue()
                    .fill(HZ.Colors.mascotCoral)
                    .frame(width: size, height: size)
            }
        case .neutral:
            MMouthLine()
                .stroke(HZ.Colors.mascotInk,
                        style: StrokeStyle(lineWidth: 10 * u, lineCap: .round))
                .frame(width: size, height: size)
        case .surprised:
            MMouthO()
                .fill(HZ.Colors.mascotInk)
                .frame(width: size, height: size)
        case .happy:
            ZStack {
                MMouthSmile()
                    .fill(HZ.Colors.mascotInk)
                    .frame(width: size, height: size)
                MTongue()
                    .fill(HZ.Colors.mascotCoral)
                    .frame(width: size, height: size)
                MMouthSmile()
                    .stroke(HZ.Colors.mascotInk.opacity(0.35),
                            style: StrokeStyle(lineWidth: 4 * u))
                    .frame(width: size, height: size)
            }
        }
    }

    // MARK: Accessoires

    @ViewBuilder
    private func propOverlay(_ pose: MascotPose) -> some View {
        switch prop {
        case .none:
            EmptyView()

        case .glasses:
            MGlasses()
                .stroke(HZ.Colors.mascotInk.opacity(0.85),
                        style: StrokeStyle(lineWidth: 7 * u))
                .frame(width: size, height: size)
                .offset(y: pose.faceLift * u)

        case .crown:
            // Posée PLUS HAUT que le sommet du dôme : à -0,34 elle mordait sur
            // le crâne et se lisait comme une tache, pas comme une couronne.
            HZCrownMark(size: size * 0.30)
                .rotationEffect(.degrees(22))
                .offset(x: size * 0.20, y: -size * 0.44)

        case .idea:
            MIdea()
                .fill(HZ.Colors.gold)
                .frame(width: size, height: size)
                .overlay {
                    MIdeaHalo()
                        .fill(HZ.Colors.gold.opacity(0.32))
                        .frame(width: size, height: size)
                        .scaleEffect(breathing ? 1.12 : 0.92)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                                   value: breathing)
                }

        case .sparkles:
            // Quatre étincelles à quatre distances, qui respirent en décalé.
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    MSpark(index: i)
                        .fill(HZ.Colors.gold)
                        .frame(width: size, height: size)
                        .opacity(breathing ? 1 : 0.35)
                        .animation(.easeInOut(duration: 0.8 + Double(i) * 0.17)
                                    .repeatForever(autoreverses: true),
                                   value: breathing)
                }
            }

        case .helmet:
            MHelmet()
                .fill(HZ.Colors.mOrange)
                .frame(width: size, height: size)
                .offset(y: pose.faceLift * u)

        case .lock:
            HZLockMark(size: size * 0.26)
                .offset(x: size * 0.30, y: size * 0.06)
        }
    }
}

// MARK: - Les yeux et leur battement propre

/// Les deux yeux et leurs paupières.
///
/// La paupière n'est PAS un `scaleEffect` sur un cercle : elle est un disque de
/// la couleur du dôme qui descend depuis au-dessus de l'œil. Au repos il est
/// remonté hors du globe, donc invisible sur le dôme de même teinte ; fermé, il
/// recouvre exactement la pupille. Un simple déplacement, donc rien à ancrer.
///
/// Le RYTHME est volontairement irrégulier — un battement isolé, puis deux
/// rapprochés, sur environ 7 secondes. Un clignement métronomique se remarque et
/// donne un air de machine ; celui-ci passe inaperçu, ce qui est le but.
private struct BlinkingEyes: View {
    let size: CGFloat
    let blinks: Bool

    var body: some View {
        KeyframeAnimator(initialValue: CGFloat(1), repeating: blinks) { openness in
            MEyes(openness: openness)
                .fill(HZ.Colors.mascotInk)
                .frame(width: size, height: size)
        } keyframes: { _ in
            // UNIQUEMENT des keyframes linéaires. Une spline cubique calcule ses
            // tangentes d'après les segments voisins : avec un battement de
            // 0,07 s coincé entre deux paliers de près de 3 s, elle produit des
            // dépassements massifs. Ici la valeur ne peut pas sortir des bornes
            // qu'on lui donne.
            KeyframeTrack(\.self) {
                LinearKeyframe(1, duration: 2.80)     // yeux ouverts, longtemps
                LinearKeyframe(0.06, duration: 0.07)  // fermeture nette
                LinearKeyframe(1, duration: 0.11)     // ouverture un peu plus lente
                LinearKeyframe(1, duration: 0.85)
                LinearKeyframe(0.06, duration: 0.07)  // salve : second battement
                LinearKeyframe(1, duration: 0.11)
                LinearKeyframe(1, duration: 2.90)
            }
        }
    }
}

// MARK: - La pose animée

/// Toutes les valeurs qu'une animation peut faire varier. Un seul type animé,
/// donc un seul KeyframeAnimator : les pistes restent synchronisées entre elles,
/// ce qui est indispensable pour composer anticipation, écrasement et retard.
struct MascotPose {
    /// Élévation verticale, en unités du repère 600.
    var lift: CGFloat = 0
    /// Inclinaison du corps entier, en degrés.
    var tilt: Double = 0
    /// Écrasement / étirement.
    var squashX: CGFloat = 1
    var squashY: CGFloat = 1
    /// Rotation des bras, en degrés (négatif = vers le haut).
    var armLeft: Double = 0
    var armRight: Double = 0
    /// Écrasement des pieds.
    var footSquash: CGFloat = 1
    /// Décalage du visage, amorti par rapport au corps.
    var faceLift: CGFloat = 0
    /// Déplacement horizontal, en unités du repère 600. Seule l'entrée en
    /// scène l'utilise — un personnage qui dérive latéralement sans raison
    /// donne l'impression de flotter.
    var driftX: CGFloat = 0
}

// =============================================================================
// LES FORMES — transcrites du SVG de référence, repère 600 × 600
// =============================================================================
//
// Chacune reçoit la frame ENTIÈRE et se place elle-même. C'est ce qui garantit
// qu'elles restent solidaires : elles partagent toutes le même `u`.

/// Convertit un point du repère 600 en point de la frame reçue.
private func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    let u = r.width / 600
    return CGPoint(x: x * u, y: y * u)
}

enum MSide { case left, right }

/// Silhouette du corps. Le bas est plus « plein » qu'une ellipse — la section
/// reste large jusqu'à y = 528 — d'où un tracé et non un simple ovale.
struct MBody: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        path.move(to: p(300, 3))
        path.addCurve(to: p(562, 266), control1: p(440, 3), control2: p(562, 128))
        path.addCurve(to: p(340, 528), control1: p(562, 402), control2: p(470, 500))
        path.addLine(to: p(260, 528))
        path.addCurve(to: p(38, 266), control1: p(130, 500), control2: p(38, 402))
        path.addCurve(to: p(300, 3), control1: p(38, 128), control2: p(160, 3))
        path.closeSubpath()
        return path
    }
}

/// Le dôme coloré : une courbe qui plonge au centre, comme un béret posé de
/// travers. Découpé ensuite à la silhouette du corps.
struct MDome: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        path.move(to: p(0, 265))
        path.addQuadCurve(to: p(600, 265), control: p(300, 400))
        path.addLine(to: p(600, -10))
        path.addLine(to: p(0, -10))
        path.closeSubpath()
        return path
    }
}

/// Les deux éclats de lumière. Le grand est ASYMÉTRIQUE : bord haut-gauche
/// bombé, bord bas-droit presque rectiligne. Il est incliné de -38°.
struct MGloss: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var big = Path()
        // Tracé dans un repère local centré, puis pivoté et posé à (205, 88).
        big.move(to: CGPoint(x: -52 * u, y: 0))
        big.addCurve(to: CGPoint(x: 5 * u, y: -22 * u),
                     control1: CGPoint(x: -48 * u, y: -19 * u),
                     control2: CGPoint(x: -21 * u, y: -24 * u))
        big.addCurve(to: CGPoint(x: 52 * u, y: -2 * u),
                     control1: CGPoint(x: 29 * u, y: -20 * u),
                     control2: CGPoint(x: 50 * u, y: -10 * u))
        big.addCurve(to: CGPoint(x: 10 * u, y: 8 * u),
                     control1: CGPoint(x: 52 * u, y: 4 * u),
                     control2: CGPoint(x: 36 * u, y: 8 * u))
        big.addCurve(to: CGPoint(x: -52 * u, y: 0),
                     control1: CGPoint(x: -16 * u, y: 8 * u),
                     control2: CGPoint(x: -46 * u, y: 5 * u))
        big.closeSubpath()

        var path = Path()
        path.addPath(big.applying(
            CGAffineTransform(rotationAngle: -38 * .pi / 180)
                .concatenating(CGAffineTransform(translationX: 205 * u, y: 88 * u))))
        // Petit éclat, circulaire.
        path.addEllipse(in: CGRect(origin: p(140, 128),
                                   size: CGSize(width: 24 * u, height: 24 * u)))
        return path
    }
}

/// Un bras : une virgule épaisse aux extrémités arrondies, qui part de l'épaule
/// et redescend le long du corps. Il n'y en a jamais qu'un par instance, pour
/// que chacun puisse pivoter autour de SON épaule.
struct MArm: Shape {
    var side: MSide

    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        switch side {
        case .left:
            path.move(to: p(78, 292))
            path.addCurve(to: p(28, 312), control1: p(62, 284), control2: p(42, 292))
            path.addCurve(to: p(10, 370), control1: p(12, 334), control2: p(6, 356))
            path.addCurve(to: p(48, 376), control1: p(15, 386), control2: p(34, 390))
            path.addCurve(to: p(82, 312), control1: p(64, 360), control2: p(76, 330))
            path.addCurve(to: p(78, 292), control1: p(86, 302), control2: p(84, 295))
        case .right:
            path.move(to: p(522, 292))
            path.addCurve(to: p(572, 312), control1: p(538, 284), control2: p(558, 292))
            path.addCurve(to: p(590, 370), control1: p(588, 334), control2: p(594, 356))
            path.addCurve(to: p(552, 376), control1: p(585, 386), control2: p(566, 390))
            path.addCurve(to: p(518, 312), control1: p(536, 360), control2: p(524, 330))
            path.addCurve(to: p(522, 292), control1: p(514, 302), control2: p(516, 295))
        }
        path.closeSubpath()
        return path
    }
}

/// Les DEUX pieds — pas trois : la forme molle sous le corps est une ombre,
/// jamais une jambe. Chacun est un rectangle dont la semelle est une
/// demi-ellipse. Les deux dans une seule Shape, comme les yeux et les joues :
/// c'est ce qui garantit qu'ils ne peuvent pas se désolidariser.
struct MFeet: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        for x0 in [CGFloat(222), CGFloat(324)] {
            path.move(to: p(x0, 494))
            path.addLine(to: p(x0 + 54, 494))
            path.addLine(to: p(x0 + 54, 536))
            // Demi-ellipse de 54 de large et 21 de creux : les points de
            // contrôle à y = 564 font passer la courbe exactement par y = 557.
            path.addCurve(to: p(x0, 536),
                          control1: p(x0 + 54, 564),
                          control2: p(x0, 564))
            path.closeSubpath()
        }
        return path
    }
}

/// L'ombre au sol, aplatie et large.
struct MShadow: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        var path = Path()
        path.addEllipse(in: CGRect(x: (300 - 152) * u, y: (562 - 15) * u,
                                   width: 304 * u, height: 30 * u))
        return path
    }
}

/// Les deux joues, à l'extérieur des yeux.
struct MBlush: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        var path = Path()
        for cx in [CGFloat(181), CGFloat(419)] {
            path.addEllipse(in: CGRect(x: (cx - 24) * u, y: (236 - 12) * u,
                                       width: 48 * u, height: 24 * u))
        }
        return path
    }
}

/// Les deux pupilles, Ø 37 dans le repère, aux abscisses 212 et 388.
///
/// Le clignement se fait en APLATISSANT le globe, pas en faisant descendre une
/// paupière par-dessus. Ce choix n'est pas esthétique, il est défensif.
///
/// La version précédente posait un disque de la couleur du dôme au-dessus de
/// l'œil et le faisait redescendre. Sa piste d'animation mélangeait
/// CubicKeyframe et LinearKeyframe sur des durées très inégales — 0,07 s contre
/// 2,8 s — et la spline cubique calculait aux jonctions des tangentes énormes.
/// La valeur sortait largement de [0, 1], et les deux disques partaient se
/// promener au-dessus de la tête, hors du corps, à près de 300 unités de leur
/// place. Un aplatissement ne peut RIEN faire sortir : la forme reste toujours
/// contenue dans l'œil, quoi que fasse l'animation.
struct MEyes: Shape {
    /// 1 = grand ouvert, 0 = fermé.
    var openness: CGFloat = 1

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        // Garde-fou : même si une animation dérape, un œil reste un œil.
        let o = min(max(openness, 0.055), 1)
        let ry = 18.5 * o
        var path = Path()
        for cx in [CGFloat(212), CGFloat(388)] {
            path.addEllipse(in: CGRect(x: (cx - 18.5) * u,
                                       y: (198 - ry) * u,
                                       width: 37 * u,
                                       height: 2 * ry * u))
        }
        return path
    }
}

/// La bouche souriante : un arc supérieur presque plat et un menton arrondi.
struct MMouthSmile: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        path.move(to: p(258, 220))
        path.addCurve(to: p(341, 220), control1: p(258, 220), control2: p(300, 213))
        path.addCurve(to: p(300, 272), control1: p(341, 254), control2: p(323, 272))
        path.addCurve(to: p(258, 220), control1: p(277, 272), control2: p(258, 254))
        path.closeSubpath()
        return path
    }
}

/// La langue : un calisson — losange aux pointes arrondies — incliné de -11° et
/// calé en bas à droite de la bouche.
struct MTongue: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        var local = Path()
        local.move(to: CGPoint(x: -22.5 * u, y: 0))
        local.addCurve(to: CGPoint(x: 0, y: -10 * u),
                       control1: CGPoint(x: -19 * u, y: -8.5 * u),
                       control2: CGPoint(x: -9 * u, y: -10.5 * u))
        local.addCurve(to: CGPoint(x: 22.5 * u, y: 0),
                       control1: CGPoint(x: 11 * u, y: -9.5 * u),
                       control2: CGPoint(x: 20 * u, y: -5 * u))
        local.addCurve(to: CGPoint(x: 0, y: 10 * u),
                       control1: CGPoint(x: 20 * u, y: 5 * u),
                       control2: CGPoint(x: 11 * u, y: 9.5 * u))
        local.addCurve(to: CGPoint(x: -22.5 * u, y: 0),
                       control1: CGPoint(x: -9 * u, y: 10.5 * u),
                       control2: CGPoint(x: -19 * u, y: 8.5 * u))
        local.closeSubpath()

        var path = Path()
        path.addPath(local.applying(
            CGAffineTransform(rotationAngle: -11 * .pi / 180)
                .concatenating(CGAffineTransform(translationX: 303 * u, y: 255 * u))))
        return path
    }
}

/// La bouche neutre : un simple arc, à tracer au stroke.
struct MMouthLine: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        path.move(to: p(266, 232))
        path.addCurve(to: p(334, 232), control1: p(282, 250), control2: p(318, 250))
        return path
    }
}

/// La bouche surprise : un ovale vertical.
struct MMouthO: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        var path = Path()
        path.addEllipse(in: CGRect(x: (300 - 22) * u, y: (242 - 27) * u,
                                   width: 44 * u, height: 54 * u))
        return path
    }
}

/// Les lunettes : deux cercles posés sur les yeux et leur pont.
struct MGlasses: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        for cx in [CGFloat(212), CGFloat(388)] {
            path.addEllipse(in: CGRect(x: (cx - 33) * u, y: (198 - 33) * u,
                                       width: 66 * u, height: 66 * u))
        }
        path.move(to: p(245, 198))
        path.addLine(to: p(355, 198))
        return path
    }
}

/// L'ampoule de l'idée, au-dessus de la tête.
struct MIdea: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        var path = Path()
        path.addEllipse(in: CGRect(x: (300 - 21) * u, y: (-58 - 21) * u,
                                   width: 42 * u, height: 42 * u))
        path.addRoundedRect(in: CGRect(x: (300 - 10) * u, y: (-34) * u,
                                       width: 20 * u, height: 10 * u),
                            cornerSize: CGSize(width: 3 * u, height: 3 * u))
        return path
    }
}

/// Le halo de l'ampoule, qui pulse.
struct MIdeaHalo: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        var path = Path()
        path.addEllipse(in: CGRect(x: (300 - 37) * u, y: (-58 - 37) * u,
                                   width: 74 * u, height: 74 * u))
        return path
    }
}

/// Une étincelle : un quadrilatère aux côtés concaves. Quatre positions fixes,
/// pour qu'elles n'aient jamais l'air posées au hasard.
struct MSpark: Shape {
    var index: Int

    private static let layout: [(x: CGFloat, y: CGFloat, s: CGFloat)] =
        [(84, 108, 46), (516, 148, 34), (128, 402, 30), (498, 386, 40)]

    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        let l = Self.layout[min(index, Self.layout.count - 1)]
        let h = l.s / 2
        let cx = l.x * u, cy = l.y * u, s = h * u
        let k = s * 0.22   // creux des côtés
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - s))
        path.addQuadCurve(to: CGPoint(x: cx + s, y: cy),
                          control: CGPoint(x: cx + k, y: cy - k))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + s),
                          control: CGPoint(x: cx + k, y: cy + k))
        path.addQuadCurve(to: CGPoint(x: cx - s, y: cy),
                          control: CGPoint(x: cx - k, y: cy + k))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - s),
                          control: CGPoint(x: cx - k, y: cy - k))
        path.closeSubpath()
        return path
    }
}

/// Le casque de chantier, posé sur le dôme.
struct MHelmet: Shape {
    func path(in r: CGRect) -> Path {
        let u = r.width / 600
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(r, x, y) }
        var path = Path()
        path.move(to: p(150, 110))
        path.addCurve(to: p(450, 110), control1: p(170, -10), control2: p(430, -10))
        path.closeSubpath()
        path.addRoundedRect(in: CGRect(x: 118 * u, y: 100 * u,
                                       width: 364 * u, height: 30 * u),
                            cornerSize: CGSize(width: 15 * u, height: 15 * u))
        return path
    }
}
