import SwiftUI

/// ACCÈS AUX TONS PERSONNALISÉS (26/09) — une seule règle, un seul langage, partout.
///
/// • Sans abonnement : 1 ton personnalisé. Le « + » porte un cadenas dès qu'il existe ; le toucher EXPLIQUE
///   pourquoi (1 ton gratuit) avant de proposer Pro ou de modifier le ton existant. Jamais un paywall muet.
/// • Avec Pro : tons illimités.
/// • Pro terminé : les tons créés EN PLUS restent (rien n'est supprimé) mais sous cadenas, comme le Triple Tap ;
///   les toucher explique, propose de repasser Pro ou de supprimer le ton.
enum CustomToneAccess {
    /// Abonnement vu sans clignotement (même règle que les gestes Pro du Studio).
    @MainActor static var hasPro: Bool { PurchaseService.shared.isPro || ProAccess.isKnownPro }
}

enum ToneGateAlert: Identifiable {
    case locked(CustomTone)
    case limit
    var id: String {
        switch self {
        case .locked(let t): return "locked-\(t.id)"
        case .limit: return "limit"
        }
    }
}

struct CustomToneGate: ViewModifier {
    @Binding var alert: ToneGateAlert?
    /// « Modifier mon ton » depuis l'alerte de limite : ouvre l'éditeur du ton gratuit existant.
    var onEditFreeTone: ((CustomTone) -> Void)?
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } }), presenting: alert) { a in
                Button(String(localized: "Passer Pro")) { openPaywall() }
                switch a {
                case .locked(let tone):
                    Button(String(localized: "Supprimer ce ton"), role: .destructive) {
                        CustomToneStore.delete(id: tone.id)
                        NotificationCenter.default.post(name: .tapReplyTonesChanged, object: nil)
                    }
                case .limit:
                    if let free = CustomToneStore.freeTone, let onEditFreeTone {
                        Button(String(localized: "Modifier mon ton")) { onEditFreeTone(free) }
                    }
                }
                Button(String(localized: "Annuler"), role: .cancel) {}
            } message: { a in
                switch a {
                case .locked:
                    Text(String(localized: "Sans abonnement, tu as droit à 1 ton personnalisé. Celui-ci est gardé, rien n'est supprimé : repasse Pro pour le retrouver, ou supprime-le."))
                case .limit:
                    Text(String(localized: "Tu as déjà créé ton ton personnalisé gratuit. Passe Pro pour en créer autant que tu veux, ou modifie celui que tu as."))
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywall { showPaywall = false }
                    .background(DS.Colors.page)
            }
    }

    private var title: String {
        switch alert {
        case .locked: return String(localized: "Ce ton fait partie de Pro")
        default:      return String(localized: "1 ton personnalisé gratuit")
        }
    }

    private func openPaywall() {
        Analytics.track("paywall_reason", ["why": "custom_tones"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPaywall = true }
    }
}

extension View {
    func customToneGate(_ alert: Binding<ToneGateAlert?>, onEditFreeTone: ((CustomTone) -> Void)? = nil) -> some View {
        modifier(CustomToneGate(alert: alert, onEditFreeTone: onEditFreeTone))
    }
}

/// Badge de cadenas posé sur une vignette verrouillée (même or que les emplacements Pro).
struct ToneLockBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 44, height: 44)
            HZLockMark(size: 22)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }
}
