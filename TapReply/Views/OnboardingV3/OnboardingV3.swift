import SwiftUI

// =============================================================================
// ONBOARDING V3 — LE ROUTEUR (TapTap vectoriel, script v2)
// =============================================================================
//
// Dix-sept temps, six actes. Ce qui change par rapport à V2 :
//
// 1. TAPTAP EST UN PERSONNAGE ANIMÉ, PAS UN DESSIN. Il sort d'une lampe, sort
//    un iPhone géant de sa poche, écrit au crayon, met des lunettes de
//    professeur, plonge, jaillit du sol, range les cartes du paywall. Chaque
//    écran a UN gag d'arrivée, puis le calme (bible, principe 7).
//
// 2. LES ÉCRANS NE LE CONTIENNENT PAS. Ils publient une SCÈNE (TapTapScene) :
//    où il se pose, à quelle échelle, ce qu'il joue, comment il arrive. Le
//    metteur en scène (TapTapDirectorLayer) l'y emmène — marche, sortie de
//    cadre, pouf — et fond les clips entre eux. C'est ce qui fait du parcours
//    un plan-séquence.
//
// 3. LA DÉMO SE JOUE DANS L'IPHONE GÉANT QU'IL A SORTI DE SA POCHE. La dalle de
//    l'iPhone vectoriel est plaquée sur une vue SwiftUI : la conversation, le
//    champ, l'île y sont VRAIS. Le geste (deux taps au dos) se fait sur ce même
//    iPhone, retourné.
//
// Ce qui ne change pas : la magie avant l'effort, le consentement explicite,
// les réglages système redessinés, l'honnêteté sur la vérification, le paywall
// qui clôt au lieu d'interrompre. Les chaînes de l'ancien onboarding sont
// conservées dès qu'elles restent justes (✅ dans le script).
// =============================================================================

struct OnboardingV3: View {
    @AppStorage(SettingsKeys.onboardingDone) private var onboardingDone = false
    @AppStorage(SettingsKeys.userName) private var userName = ""
    @AppStorage(SettingsKeys.avatarColorIndex) private var avatarColorIndex = 0
    @AppStorage(SettingsKeys.messagesPerDay) private var messagesPerDay = 20
    @ObservedObject private var theme = HZTheme.shared

    @State private var draft = OnbDraft()
    @State private var step: Onb3Step = .lamp
    @State private var scene: TapTapScene?
    /// Jeton de navigation : toute closure `onNext` capturée par un écran déjà quitté (Task avec délai) est ignorée.
    /// Sans lui, « Elle est parfaite » puis retour ramenait 3,6 s plus tard sur le consentement (audit 26/09, M1).
    @State private var visit = 0
    /// Restauration après terminaison par iOS : l'onboarding envoie lui-même dans Raccourcis / Réglages (M3).
    /// SceneStorage n'est restauré qu'après une terminaison par le système, pas après un kill volontaire.
    @SceneStorage("onb3.step") private var savedStep = Onb3Step.lamp.rawValue
    @SceneStorage("onb3.name") private var savedName = ""
    @AppStorage(SettingsKeys.onboardingReplay) private var isReplay = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Fond ─────────────────────────────────────────────────
                // Blanc pur pour la lampe (le fond de la vidéo approuvée), puis
                // canevas clair. Le rideau circulaire reste pour les deux pics
                // de couleur (essai, brouillon) et la récompense.
                (step.nightBackground ? Color.white : HZ.Colors.page).ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: step.nightBackground)
                // Les pics de couleur sont des teintes CLAIRES de l'accent : TapTap (violet) reste lisible dessus.
                ActBackdrop(color: draft.accent.lightened(),
                            origin: UnitPoint(x: 0.5, y: 0.42),
                            active: step.tintedBackground)

                VStack(spacing: 0) {
                    if step != .paywall { topBar }
                    // L'écran qui part disparaît IMMÉDIATEMENT (aucun chevauchement de deux écrans : deux écrans
                    // = deux places publiées pour TapTap = TapTap qui saute) ; celui qui arrive fond en 0,3 s.
                    content
                        .id(step)
                        .transition(.asymmetric(insertion: step.isPhoneStep ? .identity : .opacity, removal: .identity))
                }

                // UNE seule instance de TapTap, toujours au-dessus du contenu ; quand un écran veut TapTap derrière
                // un objet (l'iPhone géant), il publie un occulteur.
                TapTapDirectorLayer(scene: scene, viewSize: geo.size)
            }
        }
        .coordinateSpace(name: onb3Space)
        .preferredColorScheme(.light)
        // Mises en page chorégraphiées à hauteur fixe : on plafonne le Dynamic Type (le paywall, enfant, en profite).
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(.easeOut(duration: 0.3), value: step)
        .onPreferenceChange(TapTapSceneKey.self) { next in
            // On IGNORE les nil : entre le démontage d'un écran et le montage
            // du suivant, personne ne publie — lire ce vide ferait clignoter
            // TapTap.
            guard let next else { return }
            scene = next
        }
        .onAppear {
            draft.hydrate(name: userName, colorIndex: avatarColorIndex)
            if draft.name.isEmpty { draft.name = savedName }
            // Reprise après une fermeture PAR iOS pendant les réglages (Raccourcis / Réglages) uniquement :
            // jamais pour une relance volontaire depuis les Réglages de l'app, et jamais au-delà des réglages.
            if !isReplay, let s = Onb3Step(rawValue: savedStep),
               s.rawValue >= Onb3Step.setupIntro.rawValue, s.rawValue <= Onb3Step.notifications.rawValue {
                step = s
            } else {
                savedStep = Onb3Step.lamp.rawValue
            }
            Analytics.track("onb_step", ["step": step.analyticsName])
            TapTapClip.preload([TapTapClips.coucou, TapTapClips.idle, TapTapClips.idleRegard,
                                TapTapClips.idleEtirement, TapTapClips.presente, TapTapClips.marche, TapTapClips.arretMarche])
        }
        .onChange(of: step) { _, s in
            savedStep = s.rawValue
            Analytics.track("onb_step", ["step": s.analyticsName])
        }
        .onChange(of: draft.name) { _, n in savedName = n }
    }

    // MARK: Barre haute

    private var topBar: some View {
        HStack(spacing: 14) {
            if step.canGoBack {
                Button {
                    visit += 1
                    Analytics.track("onb_back", ["from": step.analyticsName])
                    withAnimation(.spring(duration: 0.45)) { step = step.previous }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(step.darkTint ? .white : HZ.Colors.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Retour"))
            } else if isReplay {
                // Relance depuis les Réglages : on peut toujours en sortir (sans repasser par le paywall).
                Button {
                    isReplay = false
                    savedStep = Onb3Step.lamp.rawValue
                    UserDefaults.standard.set(true, forKey: SettingsKeys.tourDone)
                    onboardingDone = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HZ.Colors.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Quitter"))
            } else {
                Spacer().frame(width: 40, height: 40)
            }

            if let stage = step.progressStage {
                OnbProgress(stage: stage, accent: draft.accent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Spacer()
            }

            if let skip = step.skipTarget {
                Button {
                    for key in skip.confirms { UserDefaults.standard.set(true, forKey: key) }
                    // la couleur choisie vaut aussi pour la suite (paywall) même si on passe
                    if step == .name || step == .color { TapTapColor.apply(index: draft.colorIndex) }
                    Analytics.track("onb_skip", ["from": step.analyticsName])
                    visit += 1
                    withAnimation(.spring(duration: 0.45)) { step = skip.step }
                } label: {
                    Text(skip.label)
                        .font(HZ.Fonts.fig(13.5, .semibold))
                        .foregroundStyle(step.darkTint ? .white.opacity(0.62) : HZ.Colors.faint)
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
        let v = visit
        switch step {
        // ── ACTE 0 · la lampe ────────────────────────────────────────────
        case .lamp:          Onb3Lamp(draft: $draft) { go(.hello, visit: v) }
        case .hello:         Onb3Hello(draft: $draft) { go(.situation, visit: v) }
        // ── ACTE 1 · le problème, puis la magie ──────────────────────────
        case .situation:     Onb3Situation(draft: $draft) { go(.phone, visit: v) }
        case .phone:         Onb3Phone(draft: $draft) { go(.demo, visit: v) }
        case .demo:          Onb3Demo(draft: $draft) { go(.tryIt, visit: v) }
        case .tryIt:         Onb3TryIt(draft: $draft) { go(.draft, visit: v) }
        // ── ACTE 2 · le brouillon ────────────────────────────────────────
        case .draft:         Onb3Draft(draft: $draft) { go(.name, visit: v) }
        // ── ACTE 3 · ton TapTap ──────────────────────────────────────────
        case .name:          Onb3Name(draft: $draft) { go(.color, visit: v) }
        case .color:         Onb3Color(draft: $draft) {
                                 guard v == visit else { return }
                                 TapTapColor.apply(index: draft.colorIndex); go(.privacy, visit: v)
                             }
        // ── ACTE 4 · la confiance ────────────────────────────────────────
        case .privacy:       Onb3Privacy(draft: $draft) { go(.setupIntro, visit: v) }
        // ── ACTE 5 · le vrai geste ───────────────────────────────────────
        case .setupIntro:    Onb3SetupIntro(draft: $draft) { go(.setupShortcut, visit: v) }
        case .setupShortcut: Onb3SetupShortcut(draft: $draft) { go(.setupBackTap, visit: v) }
        case .setupBackTap:  Onb3SetupBackTap(draft: $draft) { go(.permissions, visit: v) }
        case .permissions:   Onb3Permissions(draft: $draft) { go(.notifications, visit: v) }
        case .notifications: Onb3Notifications(draft: $draft) { go(.reward, visit: v) }
        // ── ACTE 6 · prêt, puis l'offre ──────────────────────────────────
        case .reward:
            Onb3Reward(draft: $draft, onNext: { go(.paywall, visit: v) }, onTest: {
                // Le vrai double tap se pratique dans le terrain d'essai : on ferme l'onboarding ; la visite guidée
                // (accueil, studio, terrain d'essai) se joue d'abord et se termine SUR le terrain d'essai.
                guard v == visit else { return }
                finish()
            }, onFinishSetup: {
                // « Terminer l'activation maintenant » : retour à l'étape de réglage manquante (pas au paywall).
                let d = UserDefaults.standard
                let target: Onb3Step = !d.bool(forKey: SettingsKeys.consentAccepted) ? .privacy
                    : !d.bool(forKey: SettingsKeys.shortcutConfirmed) ? .setupShortcut : .setupBackTap
                go(target, visit: v)
            })
        case .paywall:
            ProPaywall(onClose: { finish() }, choreographed: true)
                .tapTapScene(TapTapScene(placement: .ground(anchor: .zero, height: 1), beats: [], hidden: true))
        }
    }

    private func go(_ next: Onb3Step, visit v: Int) {
        guard v == visit, next != step else { return }   // closure périmée (écran quitté) ou double appel
        visit += 1
        withAnimation(.spring(duration: 0.5)) { step = next }
    }

    private func finish() {
        guard !onboardingDone else { return }   // le paywall peut appeler onClose deux fois (fin du clip + filet)
        Analytics.track("onb_done", ["replay": isReplay ? "1" : "0"])
        // La progression sauvegardée ne doit JAMAIS survivre à la fin : sinon « Revoir l'onboarding » repartait
        // de l'écran « C'est prêt » (bug du 26/09).
        savedStep = Onb3Step.lamp.rawValue
        savedName = ""
        userName = String(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        messagesPerDay = draft.messagesPerDay
        // UNE couleur : celle choisie pour TapTap est celle de l'app (et de tous ses TapTap) — synchronisée partout.
        TapTapColor.apply(index: draft.colorIndex)
        UserDefaults.standard.set(false, forKey: SettingsKeys.onboardingReplay)
        // La visite guidée (accueil, studio, terrain d'essai) suit chaque onboarding, replay compris.
        UserDefaults.standard.set(false, forKey: SettingsKeys.tourDone)
        onboardingDone = true
    }
}

// MARK: - Les dix-sept temps

enum Onb3Step: Int, CaseIterable, Equatable {
    case lamp, hello
    case situation, phone, demo, tryIt
    case draft
    case name, color
    case privacy
    case setupIntro, setupShortcut, setupBackTap, permissions, notifications
    case reward, paywall

    var nightBackground: Bool { self == .lamp }
    /// Les écrans autour de l'iPhone géant : l'iPhone ne bouge pas d'un écran à l'autre, seuls les textes et la dalle s'animent.
    var isPhoneStep: Bool {
        switch self { case .phone, .demo, .tryIt, .draft: return true; default: return false }
    }

    var tintedBackground: Bool {
        switch self {
        case .hello, .tryIt, .draft, .reward: return true
        default: return false
        }
    }

    var darkTint: Bool { false }

    var progressStage: Int? {
        switch self {
        case .lamp, .hello, .situation, .phone, .demo, .tryIt, .draft: return nil
        case .name, .color:            return 0
        case .privacy:                 return 1
        case .setupIntro, .setupShortcut, .setupBackTap, .permissions, .notifications: return 2
        case .reward:                  return 3
        case .paywall:                 return 4
        }
    }

    var canGoBack: Bool {
        switch self {
        case .lamp, .hello, .reward, .paywall: return false
        default: return true
        }
    }

    var skipTarget: (step: Onb3Step, label: String, confirms: [String])? {
        switch self {
        case .situation, .phone, .demo:
            return (.tryIt, String(localized: "Passer"), [])
        case .name, .color:
            return (.privacy, String(localized: "Passer"), [])
        case .setupIntro:
            return (.permissions, String(localized: "Déjà réglé"), [SettingsKeys.shortcutConfirmed, SettingsKeys.backTapConfirmed])
        case .setupShortcut:
            return (.setupBackTap, String(localized: "Déjà fait"), [SettingsKeys.shortcutConfirmed])
        case .setupBackTap:
            return (.permissions, String(localized: "Déjà fait"), [SettingsKeys.backTapConfirmed])
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

    var previous: Onb3Step { Onb3Step(rawValue: max(0, rawValue - 1)) ?? .lamp }
    /// Nom stable envoyé dans les statistiques anonymes (« lamp », « privacy »…).
    var analyticsName: String { String(describing: self) }
}

enum Onb3Palette {
    /// La nuit du génie (DA v2) : encre profonde, pas de noir pur.
    static let night = Color(hex: 0x111114)
}
