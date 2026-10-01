import AppIntents
import SwiftUI

// =============================================================================
// LES TROIS ACTIONS EXPOSÉES À L'APP RACCOURCIS — UNE PAR GESTE
// =============================================================================
//
// iOS ne dit jamais quel geste a lancé un raccourci. Un geste = un raccourci =
// une action. Tout le travail vit dans AnalyzeRunner (voir son en-tête pour le
// raisonnement complet) ; ces trois structs ne sont que des portes d'entrée.
//
// ⚠️ `AnalyzeIntent` — nom de type ET titre — NE DOIT PAS CHANGER : les
// raccourcis déjà installés chez les testeurs le référencent. Les deux autres
// actions s'ajoutent à côté, sans jamais le toucher.

/// L'action HISTORIQUE, celle du Double Tap et de l'onboarding.
/// Conforme à LiveActivityIntent : autorisée à démarrer une Live Activity
/// depuis l'arrière-plan (le Back Tap est un geste utilisateur via l'OS).
/// Restitution : Dynamic Island (Live Activity) + presse-papiers + notification.
struct AnalyzeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Analyser"
    static var description = IntentDescription(
        "Analyse une capture d'écran de conversation et génère la réponse idéale (copiée automatiquement)."
    )
    // CRUCIAL : l'app ne passe pas au premier plan.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Capture d'écran")
    var screenshot: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Analyser \(\.$screenshot)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await AnalyzeRunner.run(trigger: .doubleTap, screenshot: screenshot))
    }
}

/// TRIPLE TAP — à associer au raccourci « TapReply Triple », lui-même branché
/// sur Réglages → Accessibilité → Toucher → Toucher le dos → Toucher trois fois.
struct AnalyzeTripleTapIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Analyser (triple tap)"
    static var description = IntentDescription(
        "Comme « Analyser », mais avec le ton associé au Triple Tap dans le Studio. À utiliser dans le raccourci dédié au triple tap."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Capture d'écran")
    var screenshot: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Analyser \(\.$screenshot) avec le ton du triple tap")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await AnalyzeRunner.run(trigger: .tripleTap, screenshot: screenshot))
    }
}

/// BOUTON ACTION — à associer au raccourci « TapReply Bouton », lui-même
/// branché sur Réglages → Bouton Action → Raccourci. (iPhone 15 Pro et plus.)
struct AnalyzeActionButtonIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Analyser (bouton Action)"
    static var description = IntentDescription(
        "Comme « Analyser », mais avec le ton associé au bouton Action dans le Studio. À utiliser dans le raccourci dédié au bouton Action."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Capture d'écran")
    var screenshot: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Analyser \(\.$screenshot) avec le ton du bouton Action")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await AnalyzeRunner.run(trigger: .actionButton, screenshot: screenshot))
    }
}
