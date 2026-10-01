import SwiftUI
import Combine

// =============================================================================
// ONBOARDING V2 — LA BOÎTE À OUTILS
// =============================================================================
//
// Les briques partagées par les seize temps de l'onboarding. Elles portent la
// grammaire visuelle décidée dans le script :
//
//   · TapTap ne parle qu'en BULLE, jamais en légende.
//   · Un écran = une action. Un seul bouton plein par écran.
//   · Le double tap est notre signature : il sert TROIS fois, et il a une
//     texture (deux vibrations espacées), pas seulement un effet.
//   · La progression n'apparaît qu'à partir de l'acte III — montrer une jauge à
//     quelqu'un qu'on veut séduire, c'est lui annoncer un formulaire.
// =============================================================================

// MARK: - La parole de TapTap

/// La bulle de dialogue. Le texte s'écrit caractère par caractère : c'est ce qui
/// donne l'impression que quelqu'un parle, plutôt que d'afficher une légende.
///
/// La vitesse (28 ms/caractère) a été choisie pour être lisible sans faire
/// attendre : une réplique de 60 signes prend 1,7 s. Un tap sur la bulle
/// termine l'écriture immédiatement — on ne retient jamais personne.
struct TapTapBubble: View {
    let text: String
    var accent: Color = HZ.Colors.blue
    /// D'où sort la pointe, et où elle vise.
    var tail: Tail = .bottomCenter
    var typing: Bool = true
    /// Vitesse d'écriture, en secondes par caractère.
    var speed: Double = 0.026

    enum Tail: Equatable {
        case none
        /// Pointe en bas, centrée — la bulle est AU-DESSUS de TapTap.
        case bottomCenter
        /// Pointe en haut, centrée : pour une bulle qui parle vers le haut.
        case topCenter
        /// Pointe en bas, à `inset` POINTS du bord gauche de la bulle.
        ///
        /// En points et non en fraction : une fraction se déplace avec la
        /// largeur de la bulle, donc la pointe glissait dès que le texte
        /// changeait de longueur et finissait par viser à côté de la tête.
        case bottomAt(CGFloat)

        var pointsDown: Bool {
            switch self {
            case .bottomCenter, .bottomAt: return true
            default: return false
            }
        }

        var pointsUp: Bool { self == .topCenter }
    }

    @State private var shown = 0
    @State private var done = false
    private var tick: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: speed, on: .main, in: .common).autoconnect()
    }

    var body: some View {
        composed
            .font(HZ.Fonts.fig(17, .medium))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                OnbBubbleShape(tail: tail)
                    .fill(.white)
                    .shadow(color: HZ.Colors.ink.opacity(0.08), radius: 16, y: 6)
            )
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .onReceive(tick) { _ in
                guard typing, !done else { return }
                if shown < text.count { shown += 1 } else { done = true }
            }
            .onAppear { if !typing { finish() } }
    }

    /// Le texte COMPLET est toujours présent — la partie non encore écrite est
    /// simplement transparente.
    ///
    /// C'est ce qui règle un défaut très visible de la version précédente : en
    /// tronquant la chaîne, le dernier mot d'une ligne grandissait caractère par
    /// caractère jusqu'à ne plus tenir, puis sautait d'un coup à la ligne
    /// suivante. Trois lignes, deux sauts, et l'effet se lisait comme un bug.
    /// En concaténant deux `Text`, la mise en page est calculée une fois pour
    /// toutes sur le texte entier : plus rien ne peut se recomposer.
    private var composed: Text {
        let n = done ? text.count : min(shown, text.count)
        let cut = text.index(text.startIndex, offsetBy: n)
        return Text(String(text[text.startIndex..<cut]))
                .foregroundColor(HZ.Colors.ink)
             + Text(String(text[cut...]))
                .foregroundColor(.clear)
    }

    private func finish() {
        shown = text.count
        done = true
    }
}

/// La forme de la bulle : un rectangle arrondi dont la pointe fait partie du
/// MÊME tracé.
///
/// La version précédente ajoutait la pointe comme un sous-chemin séparé. Les
/// deux formes se chevauchaient de deux points seulement, et l'anticrénelage
/// des deux bords superposés dessinait une couture nette — un trait en travers
/// de la bulle, exactement là où la pointe la rejoint. Un seul sous-chemin
/// fermé rend cette couture impossible.
struct OnbBubbleShape: Shape {
    var tail: TapTapBubble.Tail
    /// Rayon des coins.
    var radius: CGFloat = 22
    /// Profondeur de la pointe.
    var depth: CGFloat = 14
    /// Demi-largeur de la base de la pointe.
    var base: CGFloat = 13

    func path(in r: CGRect) -> Path {
        // Facteur d'approximation d'un quart de cercle par une Bézier cubique.
        let k = radius * 0.4477
        let x0 = r.minX, x1 = r.maxX, y0 = r.minY, y1 = r.maxY
        let tx: CGFloat
        switch tail {
        case .bottomAt(let inset): tx = x0 + inset
        default:                   tx = (x0 + x1) / 2
        }
        // La pointe ne doit jamais mordre sur un coin arrondi.
        let txc = min(max(tx, x0 + radius + base + 2), x1 - radius - base - 2)

        var p = Path()
        p.move(to: CGPoint(x: x0 + radius, y: y0))

        // ── bord haut, avec pointe éventuelle ────────────────────────────
        if tail.pointsUp {
            p.addLine(to: CGPoint(x: txc - base, y: y0))
            p.addQuadCurve(to: CGPoint(x: txc, y: y0 - depth),
                           control: CGPoint(x: txc - base * 0.35, y: y0 - depth * 0.72))
            p.addQuadCurve(to: CGPoint(x: txc + base, y: y0),
                           control: CGPoint(x: txc + base * 0.5, y: y0 - depth * 0.28))
        }
        p.addLine(to: CGPoint(x: x1 - radius, y: y0))
        p.addCurve(to: CGPoint(x: x1, y: y0 + radius),
                   control1: CGPoint(x: x1 - k, y: y0),
                   control2: CGPoint(x: x1, y: y0 + k))

        p.addLine(to: CGPoint(x: x1, y: y1 - radius))
        p.addCurve(to: CGPoint(x: x1 - radius, y: y1),
                   control1: CGPoint(x: x1, y: y1 - k),
                   control2: CGPoint(x: x1 - k, y: y1))

        // ── bord bas, avec pointe éventuelle ────────────────────────────
        if tail.pointsDown {
            p.addLine(to: CGPoint(x: txc + base, y: y1))
            p.addQuadCurve(to: CGPoint(x: txc, y: y1 + depth),
                           control: CGPoint(x: txc + base * 0.35, y: y1 + depth * 0.72))
            p.addQuadCurve(to: CGPoint(x: txc - base, y: y1),
                           control: CGPoint(x: txc - base * 0.5, y: y1 + depth * 0.28))
        }
        p.addLine(to: CGPoint(x: x0 + radius, y: y1))
        p.addCurve(to: CGPoint(x: x0, y: y1 - radius),
                   control1: CGPoint(x: x0 + k, y: y1),
                   control2: CGPoint(x: x0, y: y1 - k))

        p.addLine(to: CGPoint(x: x0, y: y0 + radius))
        p.addCurve(to: CGPoint(x: x0 + radius, y: y0),
                   control1: CGPoint(x: x0, y: y0 + k),
                   control2: CGPoint(x: x0 + k, y: y0))

        p.closeSubpath()
        return p
    }
}

/// TapTap qui commente : lui en bas à gauche, sa bulle AU-DESSUS, la pointe pile
/// sur sa tête.
///
/// La parole vient d'au-dessus et la pointe vise le visage : c'est la convention
/// de tous les personnages qui parlent bien. Une bulle posée À CÔTÉ, avec une
/// pointe qui part dans le vide, ne dit pas qui parle.
///
/// L'astuce qui rend l'alignement exact : la pointe est placée à
/// `mascotSize / 2` points du bord, soit l'axe de la mascotte posée juste en
/// dessous. Aucune mesure de la bulle n'est nécessaire, donc rien ne bouge quand
/// le texte change de longueur.
///
/// IMPORTANT — le slot est publié MÊME quand `visible` est faux. Le routeur
/// ignore les scènes nulles (sans quoi TapTap clignoterait à chaque transition),
/// donc un écran qui ne publie rien le laisse à la position de l'écran
/// PRÉCÉDENT. Publier explicitement une scène masquée est le seul moyen de le
/// faire disparaître d'un écran.
struct TapTapAside: View {
    let text: String
    /// Faux tant qu'il n'a rien à dire : il s'efface pendant que l'utilisateur
    /// agit, et revient pour commenter ce qu'il vient de réussir.
    var visible: Bool = true
    var act: MascotAct = .idle
    var mouth: MascotMouth = .neutral
    var prop: MascotProp = .none
    /// Sur fond coloré, TapTap passe en blanc.
    var white: Bool = false
    /// Couleur du curseur et des accents de la bulle.
    var accent: Color = HZ.Colors.blue
    var mascotSize: CGFloat = MascotPlace.asideSize
    var typing: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visible {
                TapTapBubble(text: text,
                             accent: accent,
                             tail: .bottomAt(mascotSize / 2),
                             typing: typing)
                    // La pointe descend de 14 pt sous la bulle : on lui laisse
                    // exactement cette place avant la tête.
                    .padding(.bottom, 15)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
            }

            MascotSlot(size: mascotSize,
                       act: act,
                       mouth: mouth,
                       prop: prop,
                       white: white,
                       hidden: !visible)
        }
    }
}

// MARK: - Le texte qui s'écrit (hors bulle)

/// Pour les grands titres qu'on veut voir se composer. Même vitesse que la
/// bulle, pour que le rythme de l'onboarding soit d'un seul tenant.
struct OnbTypewriter: View {
    let text: String
    var font: Font = HZ.Fonts.fig(30, .bold)
    var color: Color = HZ.Colors.ink
    var speed: Double = 0.028
    var startDelay: Double = 0

    @State private var shown = 0

    var body: some View {
        composed
            .font(font)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task {
                try? await Task.sleep(for: .seconds(startDelay))
                while shown < text.count {
                    try? await Task.sleep(for: .seconds(speed))
                    shown += 1
                }
            }
    }

    /// Le texte COMPLET est toujours présent : la partie non encore écrite est
    /// seulement transparente.
    ///
    /// C'est ce qui corrige un défaut très visible : en tronquant la chaîne, le
    /// dernier mot d'une ligne s'écrivait lettre par lettre en haut, dépassait,
    /// puis se téléportait d'un coup à la ligne suivante. En concaténant deux
    /// `Text`, la mise en page est calculée une fois pour toutes sur le texte
    /// entier : chaque lettre apparaît directement à sa place définitive.
    private var composed: Text {
        let n = min(shown, text.count)
        let cut = text.index(text.startIndex, offsetBy: n)
        return Text(String(text[text.startIndex..<cut]))
                .foregroundColor(color)
             + Text(String(text[cut...]))
                .foregroundColor(.clear)
    }
}

// MARK: - La scène de TapTap — la continuité entre les écrans

/// Où TapTap se trouve, et ce qu'il y fait.
///
/// C'EST LA PIÈCE CENTRALE DE L'ONBOARDING, et elle mérite d'être comprise
/// avant d'y toucher.
///
/// TapTap n'appartient à AUCUN écran. Il vit dans le routeur, en une seule
/// instance, au-dessus du contenu. Chaque écran se contente de DÉCLARER où il
/// le veut et ce qu'il doit jouer ; le routeur l'y emmène. Quand on change
/// d'écran, l'ancre change et TapTap VOLE de l'ancienne position à la nouvelle.
///
/// Sans ça, chaque écran instanciait son propre personnage : il disparaissait et
/// réapparaissait à chaque transition, et seize écrans se lisaient comme seize
/// diapositives sans lien. Avec ça, l'onboarding devient un plan-séquence et
/// TapTap devient quelqu'un qui accompagne.
///
/// Les écrans réservent la place qu'il occupera avec un `Color.clear` de la
/// bonne hauteur — c'est le prix à payer pour qu'il ne soit pas dans leur
/// hiérarchie de vues.
struct MascotStage: Equatable {
    /// Centre de TapTap, en POINTS dans l'espace de coordonnées de l'onboarding.
    ///
    /// En points mesurés et non en fraction devinée : c'est l'écran qui réserve
    /// la place dans son propre layout, puis publie le centre de cette place. La
    /// position de TapTap découle donc toujours de la mise en page réelle, même
    /// quand elle change avec la taille de l'appareil ou la longueur d'un texte.
    var center: CGPoint = .zero
    var size: CGFloat = 180
    var act: MascotAct = .idle
    var mouth: MascotMouth = .smile
    var prop: MascotProp = .none
    /// Sur les fonds colorés, TapTap passe en blanc. À n'utiliser que quand il
    /// commente par-dessus une scène déjà colorée : en blanc plein, il perd son
    /// dôme et se lit comme une silhouette.
    var white: Bool = false
    /// Les rares écrans où il s'efface complètement.
    var hidden: Bool = false
}

// MARK: - La grammaire de présence de TapTap
//
// UNE SEULE RÈGLE, et elle porte tout le récit :
//
//   TapTap accompagne pendant qu'on EXPLIQUE, il s'efface pendant qu'on AGIT,
//   et il revient pour COMMENTER ce qu'on vient de réussir.
//
// Concrètement : grand et central sur l'accueil, puis petit et posé toujours au
// MÊME endroit et à la MÊME taille pendant les trois écrans d'exposition — s'il
// change de gabarit d'un écran à l'autre, on ne lit plus un personnage qui
// suit, mais une illustration qu'on redimensionne. Absent des deux écrans où
// l'utilisateur essaie lui-même, pour ne pas lui voler la scène. Et de retour,
// en blanc, à l'instant où il a quelque chose à dire sur le résultat.

enum MascotPlace {
    /// L'accueil : grand, au centre.
    static let heroSize: CGFloat = 208
    /// Les écrans d'exposition : petit, en bas à gauche. Une seule valeur pour
    /// tous, c'est ce qui fait la continuité.
    static let asideSize: CGFloat = 82
    /// Quand il commente un résultat, par-dessus un fond coloré.
    static let commentSize: CGFloat = 80
}

/// L'espace de coordonnées commun au routeur et aux écrans.
let onbSpace = "onboardingStage"

/// La place que l'écran réserve à TapTap.
///
/// Elle occupe la mise en page comme le ferait le personnage, publie son centre
/// au routeur — qui l'y dessine — et porte la zone tactile. Le dessin appartient
/// au routeur, l'interaction à l'écran : chacun garde ce qu'il sait faire.
struct MascotSlot: View {
    var size: CGFloat = 180
    var act: MascotAct = .idle
    var mouth: MascotMouth = .smile
    var prop: MascotProp = .none
    var white: Bool = false
    var hidden: Bool = false
    /// Un simple toucher. Nil = TapTap n'est pas interactif sur cet écran.
    var onTap: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let f = geo.frame(in: .named(onbSpace))
            Color.clear
                .preference(key: MascotStageKey.self,
                            value: MascotStage(center: CGPoint(x: f.midX, y: f.midY),
                                               size: size,
                                               act: act,
                                               mouth: mouth,
                                               prop: prop,
                                               white: white,
                                               hidden: hidden))
                .contentShape(Circle())
                .onTapGesture { onTap?() }
                .allowsHitTesting(onTap != nil)
        }
        .frame(width: size, height: size)
    }
}

struct MascotStageKey: PreferenceKey {
    static let defaultValue: MascotStage? = nil
    static func reduce(value: inout MascotStage?, nextValue: () -> MascotStage?) {
        if let next = nextValue() { value = next }
    }
}

extension View {
    /// Déclare où le routeur doit poser TapTap pendant que cet écran est visible.
    func mascotStage(_ stage: MascotStage) -> some View {
        preference(key: MascotStageKey.self, value: stage)
    }
}

// MARK: - L'invitation à toucher

/// L'indice de tapabilité : une pastille discrète, et un doigt qui descend.
///
/// Pas de halo lumineux autour du personnage — un cercle de lumière qui pulse
/// derrière lui se lit comme un effet spécial, pas comme une consigne. Une
/// pastille avec un verbe, en revanche, se lit.
struct TouchHint: View {
    var label: String
    var accent: Color = HZ.Colors.blue
    /// Sur un fond coloré, la pastille a besoin d'un fond plus franc : 11 %
    /// d'opacité disparaît sur du violet saturé.
    var onColor: Bool = false
    @State private var bob = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 15, weight: .semibold))
                .offset(y: bob ? -2.5 : 2.5)
            Text(label)
                .font(HZ.Fonts.fig(16.5, .bold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 19)
        .padding(.vertical, 12)
        .background(Capsule().fill(accent.opacity(onColor ? 0.22 : 0.11)))
        .onAppear { bob = true }
        .animation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true), value: bob)
    }
}

/// L'invitation à glisser vers la suite : une flèche qui va et vient.
///
/// Le mouvement porte la consigne, le texte la confirme. Une flèche immobile
/// ressemble à une décoration ; une flèche qui dérive de six points se lit comme
/// une direction.
struct SwipeOnward: View {
    var label: String
    var accent: Color = HZ.Colors.blue
    /// La flèche est AUSSI un bouton. Le glissement reste le geste principal,
    /// mais quelqu'un qui ne le trouve pas ne doit pas rester bloqué : on ne
    /// laisse jamais une seule façon d'avancer.
    var action: (() -> Void)? = nil
    @State private var slide = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action?()
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(HZ.Fonts.fig(15, .semibold))
                    .foregroundStyle(HZ.Colors.sub)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .offset(x: slide ? 6 : -2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accent.opacity(0.12)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onAppear { slide = true }
        .animation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true), value: slide)
    }
}

/// La rature : un trait rouge qui se tire de gauche à droite.
///
/// Elle dit ce qu'aucune légende ne dirait aussi vite : ce champ, on n'a pas
/// réussi à le remplir. Le trait se TIRE au lieu d'apparaître, parce qu'un
/// geste de rature est un geste, pas un état.
struct StrikeThrough: View {
    var color: Color = HZ.Colors.mRed
    var thickness: CGFloat = 2.5
    var delay: Double = 0.35
    @State private var drawn = false

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(color)
                .frame(width: drawn ? geo.size.width : 0, height: thickness)
                .frame(width: geo.size.width, alignment: .leading)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .task {
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(.easeOut(duration: 0.42)) { drawn = true }
        }
    }
}

// MARK: - Boutons

/// LE bouton d'un écran. Un seul par écran, plein, à la couleur choisie.
struct OnbButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = HZ.Colors.blue
    var enabled: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 9) {
                Text(title)
                    .font(HZ.Fonts.fig(17.5, .bold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(enabled ? fill : HZ.Colors.cardDeep,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: enabled ? fill.opacity(0.32) : .clear, radius: 16, y: 7)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.spring(duration: 0.22), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

/// Le lien secondaire, discret mais lisible. Jamais gris pâle sur blanc : une
/// sortie qu'on cache est une sortie qu'on regrette.
struct OnbLink: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HZ.Fonts.fig(15, .semibold))
                .foregroundStyle(HZ.Colors.sub)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - La progression

/// Cinq bulles de chat reliées par un fil. Chaque étape franchie se remplit,
/// et TapTap en miniature est posé sur la bulle courante.
///
/// Ni pourcentage, ni « 3 sur 16 » : un coup d'œil doit suffire à voir combien
/// il reste. Elle n'apparaît qu'à partir de l'acte III.
struct OnbProgress: View {
    /// De 0 à 4.
    let stage: Int
    var accent: Color = HZ.Colors.blue

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                if i > 0 {
                    Rectangle()
                        .fill(i <= stage ? accent : HZ.Colors.cardDeep)
                        .frame(height: 2.5)
                        .frame(maxWidth: .infinity)
                }
                ZStack {
                    OnbBubbleShape(tail: .none)
                        .fill(i <= stage ? accent : HZ.Colors.cardDeep)
                        .frame(width: i == stage ? 15 : 11,
                               height: i == stage ? 15 : 11)
                    if i == stage {
                        Circle()
                            .fill(.white)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(width: 18, height: 18)
            }
        }
        .animation(.spring(duration: 0.45), value: stage)
    }
}

// MARK: - Le détecteur de double tap

/// La signature de l'app, transformée en interaction d'onboarding.
///
/// Le retour haptique est DOUBLE et espacé de 90 ms : le geste a une texture,
/// on sent deux impulsions distinctes. C'est ce qui fait qu'on retient le
/// rythme dans le corps avant de le porter au dos du téléphone.
struct DoubleTapZone<Content: View>: View {
    var enabled: Bool = true
    let onDoubleTap: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard enabled else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onDoubleTap()
            }
    }
}

/// L'indicateur du geste : deux ondes concentriques qui partent d'un point, au
/// rythme EXACT d'un double tap (deux impulsions à 180 ms, puis une pause).
/// C'est un métronome visuel : on apprend la cadence en la regardant.
struct DoubleTapPulse: View {
    var accent: Color = HZ.Colors.blue
    var size: CGFloat = 90

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .strokeBorder(accent, lineWidth: 2.5)
                    .frame(width: size, height: size)
                    .modifier(RipplePhase(delay: Double(i) * 0.18))
            }
            Circle()
                .fill(accent)
                .frame(width: size * 0.17, height: size * 0.17)
        }
        .frame(width: size, height: size)
    }
}

private struct RipplePhase: ViewModifier {
    let delay: Double
    @State private var go = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(go ? 1 : 0.28)
            .opacity(go ? 0 : 0.85)
            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)
                        .delay(delay), value: go)
            .onAppear { go = true }
    }
}

// MARK: - Le châssis de téléphone

/// Les mesures de l'asset de téléphone, en fractions de sa LARGEUR.
///
/// Elles ont été relevées sur l'image détourée, pas estimées : le rayon des
/// coins d'un iPhone n'est pas un arc de cercle, l'île flotte à une distance
/// qu'on ne devine pas, et le bezel du bas est plus épais que celui du haut.
/// Dessiner tout ça en SwiftUI donnait un objet crédible de loin et faux de
/// près — d'où le passage à une image, avec le contenu qui reste vivant.
enum PhoneMetrics {
    /// Hauteur / largeur de l'asset. Les trois assets partagent ce ratio, ce
    /// qui est la condition pour que le retournement dos → face soit crédible.
    static let ratio: CGFloat = 2.035
    /// La dalle, dans le repère de l'image.
    static let screenInsetX: CGFloat = 0.0417
    static let screenInsetTop: CGFloat = 0.0400
    static let screenInsetBottom: CGFloat = 0.0500
    static let screenRadius: CGFloat = 0.1330
    /// Bas de l'île. Aucun contenu ne doit passer dessous.
    static let islandBottom: CGFloat = 0.1500
    /// Le centre de la pomme, cible du double tap. Elle est volontairement
    /// discrète — un cinquième de la largeur — donc le halo doit être plus
    /// large qu'elle pour rester une cible tactile confortable.
    static let appleCenterY: CGFloat = -0.0150
    static let appleWidth: CGFloat = 0.1950

    static var screenWidth: CGFloat { 1 - 2 * screenInsetX }
    static var screenHeight: CGFloat { ratio - screenInsetTop - screenInsetBottom }
    /// La dalle n'est pas centrée : le bezel du bas est le plus épais.
    static var screenOffsetY: CGFloat { (screenInsetTop - screenInsetBottom) / 2 }
    /// Hauteur à réserver en haut du contenu pour ne pas glisser sous l'île.
    static var contentTopInset: CGFloat { islandBottom - screenInsetTop + 0.020 }
}

/// Le châssis, en image, avec du contenu SwiftUI vivant posé dans la dalle.
///
/// Le contenu passe PAR-DESSUS l'image — la dalle crème de l'asset lui sert de
/// fond d'écran — et il est recadré au rayon de la dalle pour qu'une bulle qui
/// dépasse soit coupée comme elle le serait sur un vrai écran.
struct PhoneFrame<Content: View>: View {
    var width: CGFloat = 240
    /// Laisse la place à l'île en haut. À couper pour un plein écran.
    var respectsIsland: Bool = true
    @ViewBuilder var content: Content

    private var height: CGFloat { width * PhoneMetrics.ratio }

    var body: some View {
        ZStack {
            Image("PhoneV2Frame")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)

            content
                .padding(.top, respectsIsland ? width * PhoneMetrics.contentTopInset : 0)
                .frame(width: width * PhoneMetrics.screenWidth,
                       height: width * PhoneMetrics.screenHeight,
                       alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: width * PhoneMetrics.screenRadius,
                                            style: .continuous))
                .offset(y: width * PhoneMetrics.screenOffsetY)
        }
        .frame(width: width, height: height)
        .shadow(color: HZ.Colors.ink.opacity(0.20), radius: width * 0.10, y: width * 0.05)
    }
}

/// La face avant telle quelle : conversation déjà en place, rien à animer.
/// Sert quand on montre une discussion comme un décor, pas comme une scène.
struct PhoneFront: View {
    var width: CGFloat = 240

    var body: some View {
        Image("PhoneV2Front")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: width * PhoneMetrics.ratio)
            .shadow(color: HZ.Colors.ink.opacity(0.20), radius: width * 0.10, y: width * 0.05)
    }
}

/// Le DOS du téléphone, avec la pomme comme cible du geste.
///
/// La pomme EST le bouton : c'est l'idée qui a rendu l'écran compréhensible
/// sans une ligne d'explication. Le halo pulse dessus, exactement là où il faut
/// taper — et l'asset est volontairement aux couleurs de TapTap, parce que ce
/// téléphone est le sien, pas un appareil génénérique.
struct PhoneBack: View {
    var width: CGFloat = 240
    /// Pilote le halo seulement : l'appareil garde les couleurs de la marque.
    var accent: Color = .white
    var pulsing: Bool = true

    private var height: CGFloat { width * PhoneMetrics.ratio }

    var body: some View {
        ZStack {
            Image("PhoneV2Back")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)

            // Le halo, centré sur la pomme.
            Group {
                if pulsing {
                    DoubleTapPulse(accent: accent, size: width * PhoneMetrics.appleWidth * 2.4)
                } else {
                    Circle()
                        .stroke(accent.opacity(0.30), lineWidth: 1.4)
                        .frame(width: width * PhoneMetrics.appleWidth * 2.0)
                }
            }
            .offset(y: width * PhoneMetrics.appleCenterY)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .shadow(color: HZ.Colors.blue.opacity(0.26), radius: width * 0.11, y: width * 0.06)
    }
}

// MARK: - Conversation de démonstration

/// Une bulle de conversation, dans le châssis du téléphone.
struct MiniBubble: View {
    let text: String
    var mine: Bool = false
    var accent: Color = HZ.Colors.blue
    var placeholder: Bool = false

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 26) }
            Group {
                if placeholder {
                    // Barres grises : pour les démonstrations où le contenu du
                    // message n'a aucune importance.
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach([CGFloat(0.9), 0.6], id: \.self) { w in
                            Capsule()
                                .fill(mine ? .white.opacity(0.55) : HZ.Colors.faint.opacity(0.42))
                                .frame(width: 92 * w, height: 6)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 10)
                } else {
                    Text(text)
                        .font(HZ.Fonts.fig(11.5, .medium))
                        .foregroundStyle(mine ? .white : HZ.Colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
            }
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 13,
                    bottomLeadingRadius: mine ? 13 : 4,
                    bottomTrailingRadius: mine ? 4 : 13,
                    topTrailingRadius: 13,
                    style: .continuous
                )
                .fill(mine ? accent : HZ.Colors.cardDeep)
            )
            if !mine { Spacer(minLength: 26) }
        }
    }
}

// MARK: - L'île simulée, en DA Horizon

/// La vraie Live Activity ne s'affiche pas de façon fiable quand l'app est au
/// premier plan : toutes les démonstrations en ont donc besoin d'une copie.
/// Celle-ci est dans la DA de l'app, avec TapTap dedans.
struct OnbIsland: View {
    enum Phase { case working, ready }
    let phase: Phase
    var reply: String = ""
    var accent: Color = HZ.Colors.blue
    var mascotColor: Color = HZ.Colors.blue

    @State private var fill: CGFloat = 0.08

    var body: some View {
        HStack(spacing: 11) {
            TapTapFigure(size: 34, beats: [.still(TapTapClips.stillBase)], accent: mascotColor)

            VStack(alignment: .leading, spacing: 5) {
                Text(phase == .working
                     ? String(localized: "TapTap lit la conversation…")
                     : String(localized: "Réponse prête ✓ copiée"))
                    .font(HZ.Fonts.fig(12.5, .semibold))
                    .foregroundStyle(.white)

                if phase == .working {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.22))
                            Capsule().fill(.white)
                                .frame(width: geo.size.width * fill)
                        }
                    }
                    .frame(height: 3.5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.2)) { fill = 0.97 }
                    }
                } else if !reply.isEmpty {
                    Text(reply)
                        .font(HZ.Fonts.fig(11.5, .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(HZ.Colors.pillDark)
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(accent.opacity(0.55), lineWidth: 1.4)
        )
    }
}

// MARK: - Une carte de réglage iOS, redessinée

/// Une ligne des Réglages d'iOS, reconstituée.
///
/// POURQUOI ON LA DESSINE PLUTÔT QUE DE MONTRER UNE CAPTURE : une capture est
/// figée dans UNE langue et UN thème. Ici, le libellé suit la langue de l'app,
/// l'apparence suit le thème, le poids est nul, et surtout on peut FAIRE PULSER
/// la ligne à toucher pour guider l'œil — ce qu'une image ne permet pas.
struct SettingsRow: View {
    let icon: String
    let iconTint: Color
    let label: String
    var value: String? = nil
    /// Met la ligne en surbrillance et la fait respirer.
    var highlighted: Bool = false
    var accent: Color = HZ.Colors.blue

    @State private var glow = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconTint)
                .frame(width: 29, height: 29)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
            Text(label)
                .font(HZ.Fonts.fig(15.5, .regular))
                .foregroundStyle(HZ.Colors.ink)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let value {
                Text(value)
                    .font(HZ.Fonts.fig(15, .regular))
                    .foregroundStyle(HZ.Colors.faint)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HZ.Colors.dash)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(accent.opacity(glow ? 0.16 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(accent.opacity(glow ? 0.9 : 0.4),
                                          lineWidth: 2)
                    )
            }
        }
        .onAppear {
            guard highlighted else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Le fond qui change d'acte

/// Le rideau circulaire : un disque de la nouvelle couleur naît SOUS TapTap et
/// s'étend jusqu'à remplir l'écran. La couleur vient donc de lui — c'est lui qui
/// change le monde, pas un fondu anonyme.
struct ActBackdrop: View {
    let color: Color
    /// D'où part le disque, en coordonnées unitaires.
    var origin: UnitPoint = .center
    var active: Bool

    /// LE POINT COLORÉ AU MILIEU DE L'ÉCRAN — corrigé le 30/08.
    ///
    /// Le disque était replié par `scaleEffect(active ? 1 : 0.001)`. Or son
    /// diamètre vaut 2,4 fois le plus grand côté de l'écran, soit ~2 240 pt sur
    /// un iPhone : à l'échelle 0,001 il mesurait encore DEUX POINTS, toujours
    /// rendus, toujours opaques, pile au centre. D'où la pastille de couleur
    /// visible sur tous les écrans non teintés, et son côté intermittent —
    /// elle se confondait avec le fond quand la teinte s'en approchait.
    ///
    /// Trois verrous plutôt qu'un, parce qu'un epsilon corrigé en epsilon plus
    /// petit ne fait que rendre le défaut plus discret :
    ///   1. l'échelle va à ZÉRO, pas à un epsilon ;
    ///   2. l'opacité tombe à 0 — même si une passe de rendu arrondissait la
    ///      transformation, il n'y aurait rien à peindre ;
    ///   3. le disque est RETIRÉ de l'arbre de vues une fois l'animation finie,
    ///      donc il ne reste aucune surface à arrondir.
    @State private var rendered = false

    var body: some View {
        GeometryReader { geo in
            let d = max(geo.size.width, geo.size.height) * 2.4
            if rendered || active {
                Circle()
                    .fill(color)
                    .frame(width: d, height: d)
                    .position(x: geo.size.width * origin.x,
                              y: geo.size.height * origin.y)
                    .scaleEffect(active ? 1 : 0, anchor: .center)
                    .opacity(active ? 1 : 0)
                    .animation(.easeInOut(duration: 0.62), value: active)
            }
        }
        .ignoresSafeArea()
        // Un décor ne capte jamais un toucher.
        .allowsHitTesting(false)
        .onAppear { rendered = active }
        .onChange(of: active) { _, now in
            if now {
                rendered = true
            } else {
                // On attend la fin du repli (620 ms) avant de démonter, sinon
                // le disque disparaîtrait d'un coup au lieu de se refermer.
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    if !active { rendered = false }
                }
            }
        }
    }
}
