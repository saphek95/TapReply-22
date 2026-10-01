import SwiftUI

// =============================================================================
// ACTE 6 — PRÊT
// =============================================================================
//
// T7 : le professeur retire ses lunettes et plonge vers le bas ; l'écran
// « Prêt » monte comme s'il venait de percer le sol.
// S17 : il jaillit du sol en éclaboussant des bulles de messages, puis danse,
// clap, pose victorieuse, et se balance heureux. Honnête (principe 11) : si le
// raccourci ou le double tap n'a pas été confirmé, pas de danse — il présente
// ce qu'il reste à faire, et un lien y mène.
// =============================================================================

struct Onb3Reward: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void
    /// Le vrai test : on termine l'onboarding et on ouvre le TERRAIN D'ESSAI (la fausse conversation où le double
    /// tap réel se pratique sans envoyer à personne).
    var onTest: (() -> Void)? = nil
    /// Ramène à l'étape manquante (consentement, raccourci ou Back Tap) au lieu d'ouvrir le paywall.
    var onFinishSetup: (() -> Void)? = nil

    @AppStorage(SettingsKeys.shortcutConfirmed) private var shortcutConfirmed = false
    @AppStorage(SettingsKeys.backTapConfirmed) private var backTapConfirmed = false
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false

    @State private var arrived = false
    @State private var burst = false
    @State private var revealed = false

    private var accent: Color { draft.accent }
    private var complete: Bool { shortcutConfirmed && backTapConfirmed && consentAccepted }

    private var greeting: String {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if complete { return name.isEmpty ? String(localized: "C'est prêt !") : String(localized: "Prêt, \(name) !") }
        return name.isEmpty ? String(localized: "Ton TapTap est prêt.") : String(localized: "Ton TapTap est prêt, \(name).")
    }

    var body: some View {
        GeometryReader { geo in
            let hero = TapTapScale.hero(geo.size) * 0.95
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                Text(greeting)
                    .font(HZ.Fonts.fig(31, .heavy)).foregroundStyle(HZ.Colors.ink)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .opacity(arrived ? 1 : 0)

                Text(complete
                     ? String(localized: "Tu n'as plus qu'à taper deux fois au dos de ton téléphone, dans n'importe quelle conversation.")
                     : String(localized: "Il reste à activer le geste (une minute). Tu peux le faire maintenant, ou depuis l'accueil."))
                    .font(HZ.Fonts.fig(15.5, .medium)).foregroundStyle(HZ.Colors.sub)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10).padding(.horizontal, 6)
                    .opacity(arrived ? 1 : 0)

                Spacer(minLength: 10)

                ZStack {
                    BubbleBurst(accent: accent, fired: burst)
                    // Il arrive par le sol : la scène part d'un pouf (le plongeon de l'écran précédent l'a emmené sous terre).
                    TapTapSlot(height: hero, beats: beats, accent: accent, transit: .pouf)
                }

                Spacer(minLength: 10)

                HStack(spacing: 10) {
                    rewardTile(value: "\(draft.hoursPerYear)", label: String(localized: "heures par an"))
                    rewardTile(value: "1", label: String(localized: "geste à retenir"))
                    rewardTile(value: "0", label: String(localized: "app à ouvrir"))
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 14)

                Spacer(minLength: 14)

                if complete, let onTest {
                    OnbButton(title: String(localized: "Tester pour de vrai, au dos de mon iPhone"), icon: "hand.tap.fill", fill: accent, action: onTest)
                    OnbLink(title: String(localized: "Plus tard, voir l'app")) { onNext() }.padding(.top, 10)
                } else {
                    OnbButton(title: String(localized: "Utiliser TapReply"), icon: "arrow.right", fill: accent, action: onNext)
                }
                if !complete {
                    OnbLink(title: String(localized: "Terminer l'activation maintenant")) {
                        (onFinishSetup ?? onNext)()
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 26)
            .task {
                try? await Task.sleep(for: .milliseconds(650))
                burst = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(duration: 0.5)) { arrived = true }
                try? await Task.sleep(for: .milliseconds(complete ? 2_600 : 900))
                withAnimation(.spring(duration: 0.6)) { revealed = true }
            }
        }
    }

    private var beats: [TapTapBeat] {
        if complete {
            return [.play(TapTapClips.jaillitDuSol, speed: 1.35), .play(TapTapClips.danseClap, speed: 1.15), .loop(TapTapClips.reposHeureux)]
        }
        return [.play(TapTapClips.jaillitDuSol, speed: 1.35), .play(TapTapClips.presente, speed: 1.1, holdMs: 1_200), .loop(TapTapClips.idle)]
    }

    private func rewardTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(verbatim: value).font(HZ.Fonts.fig(26, .heavy)).foregroundStyle(accent).monospacedDigit()
            Text(label).font(HZ.Fonts.fig(11.5, .semibold)).foregroundStyle(HZ.Colors.sub)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.75)))
    }
}
