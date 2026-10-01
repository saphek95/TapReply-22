import SwiftUI
import UserNotifications

// =============================================================================
// ACTE 5 — LE VRAI GESTE (le professeur)
// =============================================================================
//
// TapTap pouf, réapparaît Guide à gauche, sort des lunettes trop grandes qui
// glissent, les remonte, sort son pointeur : c'est le professeur. Un tableau
// noir porte les trois étapes ; il coche celles que l'utilisateur confirme —
// jamais celles qu'il déclare vouloir faire plus tard (honnêteté).
//
// Les écrans système sont redessinés (Raccourcis, chemin des Réglages, alerte
// « Toujours autoriser ») : traduisibles, légers, et le pointeur peut désigner.
// =============================================================================

/// L'état partagé du tableau noir pendant l'acte 5 (les coches restent visibles d'un écran à l'autre).
final class Onb3Board: ObservableObject {
    static let shared = Onb3Board()
    @Published var done: [Bool] = [false, false, false]
}

/// La rangée haute commune : TapTap professeur à gauche (Guide), le tableau à droite.
struct ProfessorRow: View {
    var beats: [TapTapBeat]
    var accent: Color
    var revealed: Int
    var transit: TapTapTransit = .cut
    @ObservedObject private var board = Onb3Board.shared
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let guide = TapTapScale.guide(geo.size) * 0.95
            HStack(alignment: .bottom, spacing: 10) {
                // Le pouf ne sert qu'à l'ARRIVÉE dans l'acte ; ensuite, quand le tableau grandit, il descend avec lui (glisse).
                TapTapSlot(height: guide, beats: beats, accent: accent, transit: appeared ? .cut : transit)
                    .onAppear { Task { @MainActor in try? await Task.sleep(for: .milliseconds(600)); appeared = true } }
                Chalkboard(lines: [.init(id: 0, text: String(localized: "Ajouter le raccourci"), cost: String(localized: "30 s"), done: board.done[0]),
                                   .init(id: 1, text: String(localized: "Activer le double tap au dos"), cost: String(localized: "30 s"), done: board.done[1]),
                                   .init(id: 2, text: String(localized: "Répondre « Toujours autoriser »"), cost: nil, done: board.done[2])],
                           revealed: revealed, accent: accent)
            }
        }
        .frame(height: 176)
    }
}

// MARK: - S12 · Le plan

struct Onb3SetupIntro: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void
    @State private var revealed = 0
    @State private var pointing = 0
    private var accent: Color { draft.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbTypewriter(text: String(localized: "Il reste trois réglages.\nUne minute, et c'est à toi."), font: HZ.Fonts.fig(27, .heavy))
                .padding(.top, 10)
            Text(String(localized: "Ce sont des réglages d'iOS, pas de l'application. Je ne peux pas les faire à ta place, mais je te montre exactement où aller."))
                .font(HZ.Fonts.fig(15, .medium)).foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            ProfessorRow(beats: beats, accent: accent, revealed: revealed, transit: .pouf)
                .padding(.top, 22)
                .onChange(of: revealed) { _, _ in }

            Spacer(minLength: 14)

            Text(String(localized: "Après ça, je travaille tout seul. Tu n'ouvriras plus jamais l'app pour répondre."))
                .font(HZ.Fonts.fig(14.5, .semibold)).foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            OnbButton(title: String(localized: "On y va"), icon: "arrow.right", fill: accent, enabled: revealed >= 3, action: onNext)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .task {
            // Jamais pré-coché : même si l'app connaît déjà ces réglages, l'onboarding propose de les (re)faire ;
            // seule une confirmation sur les écrans qui suivent coche une ligne.
            Onb3Board.shared.done = [false, false, false]
            // Il met ses lunettes (≈ 3,3 s ×1,3), puis pointe chaque ligne quand elle apparaît.
            try? await Task.sleep(for: .milliseconds(3_600))
            for i in 1...3 {
                revealed = i; pointing = i
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
    }

    private var beats: [TapTapBeat] {
        if pointing == 0 { return [.play(TapTapClips.metLunettes, speed: 1.3), .still(TapTapClips.metLunettes)] }
        return [.play(TapTapClips.pointe, speed: 1.4, holdMs: 300), .still(TapTapClips.metLunettes)]
    }
}

// MARK: - S13 · Le raccourci

struct Onb3SetupShortcut: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @AppStorage(SettingsKeys.shortcutConfirmed) private var confirmed = false
    @State private var opened = false
    @State private var confirming = false
    @State private var declining = false
    @Environment(\.openURL) private var openURL
    private var accent: Color { draft.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbStepBadge(text: String(localized: "ÉTAPE 1 SUR 3"), accent: accent).padding(.top, 6)
            Text(String(localized: "Ajoute le raccourci")).font(HZ.Fonts.fig(26, .heavy)).foregroundStyle(HZ.Colors.ink).padding(.top, 8)
            Text(String(localized: "Le bouton ouvre l'app Raccourcis. Touche « Ajouter le raccourci », puis reviens ici. Ne le renomme pas."))
                .font(HZ.Fonts.fig(14.5, .medium)).foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 6)

            ProfessorRow(beats: beats, accent: accent, revealed: 3).padding(.top, 14)

            Spacer(minLength: 10)

            // La fiche de l'app Raccourcis, reconstituée. Toute la carte ouvre l'app.
            VStack(spacing: 0) {
                VStack(spacing: 9) {
                    Image("IconPreviewViolet").resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: HZ.Colors.ink.opacity(0.16), radius: 12, y: 5)
                    Text(verbatim: ToneTrigger.doubleTap.shortcutName).font(HZ.Fonts.fig(16, .bold)).foregroundStyle(HZ.Colors.ink)
                    Text(String(localized: "Raccourci")).font(HZ.Fonts.fig(12.5, .medium)).foregroundStyle(HZ.Colors.faint)
                }
                .padding(.top, 18).padding(.bottom, 14)
                HStack(spacing: 7) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 15, weight: .semibold))
                    Text(String(localized: "Ajouter le raccourci")).font(HZ.Fonts.fig(15.5, .semibold))
                }
                .foregroundStyle(.white).padding(.horizontal, 20).frame(height: 44)
                .background(Capsule().fill(Color(hex: 0x0A84FF)))
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(HZ.Colors.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture { install() }
            .accessibilityAddTraits(.isButton)

            Spacer(minLength: 12)

            if opened {
                OnbButton(title: String(localized: "Oui, je l'ai ajouté"), icon: "checkmark", fill: accent, enabled: !confirming) {
                    confirmed = true; confirming = true
                    Analytics.track("setup", ["what": "shortcut", "value": "done"])
                    withAnimation(.spring(duration: 0.35)) { Onb3Board.shared.done[0] = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(650)); onNext() }
                }
                OnbLink(title: String(localized: "Rouvrir l'app Raccourcis")) { install() }.padding(.top, 10)
            } else {
                OnbButton(title: String(localized: "Ouvrir l'app Raccourcis"), icon: "arrow.up.forward", fill: accent, enabled: !declining) { install() }
                OnbLink(title: String(localized: "Je le ferai plus tard")) {
                    guard !declining && !confirming else { return }
                    declining = true
                    Analytics.track("setup", ["what": "backtap", "value": "later"])
                    Analytics.track("setup", ["what": "shortcut", "value": "later"])
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(800)); onNext() }
                }.padding(.top, 10)
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .animation(.spring(duration: 0.45), value: opened)
    }

    private var beats: [TapTapBeat] {
        if confirming { return [.play(TapTapClips.coche, speed: 1.5), .still(TapTapClips.metLunettes)] }
        if declining { return [.play(TapTapClips.hausseEpaules, speed: 1.1)] }
        if opened { return [.loop(TapTapClips.attendLaPorte)] }
        return [.play(TapTapClips.pointe, speed: 1.3, holdMs: 600), .still(TapTapClips.metLunettes)]
    }

    private func install() {
        if let url = Config.shortcutInstallURL { openURL(url) }
        opened = true
    }
}

// MARK: - S14 · Le double tap au dos

struct Onb3SetupBackTap: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @AppStorage(SettingsKeys.backTapConfirmed) private var confirmed = false
    @State private var opened = false
    @State private var highlight = 0
    @State private var confirming = false
    @State private var declining = false
    private var accent: Color { draft.accent }

    private var path: [(icon: String, tint: Color, label: String, value: String?, hint: String?)] {
        [("accessibility", Color(hex: 0x0A84FF), String(localized: "Accessibilité"), nil, nil),
         ("hand.point.up.left.fill", Color(hex: 0x0A84FF), String(localized: "Toucher"), nil, nil),
         ("iphone.gen3", HZ.Colors.sub, String(localized: "Toucher le dos de l'appareil"), String(localized: "Désactivé"), String(localized: "tout en bas de la page")),
         ("hand.tap.fill", HZ.Colors.sub, String(localized: "Double toucher"), nil, nil),
         ("bolt.fill", accent, String(localized: "TapReply"), nil, String(localized: "fais défiler jusqu'en bas de la liste"))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbStepBadge(text: String(localized: "ÉTAPE 2 SUR 3"), accent: accent).padding(.top, 6)
            Text(String(localized: "Active le double tap")).font(HZ.Fonts.fig(26, .heavy)).foregroundStyle(HZ.Colors.ink).padding(.top, 8)
            Text(String(localized: "Dans les Réglages d'iOS, suis ce chemin. La dernière ligne, c'est TapReply : coche-la."))
                .font(HZ.Fonts.fig(14.5, .medium)).foregroundStyle(HZ.Colors.sub)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 6)

            ProfessorRow(beats: beats, accent: accent, revealed: 3).padding(.top, 12)

            VStack(spacing: 6) {
                ForEach(Array(path.enumerated()), id: \.offset) { i, row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 9) {
                            Text(verbatim: "\(i + 1)").font(HZ.Fonts.fig(12, .bold))
                                .foregroundStyle(i == highlight ? accent : HZ.Colors.faint).frame(width: 14)
                            SettingsRow(icon: row.icon, iconTint: row.tint, label: row.label, value: row.value, highlighted: i == highlight)
                        }
                        if let hint = row.hint {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down").font(.system(size: 10, weight: .bold))
                                Text(hint).font(HZ.Fonts.fig(12, .semibold))
                            }
                            .foregroundStyle(accent).padding(.leading, 23)
                        }
                    }
                }
            }
            .padding(.top, 12)

            Spacer(minLength: 10)

            if opened {
                OnbButton(title: String(localized: "Oui, TapReply est coché"), icon: "checkmark", fill: accent, enabled: !confirming) {
                    confirmed = true; confirming = true
                    Analytics.track("setup", ["what": "backtap", "value": "done"])
                    withAnimation(.spring(duration: 0.35)) { Onb3Board.shared.done[1] = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(650)); onNext() }
                }
                OnbLink(title: String(localized: "Rouvrir les Réglages")) { openSettings() }.padding(.top, 10)
            } else {
                OnbButton(title: String(localized: "Ouvrir les Réglages"), icon: "arrow.up.forward", fill: accent, enabled: !declining) { openSettings() }
                OnbLink(title: String(localized: "Je le ferai plus tard")) {
                    guard !declining && !confirming else { return }
                    declining = true
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(1_000)); onNext() }
                }.padding(.top, 10)
            }
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .padding(.bottom, 24)
        .animation(.spring(duration: 0.45), value: opened)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_100))
                withAnimation(.easeInOut(duration: 0.35)) { highlight = (highlight + 1) % path.count }
            }
        }
    }

    private var beats: [TapTapBeat] {
        if confirming { return [.play(TapTapClips.coche, speed: 1.5), .still(TapTapClips.metLunettes)] }
        if declining { return [.play(TapTapClips.hausseEpaules, speed: 1.1)] }
        if opened { return [.loop(TapTapClips.attendLaPorte)] }
        return [.play(TapTapClips.pointe, speed: 1.3, holdMs: 600), .still(TapTapClips.metLunettes)]
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        opened = true
    }
}

// MARK: - S15 · « Toujours autoriser »

struct Onb3Permissions: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void

    @State private var pulse = false
    @State private var signUp = false
    private var accent: Color { draft.accent }

    var body: some View {
        GeometryReader { geo in
            let guide = TapTapScale.guide(geo.size) * 0.95
            VStack(alignment: .leading, spacing: 0) {
                OnbStepBadge(text: String(localized: "ÉTAPE 3 SUR 3 · AVANT TON PREMIER TAP"), accent: accent).padding(.top, 6)
                Text(String(localized: "Astuce : « Toujours autoriser »")).font(HZ.Fonts.fig(26, .heavy)).foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                Text(String(localized: "À ton premier double tap, Raccourcis te demandera l'autorisation d'utiliser TapReply. « Toujours autoriser » évite que la question revienne à chaque fois ; tu peux aussi choisir « Autoriser une fois »."))
                    .font(HZ.Fonts.fig(14.5, .medium)).foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 6)

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 12) {
                    // Le professeur brandit une pancarte — dessinée par l'app, posée exactement entre ses mains
                    // (la planche du clip a été retirée) : le texte suit la pancarte, il en fait partie.
                    TapTapRectSlot(canvasRect: TapTapClips.signBoard,
                                   beats: [.play(TapTapClips.branditPancarte, speed: 1.25), .still(TapTapClips.branditPancarte)],
                                   accent: accent, transit: .cut, behindContent: true, occluderRadius: guide * 0.06) {
                        SignBoard(text: String(localized: "Toujours autoriser"), width: guide * 0.98, accent: accent)
                            .opacity(signUp ? 1 : 0)
                            .scaleEffect(signUp ? 1 : 0.7, anchor: .bottom)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: signUp)
                    }
                    .padding(.bottom, guide * 0.98)   // la pancarte est au-dessus de sa tête : on réserve sa hauteur dessous

                    // Illustration de la demande iOS (non interactive, sans pression : c'est un conseil, pas un choix forcé).
                    VStack(spacing: 0) {
                        VStack(spacing: 5) {
                            Image(systemName: "camera.viewfinder").font(.system(size: 20)).foregroundStyle(HZ.Colors.sub)
                            Text(String(localized: "« Raccourcis » souhaite utiliser TapReply"))
                                .font(HZ.Fonts.fig(13.5, .semibold)).foregroundStyle(HZ.Colors.ink)
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 12)
                        Rectangle().fill(HZ.Colors.line).frame(height: 1)
                        Text(String(localized: "Autoriser une fois"))
                            .font(HZ.Fonts.fig(14.5, .regular)).foregroundStyle(HZ.Colors.faint)
                            .frame(maxWidth: .infinity).frame(height: 42)
                        Rectangle().fill(HZ.Colors.line).frame(height: 1)
                        Text(String(localized: "Toujours autoriser"))
                            .font(HZ.Fonts.fig(15, .bold)).foregroundStyle(accent)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(accent.opacity(pulse ? 0.12 : 0.06))
                    }
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(HZ.Colors.line, lineWidth: 1))
                    .overlay(alignment: .bottom) {
                        Text(String(localized: "Illustration")).font(HZ.Fonts.fig(10.5, .semibold)).foregroundStyle(HZ.Colors.faint)
                            .offset(y: 16)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Illustration de la demande d'autorisation d'iOS"))
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                    Text(String(localized: "Avec « Autoriser une fois », iOS te reposera simplement la question à chaque réponse."))
                        .font(HZ.Fonts.fig(13.5, .medium)).foregroundStyle(HZ.Colors.sub).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)

                Spacer(minLength: 12)

                OnbButton(title: String(localized: "Continuer"), icon: "arrow.right", fill: accent) {
                    Onb3Board.shared.done[2] = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onNext()
                }
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 24)
            .task {
                try? await Task.sleep(for: .milliseconds(1_900))
                signUp = true
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.9)) { pulse.toggle() }
                    try? await Task.sleep(for: .milliseconds(900))
                }
            }
        }
    }
}

// MARK: - S16 · Être prévenu

struct Onb3Notifications: View {
    @Binding var draft: OnbDraft
    let onNext: () -> Void
    @State private var declining = false
    @State private var asking = false
    private var accent: Color { draft.accent }

    var body: some View {
        GeometryReader { geo in
            let guide = TapTapScale.guide(geo.size)
            VStack(alignment: .leading, spacing: 0) {
                OnbTypewriter(text: String(localized: "Je peux te prévenir\nquand ta réponse est prête ?"), font: HZ.Fonts.fig(27, .heavy))
                    .padding(.top, 10)
                Text(String(localized: "Uniquement quand TU as demandé une réponse. Jamais de promotion, jamais de rappel, jamais rien d'autre."))
                    .font(HZ.Fonts.fig(15, .medium)).foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 8)

                Spacer(minLength: 12)

                HStack(alignment: .bottom, spacing: 14) {
                    TapTapSlot(height: guide, beats: declining ? [.play(TapTapClips.hausseEpaules, speed: 1.1)] : [.play(TapTapClips.cloche, speed: 1.15), .still(TapTapClips.cloche)],
                               accent: accent, transit: .cut)
                    // La notification telle qu'elle arrivera.
                    OnbIsland(phase: .ready, reply: String(localized: "Oui carrément, 18h comme prévu !"), accent: accent, mascotColor: accent)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, guide * 0.35)
                }

                Spacer(minLength: 12)

                OnbButton(title: String(localized: "D'accord, prévenez-moi"), icon: "bell.fill", fill: accent, enabled: !asking && !declining) {
                    guard !asking, !declining else { return }
                    asking = true
                    Analytics.track("setup", ["what": "notifications", "value": "done"])
                    Task {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                        await MainActor.run { onNext() }
                    }
                }
                OnbLink(title: String(localized: "Non merci")) {
                    guard !asking, !declining else { return }
                    declining = true
                    Analytics.track("setup", ["what": "notifications", "value": "later"])
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(1_000)); onNext() }
                }.padding(.top, 10)
            }
            .padding(.horizontal, HZ.Spacing.gutter)
            .padding(.bottom, 24)
        }
    }
}
