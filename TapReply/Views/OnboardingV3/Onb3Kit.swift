import SwiftUI

// =============================================================================
// ONBOARDING V3 — LES BRIQUES PROPRES AU NOUVEAU RÉCIT
// =============================================================================
//
// Tout ce qui existait dans OnbKit (bulle, machine à écrire, boutons,
// progression, double tap, lignes de Réglages, rideau) est réutilisé tel quel.
// Ici : ce dont le récit v2 a besoin en plus.
// =============================================================================

// MARK: - La conversation dans la dalle de l'iPhone géant (le téléphone lui-même : Onb3Phone.swift)

/// Le contenu de conversation dans la dalle géante : en-tête, bulles, champ. Même grammaire que MiniBubble,
/// à l'échelle de la dalle (plus grande que le PhoneFrame de V2).
struct GiantConversation: View {
    var width: CGFloat
    var contact: String = String(localized: "Marie")
    var received: [String]
    var typedDraft: String = ""
    var draftLabel: Bool = false
    var reply: String? = nil
    var replySent: Bool = false
    var working: Bool = false
    var accent: Color
    var highlightWords: [String] = []

    private var s: CGFloat { width / 230 }   // échelle typographique

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8 * s) {
                Circle().fill(accent.opacity(0.16)).frame(width: 26 * s, height: 26 * s)
                    .overlay(Text(String(contact.prefix(1))).font(HZ.Fonts.fig(12.5 * s, .bold)).foregroundStyle(accent))
                Text(contact).font(HZ.Fonts.fig(14 * s, .bold)).foregroundStyle(HZ.Colors.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12 * s)
            .padding(.bottom, 8 * s)
            Divider().overlay(HZ.Colors.line)

            VStack(spacing: 8 * s) {
                ForEach(Array(received.enumerated()), id: \.offset) { _, t in
                    bubble(t, mine: false)
                }
                if working {
                    HStack { Spacer(minLength: 30 * s); TypingDots(accent: accent).scaleEffect(s, anchor: .trailing) }
                        .transition(.opacity)
                }
                if let reply, replySent {
                    bubble(reply, mine: true)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal, 10 * s)
            .padding(.top, 10 * s)

            Spacer(minLength: 0)

            // Le champ de saisie : vide, brouillon, ou réponse prête.
            VStack(alignment: .leading, spacing: 4 * s) {
                if draftLabel && !typedDraft.isEmpty && reply == nil {
                    HStack(spacing: 4 * s) {
                        Image(systemName: "lock.fill").font(.system(size: 9 * s, weight: .bold))
                        Text(String(localized: "Brouillon · pas envoyé")).font(HZ.Fonts.fig(10.5 * s, .bold))
                    }
                    .foregroundStyle(HZ.Colors.faint)
                    .padding(.leading, 10 * s)
                    .transition(.opacity)
                }
                HStack(spacing: 6 * s) {
                    fieldText
                        .font(HZ.Fonts.fig(12 * s, (reply != nil || !typedDraft.isEmpty) ? .medium : .regular))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20 * s))
                        .foregroundStyle(reply != nil && !replySent ? accent : HZ.Colors.faint.opacity(0.45))
                }
                .padding(.horizontal, 10 * s)
                .padding(.vertical, 8 * s)
                .background(Capsule().fill(reply != nil && !replySent ? accent.opacity(0.10) : .white))
                .overlay(Capsule().strokeBorder(reply != nil && !replySent ? accent.opacity(0.55) : HZ.Colors.line, lineWidth: 1.3))
            }
            .padding(.horizontal, 10 * s)
            .padding(.bottom, 12 * s)
        }
        .animation(.spring(duration: 0.4), value: replySent)
        .animation(.spring(duration: 0.4), value: working)
    }

    /// Le texte du champ : la réponse (avec les mots du brouillon surlignés), le brouillon, ou l'invite.
    private var fieldText: Text {
        if let reply, !replySent {
            return highlighted(reply)
        }
        if !typedDraft.isEmpty && !replySent {
            return Text(typedDraft).foregroundColor(HZ.Colors.ink)
        }
        return Text(String(localized: "Message")).foregroundColor(HZ.Colors.faint)
    }

    private func highlighted(_ text: String) -> Text {
        guard !highlightWords.isEmpty else { return Text(text).foregroundColor(HZ.Colors.ink) }
        var result = Text("")
        var rest = Substring(text)
        while !rest.isEmpty {
            var hit: (Range<Substring.Index>, String)? = nil
            for w in highlightWords {
                if let r = rest.range(of: w, options: .caseInsensitive), hit == nil || r.lowerBound < hit!.0.lowerBound { hit = (r, w) }
            }
            guard let (r, _) = hit else { result = result + Text(String(rest)).foregroundColor(HZ.Colors.ink); break }
            result = result + Text(String(rest[rest.startIndex..<r.lowerBound])).foregroundColor(HZ.Colors.ink)
            result = result + Text(String(rest[r])).foregroundColor(accent).bold()
            rest = rest[r.upperBound...]
        }
        return result
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: 24 * s) }
            Text(text)
                .font(HZ.Fonts.fig(12 * s, .medium))
                .foregroundStyle(mine ? .white : HZ.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10 * s)
                .padding(.vertical, 8 * s)
                .background(UnevenRoundedRectangle(topLeadingRadius: 13 * s, bottomLeadingRadius: mine ? 13 * s : 4 * s,
                                                   bottomTrailingRadius: mine ? 4 * s : 13 * s, topTrailingRadius: 13 * s, style: .continuous)
                    .fill(mine ? accent : .white))
            if !mine { Spacer(minLength: 24 * s) }
        }
    }
}

// MARK: - La bulle géante de Marie (S4)

struct GiantIncomingBubble: View {
    let text: String
    let sender: String
    var dropped: Bool
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sender.uppercased())
                .font(HZ.Fonts.fig(11.5, .bold)).tracking(1.1)
                .foregroundStyle(accent)
            Text(text)
                .font(HZ.Fonts.fig(22, .bold))
                .foregroundStyle(HZ.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 8, bottomTrailingRadius: 26, topTrailingRadius: 26, style: .continuous)
            .fill(.white))
        .shadow(color: HZ.Colors.ink.opacity(0.10), radius: 22, y: 12)
        .offset(y: dropped ? 0 : -260)
        .opacity(dropped ? 1 : 0)
        .animation(.spring(response: 0.62, dampingFraction: 0.62), value: dropped)
    }
}

/// Le champ vide qui attend, avec son compteur (S4).
struct WaitingField: View {
    var seconds: Int
    var accent: Color
    @State private var on = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Capsule().fill(accent).frame(width: 2.5, height: 18)
                        .opacity(on ? 1 : 0.15)
                        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: on)
                    Text(String(localized: "Écrire un message…"))
                        .font(HZ.Fonts.fig(15, .regular)).foregroundStyle(HZ.Colors.faint)
                    Spacer(minLength: 0)
                }
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 27)).foregroundStyle(accent.opacity(0.35))
            }
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).strokeBorder(HZ.Colors.line, lineWidth: 1))

            HStack(spacing: 6) {
                Image(systemName: "clock").font(.system(size: 12, weight: .semibold))
                Text(verbatim: "\(seconds) s")
                    .font(HZ.Fonts.fig(13, .bold)).monospacedDigit()
            }
            .foregroundStyle(seconds >= 30 ? HZ.Colors.mRed : HZ.Colors.faint)
            .animation(.easeOut(duration: 0.3), value: seconds >= 30)
        }
        .onAppear { on = false }
    }
}

// MARK: - Le tableau noir du professeur (S12–S15)

struct Chalkboard: View {
    struct Line: Identifiable { let id: Int; let text: String; let cost: String?; var done: Bool }
    var lines: [Line]
    var revealed: Int
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(lines) { line in
                if line.id < revealed {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        ZStack {
                            Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.6).frame(width: 22, height: 22)
                            if line.done {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(HZ.Colors.mGreen)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Text(verbatim: "\(line.id + 1)").font(HZ.Fonts.fig(11.5, .bold)).foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        Text(line.text)
                            .font(HZ.Fonts.fig(15.5, .semibold))
                            .foregroundStyle(.white.opacity(line.done ? 0.55 : 0.96))
                            .strikethrough(line.done, color: .white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if let cost = line.cost, !line.done {
                            Text(cost).font(HZ.Fonts.fig(11.5, .bold)).foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(.white.opacity(0.14)))
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x2B3A3A))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: 0x8A5A2B), lineWidth: 6))
        )
        .animation(.spring(duration: 0.45), value: revealed)
    }
}

// MARK: - Les bulles de messages qui éclaboussent (S17)

struct BubbleBurst: View {
    var accent: Color
    var fired: Bool
    private let seeds: [(dx: CGFloat, dy: CGFloat, size: CGFloat, delay: Double)] = [
        (-140, -180, 34, 0), (120, -210, 28, 0.04), (-60, -260, 22, 0.08), (170, -120, 24, 0.02),
        (-190, -90, 20, 0.06), (60, -290, 30, 0.1), (-110, -40, 18, 0.12), (200, -230, 18, 0.05)
    ]
    var body: some View {
        ZStack {
            ForEach(Array(seeds.enumerated()), id: \.offset) { i, s in
                Image(systemName: i % 2 == 0 ? "bubble.left.fill" : "bubble.right.fill")
                    .font(.system(size: s.size))
                    .foregroundStyle(i % 3 == 0 ? .white : accent.mixed(with: .white, amount: 0.35))
                    .offset(x: fired ? s.dx : 0, y: fired ? s.dy : 40)
                    .opacity(fired ? 0 : 0.95)
                    .scaleEffect(fired ? 1.1 : 0.4)
                    .animation(.easeOut(duration: 0.9).delay(s.delay), value: fired)
            }
        }
        .allowsHitTesting(false)
    }
}
