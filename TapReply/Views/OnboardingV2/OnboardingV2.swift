import SwiftUI

// =============================================================================
// ONBOARDING V2 — LE ROUTEUR
// =============================================================================
//
// Seize temps, six actes. La structure suit le script de conception, et elle
// repose sur trois partis pris qu'il faut connaître avant d'y toucher :
//
// 1. LA MAGIE AVANT L'EFFORT. L'utilisateur produit un résultat DEUX FOIS —
//    actes I et II — avant qu'on lui demande la moindre configuration. C'est
//    l'inverse de l'ancien onboarding, qui demandait le setup en premier et
//    perdait les gens là.
//
// 2. TAPTAP NE DISPARAÎT JAMAIS. Il ne se recharge pas d'un écran à l'autre :
//    il VOYAGE. C'est ce qui transforme seize écrans en un seul plan-séquence.
//    Techniquement : une seule instance de MascotView, vivant dans le routeur,
//    positionnée et animée selon l'acte. Les écrans ne le contiennent pas.
//
// 3. LE GESTE S'APPREND PAR LE CORPS. Trois écrans se valident au double tap.
//    On n'explique pas un geste physique avec des mots : on le fait faire.
//
// Le fond change par RIDEAU CIRCULAIRE né sous TapTap, jamais par fondu.
// =============================================================================

struct OnboardingV2: View {
    @AppStorage(SettingsKeys.onboardingDone) private var onboardingDone = false
    @AppStorage(SettingsKeys.userName) private var userName = ""
    @AppStorage(SettingsKeys.avatarColorIndex) private var avatarColorIndex = 0
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 20
    @ObservedObject private var theme = HZTheme.shared

    /// L'état partagé par tous les écrans : ce que l'utilisateur a répondu.
    @State private var draft = OnbDraft()
    @State private var step: OnbStep = .hello

    /// La scène publiée par l'écran courant. TapTap la suit.
    @State private var stage: MascotStage?
    /// Vrai pendant qu'il traverse l'écran. Le temps du trajet, on lui fait
    /// jouer le vol plutôt que ce que l'écran de destination avait demandé.
    @State private var flying = false

    var body: some View {
        ZStack {
            // Le fond de l'acte courant. Deux pics de couleur seulement — la
            // magie et la récompense : un fond coloré permanent fatigue l'œil
            // et dégrade la lisibilité du texte.
            HZ.Colors.page.ignoresSafeArea()
            // Le fond de l'accueil est un violet PROFOND, pas l'accent tel
            // quel : TapTap doit y rester violet — en blanc il perd son dôme et
            // se lit comme une silhouette — donc le fond doit s'écarter
            // franchement de sa teinte. Sur les écrans d'essai, où il commente
            // en blanc, l'accent pur suffit.
            // L'accueil s'ouvre sur un violet CLAIR, pas sur un fond profond :
            // un premier écran sombre pèse, là où on cherche à accueillir.
            //
            // TapTap y reste lisible parce que la teinte est très désaturée et
            // très lumineuse : son dôme, lui, garde l'accent à pleine
            // saturation. Le contraste vient de la saturation, pas de la
            // luminosité — c'est ce qui permet de rester dans la même famille
            // de couleur sans qu'il s'y noie.
            ActBackdrop(color: step == .hello ? draft.accent.lightened() : draft.accent,
                        origin: UnitPoint(x: 0.5, y: 0.42),
                        active: step.tintedBackground)

            VStack(spacing: 0) {
                // Le paywall porte son propre en-tête, avec son logo et sa
                // croix : lui superposer la barre du routeur ferait deux
                // rangées de chrome pour un seul écran.
                if step != .paywall { topBar }
                content
            }

            // ── TAPTAP, UNE SEULE FOIS, POUR TOUT L'ONBOARDING ───────────
            //
            // Il est dessiné ici, au-dessus du contenu, et jamais dans les
            // écrans. C'est ce qui lui permet de VOLER d'un écran à l'autre :
            // la vue n'est pas détruite puis recréée, elle est déplacée. Seize
            // écrans deviennent un plan-séquence, et TapTap quelqu'un qui
            // accompagne au lieu d'une illustration qui se recharge.
            //
            // La zone tactile, elle, reste dans l'écran (MascotSlot) : c'est
            // l'écran qui sait ce qu'un toucher doit déclencher.
            // Le paywall n'a pas de mascotte : il porte son propre en-tête, et
            // TapTap restait planté au milieu de l'écran à la position publiée
            // par l'écran de récompense — le paywall ne publiant aucune scène,
            // et le routeur ignorant les scènes nulles par conception.
            if let st = stage, !st.hidden, step != .paywall {
                MascotView(act: flying ? .fly : st.act,
                           mouth: st.mouth,
                           prop: flying ? .none : st.prop,
                           color: st.white ? .white : draft.accent,
                           size: st.size)
                    .position(st.center)
                    .allowsHitTesting(false)
                    // On n'animate QUE le centre et la taille. Si on écoutait
                    // toute la scène, un simple changement d'expression
                    // relancerait le ressort de déplacement.
                    .animation(.spring(response: 0.72, dampingFraction: 0.70),
                               value: st.center)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78),
                               value: st.size)
            }
        }
        .coordinateSpace(name: onbSpace)
        .preferredColorScheme(.light)
        .animation(.spring(duration: 0.5), value: step)
        .onPreferenceChange(MascotStageKey.self) { next in
            // On IGNORE les nil. Entre le démontage d'un écran et le montage du
            // suivant, il existe une passe où plus personne ne publie de scène.
            // La lire ferait disparaître TapTap une fraction de seconde, puis
            // réapparaître ailleurs : c'est précisément ce qui donnait
            // l'impression qu'il « spawnait » au lieu de se déplacer.
            guard let next else { return }
            let travelled = stage.map {
                hypot(next.center.x - $0.center.x, next.center.y - $0.center.y)
            } ?? 0
            stage = next
            // Au-delà de 70 points, c'est un vrai trajet : on le met en scène.
            guard travelled > 70 else { return }
            flying = true
            Task {
                try? await Task.sleep(for: .milliseconds(740))
                flying = false
            }
        }
        .onAppear { draft.hydrate(name: userName, colorIndex: avatarColorIndex) }
    }

    // MARK: Barre haute — retour et progression

    private var topBar: some View {
        HStack(spacing: 14) {
            if step.canGoBack {
                Button {
                    withAnimation(.spring(duration: 0.45)) { step = step.previous }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(step.darkTint ? .white : HZ.Colors.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 40, height: 40)
            }

            // La progression n'apparaît qu'à partir de l'acte III : montrer une
            // jauge pendant la séduction, c'est annoncer un formulaire.
            if let stage = step.progressStage {
                OnbProgress(stage: stage, accent: draft.accent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Spacer()
            }

            // Le raccourci de sortie, volontairement discret : gris, petit, sans
            // fond. Il doit exister — un onboarding sans porte de sortie se fait
            // fermer par le bouton Accueil du téléphone, et on perd tout — mais
            // il ne doit pas concurrencer l'action de l'écran.
            if let skip = step.skipTarget {
                Button {
                    for key in skip.confirms {
                        UserDefaults.standard.set(true, forKey: key)
                    }
                    withAnimation(.spring(duration: 0.45)) { step = skip.step }
                } label: {
                    Text(skip.label)
                        .font(HZ.Fonts.fig(13.5, .semibold))
                        .foregroundStyle(step.darkTint
                                         ? .white.opacity(0.62)
                                         : HZ.Colors.faint)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .frame(height: 52)
    }

    // MARK: Le corps

    @ViewBuilder
    private var content: some View {
        switch step {
        // ── ACTE I · la rencontre ────────────────────────────────────────
        case .hello:      OnbHello(draft: $draft) { go(.situation) }
        case .situation:  OnbSituation(draft: $draft) { go(.oldWay) }
        case .oldWay:     OnbOldWay(draft: $draft) { go(.demo) }
        case .demo:       OnbDemo(draft: $draft) { go(.tryIt) }

        // ── ACTE II · la magie essayée ───────────────────────────────────
        case .tryIt:      OnbTryIt(draft: $draft) { go(.draftFeature) }
        case .draftFeature: OnbDraftFeature(draft: $draft) { go(.name) }

        // ── ACTE III · faire connaissance ────────────────────────────────
        case .name:          OnbName(draft: $draft) { go(.color) }
        case .color:         OnbColor(draft: $draft) { go(.privacy) }

        // ── ACTE IV · la confiance ───────────────────────────────────────
        case .privacy:       OnbPrivacy(draft: $draft) { go(.setupIntro) }

        // ── ACTE V · l'activation ────────────────────────────────────────
        case .setupIntro:    OnbSetupIntro(draft: $draft) { go(.setupShortcut) }
        case .setupShortcut: OnbSetupShortcut(draft: $draft) { go(.setupBackTap) }
        case .setupBackTap:  OnbSetupBackTap(draft: $draft) { go(.permissions) }
        case .permissions:   OnbPermissions(draft: $draft) { go(.notifications) }
        case .notifications: OnbNotifications(draft: $draft) { go(.reward) }

        // ── ACTE VI · la récompense ──────────────────────────────────────
        case .reward:        OnbReward(draft: $draft) { go(.paywall) }

        // ── L'OFFRE ──────────────────────────────────────────────────────
        // Le paywall lit lui-même le prénom, la couleur et le volume estimé :
        // il est personnalisé, donc il n'a besoin d'aucun paramètre. Le fermer
        // termine l'onboarding — on n'enferme personne derrière une offre.
        case .paywall:       ProPaywall { finish() }
        }
    }

    private func go(_ next: OnbStep) {
        withAnimation(.spring(duration: 0.5)) { step = next }
    }

    private func finish() {
        // On persiste ce que l'utilisateur a construit, puis on ouvre l'app.
        userName = draft.name
        avatarColorIndex = draft.colorIndex
        messagesPerDay = draft.messagesPerDay
        theme.accentHex = HZTheme.presets[draft.colorIndex]
        UserDefaults.standard.set(false, forKey: SettingsKeys.onboardingReplay)
        onboardingDone = true
    }
}

// MARK: - Les seize temps

enum OnbStep: Int, CaseIterable, Equatable {
    // Acte I · la rencontre
    case hello, situation, oldWay, demo
    // Acte II · la magie essayée
    case tryIt, draftFeature
    // Acte III · faire connaissance. Deux écrans, pas quatre.
    //
    // « Où réponds-tu » et « combien de messages par jour » ont été retirés :
    // ils demandaient un effort pour un bénéfice différé, juste avant le
    // passage le plus difficile du parcours. Le prénom et la couleur restent
    // parce qu'ils rendent quelque chose IMMÉDIATEMENT — un badge à son nom,
    // une mascotte repeinte sous les yeux.
    case name, color
    // Acte IV · la confiance
    case privacy
    // Acte V · l'activation
    // `permissions` : l'avertissement « Toujours autoriser », inséré APRÈS le
    // branchement et AVANT les notifications — c'est-à-dire juste avant le
    // premier vrai double tap, le seul moment où la consigne est actionnable.
    // Cette consigne existait dans l'ancien onboarding et a disparu avec lui.
    case setupIntro, setupShortcut, setupBackTap, permissions, notifications
    // Acte VI · la récompense, puis l'offre
    //
    // Le paywall clôt l'onboarding au lieu de l'interrompre. C'est le moment
    // où l'utilisateur vient de voir ce qu'il gagne, chiffré : la proposition
    // se lit comme la suite logique, pas comme un péage.
    case reward, paywall

    var act: OnbAct {
        switch self {
        case .hello, .situation, .oldWay, .demo:            return .meeting
        case .tryIt, .draftFeature:                          return .magic
        case .name, .color:                                  return .acquaintance
        case .privacy:                                       return .trust
        case .setupIntro, .setupShortcut, .setupBackTap,
             .permissions, .notifications:                    return .activation
        case .reward, .paywall:                               return .reward
        }
    }

    /// Les écrans à fond coloré saturé. Trois moments seulement, et le premier
    /// est nouveau : on OUVRE en couleur, parce qu'un onboarding qui démarre sur
    /// du blanc démarre sur un formulaire. Le rideau circulaire se rétracte
    /// ensuite pour rendre le fond clair au premier écran de contenu.
    ///
    /// C'est décidé écran par écran et non par acte : l'accueil et le constat
    /// appartiennent au même acte mais ne veulent pas le même fond.
    var tintedBackground: Bool {
        switch self {
        case .hello, .tryIt, .draftFeature, .reward: return true
        // Le paywall a son propre fond clair : il doit rester lisible longtemps,
        // et un fond saturé fatigue sur un écran qu'on lit en entier.
        default:                                     return false
        }
    }

    /// Les écrans dont le fond est SATURÉ, et sur lesquels le texte doit passer
    /// en blanc. L'accueil, lui, est coloré mais clair : une flèche blanche y
    /// serait invisible.
    var darkTint: Bool {
        switch self {
        case .tryIt, .draftFeature, .reward: return true
        default:                             return false
        }
    }

    /// De 0 à 4. Nil avant l'acte III, où la barre n'existe pas encore.
    var progressStage: Int? {
        switch act {
        case .meeting, .magic: return nil
        case .acquaintance:    return 0
        case .trust:           return 1
        case .activation:      return 2
        case .reward:          return self == .paywall ? 4 : 3
        }
    }

    /// On ne revient pas en arrière sur le tout premier écran, ni pendant
    /// l'activation : refaire un pas en arrière au milieu d'une configuration
    /// système désoriente plus qu'il n'aide.
    var canGoBack: Bool {
        switch self {
        case .hello, .reward, .paywall: return false
        default: return true
        }
    }

    /// Où mène le raccourci de sortie, et sous quel libellé.
    ///
    /// Il n'est pas uniforme : sauter la démonstration, c'est aller à l'essai ;
    /// sauter un réglage système, c'est passer au suivant en assumant qu'il est
    /// déjà fait. Un « Passer » unique qui enverrait toujours à la fin ferait
    /// rater l'activation à ceux qui en ont le plus besoin.
    var skipTarget: (step: OnbStep, label: String, confirms: [String])? {
        switch self {
        case .situation, .oldWay, .demo:
            return (.tryIt, String(localized: "Passer"), [])
        case .name, .color:
            return (.privacy, String(localized: "Passer"), [])
        // « Déjà réglé » et « Déjà fait » sont des AFFIRMATIONS de
        // l'utilisateur : elles doivent donc marquer les étapes comme
        // confirmées. Sans ça, quelqu'un qui avait déjà tout réglé se voyait
        // accueilli par des bandeaux lui réclamant ce qu'il venait de déclarer
        // avoir fait — et l'application se contredisait elle-même.
        case .setupIntro:
            return (.permissions, String(localized: "Déjà réglé"),
                    [SettingsKeys.shortcutConfirmed, SettingsKeys.backTapConfirmed])
        case .setupShortcut:
            return (.setupBackTap, String(localized: "Déjà fait"),
                    [SettingsKeys.shortcutConfirmed])
        case .setupBackTap:
            return (.permissions, String(localized: "Déjà fait"),
                    [SettingsKeys.backTapConfirmed])
        case .permissions:
            return (.notifications, String(localized: "Passer"), [])
        case .notifications:
            return (.reward, String(localized: "Passer"), [])
        case .reward:
            return (.paywall, String(localized: "Suite"), [])
        default:
            return nil
        }
    }

    var previous: OnbStep { OnbStep(rawValue: max(0, rawValue - 1)) ?? .hello }
    var next: OnbStep? { OnbStep(rawValue: rawValue + 1) }
}

enum OnbAct {
    case meeting, magic, acquaintance, trust, activation, reward
}

// MARK: - Ce que l'utilisateur construit

/// L'état accumulé pendant l'onboarding. Rien n'est écrit dans les réglages
/// avant la toute fin : on ne veut pas laisser des traces à moitié posées si
/// quelqu'un abandonne au milieu.
struct OnbDraft {
    var name: String = ""
    var colorIndex: Int = 0
    /// Une hypothèse, pas une réponse : on ne demande plus le volume, on
    /// l'estime. La personne l'ajustera dans les réglages si le chiffre affiché
    /// sur l'écran de récompense lui paraît faux.
    var messagesPerDay: Int = 20

    var accent: Color {
        Color(hex: UInt(HZTheme.presets[min(colorIndex, HZTheme.presets.count - 1)]))
    }

    /// Le prénom, ou une formule neutre : jamais « null » ni un blanc gênant.
    var greetingName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "" : " " + name
    }

    /// Heures récupérées par an — 45 s économisées par message.
    var hoursPerYear: Int {
        AppSettings.hoursPerYear(messagesPerDay: messagesPerDay)
    }

    mutating func hydrate(name: String, colorIndex: Int) {
        if self.name.isEmpty { self.name = name }
        self.colorIndex = colorIndex
    }
}
