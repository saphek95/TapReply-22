import Foundation

/// Ton personnalisé créé par l'utilisateur dans le Studio.
/// Stockage : JSON dans UserDefaults.standard (l'app et l'App Intent partagent
/// le même process — même mécanique que tous les autres réglages).
/// PAS de SwiftData : éviter toute migration de schéma du conteneur ReplyRecord.
///
/// V1.2.0 — champs additionnels de la refonte Horizon (tous OPTIONNELS pour
/// que les tons enregistrés par les versions précédentes se décodent tels
/// quels) : description courte + exemple mis en cache depuis le mode Test.
struct CustomTone: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String          // ≤ 24 caractères
    var instruction: String    // ≤ 600 caractères (plafonné aussi côté backend)
    var artIndex: Int          // teinte de vignette (rotation de la palette)
    /// Émoji choisi par l'utilisateur (optionnel) — affiché sur l'artwork
    /// du ton, dans la bibliothèque et l'Historique.
    var emoji: String?
    var createdAt: Date
    /// V1.2.0 — description courte affichée sur la fiche du ton (optionnelle).
    var about: String?
    /// V1.2.0 — exemple mis en cache : le dernier échange réussi du mode Test
    /// (message envoyé + réponse de l'IA). Affiché sur la fiche du ton.
    var exampleThem: String?
    var exampleMe: String?
    /// V1.2.0 — pose de la MASCOTTE choisie à la création (index du
    /// MascotCatalog). nil = ton d'avant la mascotte → pochette emoji.
    var mascotIndex: Int?

    init(title: String, instruction: String, artIndex: Int, emoji: String? = nil,
         about: String? = nil, mascotIndex: Int? = nil) {
        self.id = UUID()
        self.title = title
        self.instruction = instruction
        self.artIndex = artIndex
        self.emoji = emoji
        self.createdAt = Date()
        self.about = about
        self.exampleThem = nil
        self.exampleMe = nil
        self.mascotIndex = mascotIndex
    }
}

enum CustomToneStore {
    /// Tons personnalisés GRATUITS (26/09) : 1. Avec Pro : illimités (plafond technique de sécurité).
    static let freeLimit = 1
    static let proCap = 30
    /// Plafond de STOCKAGE : jamais de suppression silencieuse quand un abonné perd Pro (ses tons en trop sont
    /// seulement verrouillés, pas effacés).
    static let maxCount = proCap

    /// Les tons restés accessibles SANS abonnement : les `freeLimit` plus anciens (ordre de création).
    static func unlockedIDs(hasPro: Bool) -> Set<UUID> {
        let list = all.sorted { $0.createdAt < $1.createdAt }
        return Set((hasPro ? list : Array(list.prefix(freeLimit))).map(\.id))
    }

    /// Ton personnalisé verrouillé : créé en plus du ton gratuit, et l'abonnement Pro n'est plus actif.
    static func isLocked(_ tone: CustomTone, hasPro: Bool) -> Bool {
        !hasPro && !unlockedIDs(hasPro: false).contains(tone.id)
    }

    static func isLocked(id raw: String, hasPro: Bool) -> Bool {
        guard let t = tone(withID: raw) else { return false }
        return isLocked(t, hasPro: hasPro)
    }

    /// Peut-on créer un NOUVEAU ton ? Gratuit : tant qu'aucun n'existe. Pro : jusqu'au plafond technique.
    static func canCreate(hasPro: Bool) -> Bool {
        all.count < (hasPro ? proCap : freeLimit)
    }

    /// Le ton gratuit (le plus ancien) : c'est lui qu'on propose de modifier quand la limite est atteinte.
    static var freeTone: CustomTone? { all.sorted { $0.createdAt < $1.createdAt }.first }

    static var all: [CustomTone] {
        guard let data = UserDefaults.standard.data(forKey: SettingsKeys.customTones),
              let list = try? JSONDecoder().decode([CustomTone].self, from: data)
        else { return [] }
        return list
    }

    static func save(_ list: [CustomTone]) {
        guard let data = try? JSONEncoder().encode(Array(list.prefix(maxCount))) else { return }
        UserDefaults.standard.set(data, forKey: SettingsKeys.customTones)
    }

    static func add(_ tone: CustomTone) {
        var list = all
        guard list.count < maxCount else { return }
        list.append(tone)
        save(list)
    }

    static func update(_ tone: CustomTone) {
        var list = all
        guard let i = list.firstIndex(where: { $0.id == tone.id }) else { return }
        list[i] = tone
        save(list)
    }

    /// V1.2.0 — mémorise le dernier échange du mode Test comme exemple de la
    /// fiche du ton (question de l'autre + réponse générée).
    static func recordExample(toneID: UUID, them: String, me: String) {
        var list = all
        guard let i = list.firstIndex(where: { $0.id == toneID }) else { return }
        list[i].exampleThem = String(them.prefix(140))
        list[i].exampleMe = String(me.prefix(200))
        save(list)
    }

    static func delete(id: UUID) {
        save(all.filter { $0.id != id })
        // Si le ton supprimé était assigné à un déclencheur, on retombe
        // sur « Classique » (Double Tap) ou on vide (autres déclencheurs).
        ToneTriggers.handleDeletedTone(id: id)
    }

    static func tone(withID raw: String) -> CustomTone? {
        guard let uuid = UUID(uuidString: raw) else { return nil }
        return all.first { $0.id == uuid }
    }
}

/// Résout l'affichage d'un ton stocké : rawValue de `Tone` OU UUID de ton
/// personnalisé (les deux formes cohabitent dans `SettingsKeys.defaultTone`
/// et dans `ReplyRecord.tone`).
enum ToneDisplay {
    static func label(for raw: String) -> String {
        if let c = CustomToneStore.tone(withID: raw) { return c.title }
        return (Tone(rawValue: raw) ?? .auto).label
    }
}
