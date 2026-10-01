import SwiftUI

/// GUIDE ANIMÉ « Toucher le dos de l'appareil » (v1.1.1).
///
/// POURQUOI : iOS n'expose AUCUNE API publique pour ouvrir la page
/// Accessibilité des Réglages (confirmé Apple DTS ; le scheme privé
/// `App-Prefs:` est un motif de rejet 2.5.1 et ne fonctionne plus depuis
/// iOS 18). Plutôt qu'un bouton qui atterrit au mauvais endroit, on MONTRE
/// le chemin : un iPhone rejoue en boucle les 5 tapes à faire.
///
/// Écrans reproduits d'après les VRAIES captures de Pierre (21/08) : mêmes
/// libellés, mêmes valeurs à droite, même ordre, mêmes en-têtes de section.
///
/// Anti-largage : sous l'iPhone, un fil d'étapes 1→5 CLIQUABLE. L'utilisateur
/// qui décroche touche une étape, l'animation s'y fige et le texte détaille le
/// geste (« descends tout en bas… »). Un bouton relance la lecture auto.
struct BackTapAnimationView: View {

    // MARK: - Modèle d'écran

    private enum Trailing {
        case chevron
        case value(String)
        case toggle(Bool)
        case check
        case none
    }

    private struct Row: Identifiable {
        let id: Int
        let label: String
        var icon: String? = nil
        var iconTint: Color = .clear
        var trailing: Trailing = .chevron
        var isTarget: Bool = false
    }

    private struct Group {
        var header: String? = nil
        var rows: [Row]
    }

    private struct ScreenSpec {
        let navTitle: String
        let showsBack: Bool
        let groups: [Group]
        /// Défilement simulé (points) pour amener la cible sous les yeux
        let scroll: CGFloat
        let caption: String
    }

    // MARK: - État

    @State private var index = 0          // 0...4
    @State private var scrolled = false
    @State private var tapped = false
    @State private var selected = false   // coche finale
    @State private var paused = false

    private let stepCount = 5
    // Proportions d'un vrai iPhone (≈ 19,5:9) : l'ancien cadre était trop
    // large et faisait « iPad ». Pas de Dynamic Island non plus : le texte
    // passait dessous et ça salissait le visuel (retour Pierre 21/08).
    private let phoneW: CGFloat = 212
    private let phoneH: CGFloat = 452

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            phone
            stepper
        }
        .task { await autoplay() }
    }

    // MARK: - L'iPhone

    private var phone: some View {
        let spec = spec(index)
        return VStack(spacing: 0) {
            // Barre de statut (réalisme, comme sur les captures)
            HStack {
                Text("9:41")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75")
                }
                .font(.system(size: 9))
            }
            .foregroundStyle(DS.Colors.ink)
            .padding(.horizontal, 16)
            .padding(.top, 9)
            .padding(.bottom, 3)

            // Barre de navigation : bouton retour rond + titre centré
            ZStack {
                Text(spec.navTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 34)
                if spec.showsBack {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Colors.ink)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.white))
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)

            // La liste
            ZStack(alignment: .top) {
                Color(hex: 0xEFEFF4)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(spec.groups.enumerated()), id: \.offset) { _, group in
                        if let header = group.header {
                            Text(header)
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color(hex: 0x8A8A8E))
                                .padding(.leading, 12)
                                .padding(.bottom, -4)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(group.rows.enumerated()), id: \.offset) { i, row in
                                rowView(row)
                                if i < group.rows.count - 1 {
                                    Divider().padding(.leading, row.icon == nil ? 10 : 36)
                                }
                            }
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
                .padding(.horizontal, 9)
                .padding(.top, 8)
                .offset(y: scrolled ? -spec.scroll : 0)
                .animation(.easeInOut(duration: 0.85), value: scrolled)
            }
            .clipped()
        }
        .frame(width: phoneW, height: phoneH)
        .background(Color(hex: 0xEFEFF4))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(DS.Colors.ink, lineWidth: 5)
        )
        .animation(.easeInOut(duration: 0.3), value: index)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 7) {
            // Icône UNIQUEMENT sur la ligne à toucher (sauf écran Réglages,
            // où iOS en affiche partout) — la cible saute aux yeux.
            if let icon = row.icon {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(row.iconTint)
                    .frame(width: 19, height: 19)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            Text(row.label)
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            trailingView(row)
        }
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(row.isTarget && tapped ? Color(hex: 0xD8D8DD) : .white)
        .overlay(alignment: .trailing) {
            // Le doigt qui appuie
            if row.isTarget && tapped {
                Circle()
                    .fill(DS.Colors.blue.opacity(0.25))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(DS.Colors.blue, lineWidth: 1.8))
                    .offset(x: -30)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: tapped)
    }

    @ViewBuilder
    private func trailingView(_ row: Row) -> some View {
        // Dernier écran : la sélection pose une COCHE bleue, pas un chevron
        // (ça ne mène nulle part — correction 21/08).
        if row.isTarget && index == 4 {
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Colors.blue)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        } else {
            switch row.trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC4C4C6))
            case .value(let v):
                HStack(spacing: 3) {
                    Text(v)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: 0x8A8A8E))
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xC4C4C6))
                }
            case .toggle(let on):
                Capsule()
                    .fill(on ? Color(hex: 0x34C759) : Color(hex: 0xD1D1D6))
                    .frame(width: 27, height: 16)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 13, height: 13).padding(1.5)
                    }
            case .check:
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Colors.blue)
            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Le fil d'étapes (anti-largage)

    private var stepper: some View {
        VStack(spacing: 7) {
            // Pastilles cliquables 1 → 5
            HStack(spacing: 7) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Button {
                        paused = true
                        jump(to: i)
                    } label: {
                        Text("\(i + 1)")
                            .font(DS.Fonts.body(12, weight: .bold))
                            .foregroundStyle(i == index ? .white : DS.Colors.ink)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(i == index ? DS.Colors.blue : DS.Colors.surface)
                            )
                    }
                    .buttonStyle(.plain)
                    if i < stepCount - 1 {
                        Rectangle()
                            .fill(DS.Colors.divider)
                            .frame(width: 10, height: 1.5)
                    }
                }
            }

            // Consigne détaillée de l'étape en cours
            Text(spec(index).caption)
                .font(DS.Fonts.body(13, weight: .medium))
                .foregroundStyle(DS.Colors.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36, alignment: .top)
                .animation(.easeInOut(duration: 0.2), value: index)

            if paused {
                Button {
                    paused = false
                } label: {
                    Label(String(localized: "Relancer l'animation"), systemImage: "play.fill")
                        .font(DS.Fonts.body(12, weight: .semibold))
                        .foregroundStyle(DS.Colors.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.s)
    }

    private func jump(to i: Int) {
        index = i
        scrolled = true       // on montre directement la cible
        tapped = false
        selected = i == 4
    }

    // MARK: - Lecture automatique

    @MainActor
    private func autoplay() async {
        while !Task.isCancelled {
            if paused {
                try? await Task.sleep(nanoseconds: 250_000_000)
                continue
            }
            // Mise en place de l'étape
            scrolled = false
            tapped = false
            selected = false
            guard await wait(0.55) else { return }
            if paused { continue }

            if spec(index).scroll > 0 {
                scrolled = true
                guard await wait(0.9) else { return }
                if paused { continue }
            }
            tapped = true
            guard await wait(0.5) else { return }
            if paused { continue }

            if index == stepCount - 1 {
                selected = true
                guard await wait(1.8) else { return }
            } else {
                guard await wait(0.35) else { return }
            }
            if paused { continue }
            index = (index + 1) % stepCount
        }
    }

    /// Sommeil annulable : `false` si la vue a disparu.
    private func wait(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }

    // MARK: - Les 5 écrans (fidèles aux captures)

    private func spec(_ i: Int) -> ScreenSpec {
        switch i {

        // 1 · Réglages → Accessibilité (juste sous Général)
        case 0:
            return ScreenSpec(
                navTitle: String(localized: "Réglages"),
                showsBack: false,
                groups: [
                    Group(rows: [
                        Row(id: 0, label: String(localized: "Mode Avion"), icon: "airplane",
                            iconTint: Color(hex: 0xE8863C), trailing: .toggle(false)),
                        Row(id: 1, label: "Wi-Fi", icon: "wifi",
                            iconTint: Color(hex: 0x1E7BF7), trailing: .value("Freebox")),
                        Row(id: 2, label: "Bluetooth", icon: "dot.radiowaves.right",
                            iconTint: Color(hex: 0x1E7BF7), trailing: .value(String(localized: "Oui"))),
                        Row(id: 3, label: String(localized: "Données cellulaires"), icon: "antenna.radiowaves.left.and.right",
                            iconTint: Color(hex: 0x34A853)),
                        Row(id: 4, label: String(localized: "Batterie"), icon: "battery.100",
                            iconTint: Color(hex: 0x34A853))
                    ]),
                    Group(rows: [
                        Row(id: 5, label: String(localized: "Général"), icon: "gearshape.fill",
                            iconTint: Color(hex: 0x8E8E93)),
                        Row(id: 6, label: String(localized: "Accessibilité"), icon: "figure.arms.open",
                            iconTint: Color(hex: 0x1E7BF7), isTarget: true)
                    ])
                ],
                scroll: 62,
                caption: String(localized: "1. Ouvre Réglages et touche Accessibilité, juste sous Général.")
            )

        // 2 · Accessibilité → Toucher (section « Physique et motricité »)
        case 1:
            return ScreenSpec(
                navTitle: String(localized: "Accessibilité"),
                showsBack: true,
                groups: [
                    Group(rows: [
                        Row(id: 0, label: "VoiceOver", trailing: .value(String(localized: "Non"))),
                        Row(id: 1, label: "Zoom", trailing: .value(String(localized: "Non"))),
                        Row(id: 2, label: String(localized: "Survol de texte"), trailing: .value(String(localized: "Non"))),
                        Row(id: 3, label: String(localized: "Affichage et taille du texte")),
                        Row(id: 4, label: String(localized: "Animation")),
                        Row(id: 5, label: String(localized: "Lire et énoncer"))
                    ]),
                    Group(header: String(localized: "Physique et motricité"), rows: [
                        Row(id: 6, label: String(localized: "Toucher"), icon: "hand.point.up.left.fill",
                            iconTint: Color(hex: 0x1E7BF7), isTarget: true),
                        Row(id: 7, label: String(localized: "Face ID et attention")),
                        Row(id: 8, label: String(localized: "Contrôle de sélection"), trailing: .value(String(localized: "Non"))),
                        Row(id: 9, label: String(localized: "Contrôle vocal"), trailing: .value(String(localized: "Non")))
                    ])
                ],
                scroll: 96,
                caption: String(localized: "2. Descends jusqu'à « Physique et motricité », puis touche Toucher.")
            )

        // 3 · Toucher → Toucher le dos de l'appareil (tout en bas)
        case 2:
            return ScreenSpec(
                navTitle: String(localized: "Toucher"),
                showsBack: true,
                groups: [
                    Group(rows: [
                        Row(id: 0, label: "AssistiveTouch", trailing: .value(String(localized: "Non"))),
                        Row(id: 1, label: String(localized: "Toucher sur l'écran"), trailing: .value(String(localized: "Non"))),
                        Row(id: 2, label: String(localized: "Vibration"), trailing: .toggle(true)),
                        Row(id: 3, label: String(localized: "Ne pas raccrocher au verrouillage"), trailing: .toggle(false)),
                        Row(id: 4, label: String(localized: "Sortie des appels"), trailing: .value(String(localized: "Automatique")))
                    ]),
                    Group(rows: [
                        Row(id: 5, label: String(localized: "Toucher le dos de l'appareil"), icon: "iphone",
                            iconTint: Color(hex: 0x1E7BF7), trailing: .value(String(localized: "Non")), isTarget: true)
                    ])
                ],
                scroll: 78,
                caption: String(localized: "3. Descends tout en bas, puis touche « Toucher le dos de l'appareil ».")
            )

        // 4 · Toucher le dos → Toucher 2 fois
        case 3:
            return ScreenSpec(
                navTitle: String(localized: "Toucher le dos de l'appareil"),
                showsBack: true,
                groups: [
                    Group(rows: [
                        Row(id: 0, label: String(localized: "Toucher 2 fois"), icon: "hand.tap.fill",
                            iconTint: Color(hex: 0x1E7BF7), trailing: .value(String(localized: "Aucun")), isTarget: true),
                        Row(id: 1, label: String(localized: "Toucher 3 fois"), trailing: .value(String(localized: "Aucun")))
                    ]),
                    Group(rows: [
                        Row(id: 2, label: String(localized: "Afficher la bannière"), trailing: .toggle(true))
                    ])
                ],
                scroll: 0,
                caption: String(localized: "4. Touche « Toucher 2 fois ».")
            )

        // 5 · Toucher 2 fois → TapReply (section Raccourcis, tout en bas)
        default:
            return ScreenSpec(
                navTitle: String(localized: "Toucher 2 fois"),
                showsBack: true,
                groups: [
                    Group(rows: [
                        Row(id: 0, label: String(localized: "Sous-titres en direct"), trailing: .none),
                        Row(id: 1, label: "VoiceOver", trailing: .none),
                        Row(id: 2, label: "Zoom", trailing: .none)
                    ]),
                    Group(header: String(localized: "Gestes de défilement"), rows: [
                        Row(id: 3, label: String(localized: "Faire défiler vers le bas"), trailing: .none),
                        Row(id: 4, label: String(localized: "Faire défiler vers le haut"), trailing: .none)
                    ]),
                    Group(header: String(localized: "Raccourcis"), rows: [
                        Row(id: 5, label: String(localized: "Prendre une pause"), trailing: .none),
                        Row(id: 6, label: String(localized: "Raccourci Shazam"), trailing: .none),
                        Row(id: 7, label: "TapReply", trailing: .none, isTarget: true)
                    ])
                ],
                scroll: 118,
                caption: String(localized: "5. Descends tout en bas, section Raccourcis, et sélectionne TapReply.")
            )
        }
    }
}

#Preview {
    BackTapAnimationView().padding()
}
