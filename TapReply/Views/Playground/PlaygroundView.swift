import SwiftUI
import Combine
import PhotosUI

/// ESSAI — refonte Horizon 1.2.0 (le terrain de jeu du pipeline RÉEL).
/// Une fausse conversation à l'écran pour tester le pipeline complet :
/// - iPhone : double tap au dos → le raccourci capture CET écran → réponse.
/// AUCUN contournement : le double tap est le seul déclencheur de cet écran.
/// Un bouton qui générait sans le geste laissait croire l'app fonctionnelle
/// alors que le Back Tap pouvait très bien ne pas répondre — il est retiré.
/// LOGIQUE INCHANGÉE (détection de runs par polling, brouillon, envoi simulé)
/// — seul l'habillage passe en DA Horizon. La feuille de résultat (ResultSheet)
/// n'est plus présentée ici : le vrai double tap affiche déjà l'île puis le
/// snippet iOS. Elle reste définie, prête à resservir.
struct PlaygroundView: View {
    @ObservedObject private var theme = HZTheme.shared
    @AppStorage(SettingsKeys.consentAccepted) private var consentAccepted = false
    @AppStorage(SettingsKeys.shortcutConfirmed) private var shortcutConfirmed = false
    @AppStorage(SettingsKeys.backTapConfirmed) private var backTapConfirmed = false

    @State private var draftText = ""
    @State private var sentMessages: [String] = []
    @State private var errorMessage: String?
    /// Voie SANS geste : analyser une capture déjà prise (photothèque). Pour les iPhone sans Back Tap, pour qui
    /// n'utilise pas l'Accessibilité, et pour App Review (iPad, pas de Back Tap). Aucune permission photo : le
    /// sélecteur tourne hors du process de l'app. La génération reste soumise au consentement.
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedResult: PickedResult?
    @State private var analyzing = false
    @State private var showConsent = false
    @State private var showSentToast = false
    /// Anime les trois points de la bande d'attente.
    @State private var pulse = false
    @ObservedObject private var keyboard = HZKeyboard.shared
    /// Une réponse a été générée pendant cette session et n'a pas encore été
    /// envoyée : c'est ce qui déclenche le mode « colle ta réponse ». On ne se
    /// base PAS sur l'île, qui se referme au bout de 6 s alors que la réponse
    /// est toujours dans le presse-papiers.
    @State private var replyReady = false
    /// La carte d'explication est DÉPLIÉE tant que le double tap n'a jamais
    /// abouti sur cet appareil : on lit le mode d'emploi une fois. Ensuite elle
    /// se replie d'elle-même pour rendre sa place à la conversation, et un tap
    /// la redéploie.
    @State private var briefExpanded = false
    @FocusState private var composerFocused: Bool

    // Île SIMULÉE (la vraie Live Activity ne s'affiche pas de façon fiable
    // quand TapReply est au premier plan). RIEN au repos.
    private enum IslandPhase { case none, generating, ready }
    @State private var islandPhase: IslandPhase = .none
    @State private var islandReply = ""
    @State private var appearedAt = Date()
    private let islandTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // ① Titre + badge d'état
                        HStack(alignment: .center) {
                            Text(String(localized: "Essai"))
                                .font(HZ.Fonts.title)
                                .foregroundStyle(HZ.Colors.ink)
                            Spacer()
                            statusBadge
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                        briefCard
                            .padding(.bottom, 10)

                        // iPad uniquement (pas de Back Tap) : sur iPhone, le geste reste la seule porte d'entrée,
                        // pour ne pas brouiller la compréhension de l'app.
                        if DeviceCapabilities.isIPad {
                            screenshotPicker
                                .padding(.bottom, 12)
                        }

                        // ② Détail de configuration si incomplet
                        if configOK < 3 {
                            missingCard
                                .padding(.bottom, 12)
                        }

                        // ③ Conversation de test
                        conversationCard
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, HZ.Spacing.gutter)
                    // Le clavier mange le bas : on ajoute du dégagement pour
                    // que la bulle de saisie ne finisse pas collée à lui.
                    .padding(.bottom, keyboard.isVisible ? 30 : 16)
                }
                // Le clavier se rétracte en défilant vers le bas — geste
                // naturel, et il n'y avait AUCUN moyen de le fermer avant.
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: sentMessages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                // Le champ vit en BAS du contenu défilant : sans ce recentrage,
                // le clavier le recouvrait et rien ne bougeait.
                //
                // DEUX passages, et c'est nécessaire : au moment du focus, le
                // clavier n'est pas encore posé — la hauteur disponible est
                // donc encore l'ancienne, et le premier scroll s'arrête trop
                // haut (la bulle restait à moitié sous le clavier). Le second,
                // joué après son animation, travaille sur la bonne hauteur.
                .onChange(of: composerFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                        withAnimation(.easeOut(duration: 0.28)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                // Réponse prête → on amène la zone de collage sous les yeux.
                .onChange(of: islandPhase) { _, phase in
                    guard phase == .ready else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onTapGesture { composerFocused = false }
            }

            // BANDE D'ATTENTE — remplace l'ancien bouton « Tester sans le
            // double tap ». Ce raccourci n'avait rien à faire en production :
            // il permettait de croire l'app fonctionnelle sans jamais éprouver
            // le geste, qui est POURTANT la seule chose que cet écran valide.
            // À la place, un état vivant : l'app dit qu'elle guette le geste,
            // puis que le génie travaille.
            if keyboard.isVisible {
                // FERMER LE CLAVIER — bouton posé par NOUS, pas par la barre
                // d'accessoire d'iOS : celle-ci imposait son propre fond blanc
                // « glass » autour, donnant deux bulles imbriquées et mal
                // centrées, et rognait même le libellé. Ici, plus que le signe
                // dans sa pastille teintée, et l'espacement est le nôtre.
                HStack {
                    Spacer()
                    Button { composerFocused = false } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HZ.Colors.blue)
                            .frame(width: 38, height: 38)
                            .background(HZ.Colors.tint, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, HZ.Spacing.gutter)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .transition(.opacity)
            } else {
                waitingStrip
                    .padding(.horizontal, HZ.Spacing.gutter)
                    .padding(.top, 6)
                    // 66 pt = la barre flottante (50) + 6 de marge basse + air.
                    .padding(.bottom, 66)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: keyboard.isVisible)
        // Le fond (brume commune) vit au niveau de la RACINE — page transparente.
        .overlay(alignment: .top) {
            if islandPhase != .none {
                FakeIslandView(state: islandPhase == .generating ? .generating : .ready,
                               reply: islandReply)
                    .padding(.top, 4)
                    .transition(.scale(scale: 0.3, anchor: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { islandPhase = .none } }
            }
        }
        .overlay(alignment: .top) {
            if showSentToast {
                ToastView(message: String(localized: "Message envoyé"))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            appearedAt = Date()
            // Le mode d'emploi ne se lit qu'une fois : si un double tap a déjà
            // abouti sur cet appareil, la carte arrive repliée et la
            // conversation garde toute sa place.
            // Carte REPLIÉE par défaut (26/09) : toute la conversation d'essai doit tenir à l'écran sans défiler,
            // sinon le double tap capture un écran à moitié vide. Un tap la déplie.
            briefExpanded = false
        }
        .onReceive(islandTimer) { _ in checkIslandProgress() }
        .alert(String(localized: "Oups"), isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - La carte d'explication

    /// À QUOI SERT CET ÉCRAN. Deux phrases ne suffisaient pas : on arrivait sur
    /// une fausse conversation sans savoir qu'on était sur un banc d'essai, ni
    /// ce qui allait se passer, ni pourquoi il fallait coller quelque chose.
    /// La carte porte donc les TROIS temps du geste — taper, laisser copier,
    /// coller — et se referme sur la promesse qui justifie l'écran : si ça
    /// marche ici, ça marchera partout ailleurs.
    ///
    /// En couleur d'accent, parce que c'est le seul appel à l'action de la page.
    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.18))
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Teste ton double tap"))
                        .font(HZ.Fonts.fig(17.5, .bold))
                        .foregroundStyle(.white)
                    Text(briefExpanded
                         ? String(localized: "Une conversation pour de faux : personne ne reçoit rien.")
                         : String(localized: "Double-tape au dos de l'iPhone, sur cet écran"))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: briefExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if briefExpanded {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 1)
                    .padding(.vertical, 11)

                VStack(alignment: .leading, spacing: 6) {
                    briefStep(1, String(localized: "Double-tape au dos de l'iPhone, sur cet écran"))
                    briefStep(2, String(localized: "Le génie lit la conversation et copie sa réponse"))
                    briefStep(3, String(localized: "Colle-la dans le champ en bas, puis envoie"))
                }

                Text(String(localized: "Si ça marche ici, ça marchera dans toutes tes apps."))
                    .font(HZ.Fonts.fig(13.5, .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HZ.Colors.blue,
                    in: RoundedRectangle(cornerRadius: HZ.Radius.row,
                                         style: .continuous))
        .hzFloating()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.35)) { briefExpanded.toggle() }
        }
    }

    /// « Analyser une capture existante » : même pipeline que le double tap (OCR local, puis IA), résultat en feuille.
    private var screenshotPicker: some View {
        Group {
            if consentAccepted {
                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    pickerLabel
                }
                .disabled(analyzing)
            } else {
                Button { showConsent = true } label: { pickerLabel }
                    .buttonStyle(.plain)
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            analyzing = true
            Task { @MainActor in
                defer { analyzing = false; pickedItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    errorMessage = String(localized: "Impossible d'ouvrir cette image.")
                    return
                }
                do {
                    let out = try await ReplyPipeline.run(imageData: data, source: "picker")
                    pickedResult = PickedResult(output: out)
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
        .sheet(item: $pickedResult) { ResultSheet(output: $0.output) }
        .sheet(isPresented: $showConsent) { ConsentSheet(accepted: $consentAccepted) }
    }

    private var pickerLabel: some View {
        HStack(spacing: 10) {
            if analyzing {
                ProgressView().tint(HZ.Colors.blue)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 15, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(analyzing ? String(localized: "Analyse en cours…") : String(localized: "Analyser une capture existante"))
                    .font(HZ.Fonts.fig(15, .bold))
                Text(String(localized: "Pas de Back Tap ? Choisis une capture de conversation dans tes photos."))
                    .font(HZ.Fonts.fig(12.5, .medium))
                    .foregroundStyle(HZ.Colors.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(HZ.Colors.faint)
        }
        .foregroundStyle(HZ.Colors.blue)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HZ.Colors.card, in: RoundedRectangle(cornerRadius: HZ.Radius.row, style: .continuous))
        .contentShape(Rectangle())
    }

    private func briefStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(n)")
                .font(HZ.Fonts.fig(11, .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.white.opacity(0.22), in: Circle())
            Text(text)
                .font(HZ.Fonts.fig(14, .medium))
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Bande d'attente (ce qui remplace le bouton de contournement)

    /// L'écran guette le geste : trois points qui respirent au repos, un
    /// indicateur pendant la génération. Aucune action — c'est un état, pas un
    /// bouton, et c'est justement le propos : ici, seul le double tap agit.
    private var waitingStrip: some View {
        HStack(spacing: 10) {
            if islandPhase == .generating {
                ProgressView()
                    .controlSize(.small)
                    .tint(HZ.Colors.blue)
                Text(String(localized: "Le génie s'active…"))
                    .font(HZ.Fonts.fig(14, .semibold))
                    .foregroundStyle(HZ.Colors.ink)
            } else if replyReady {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HZ.Colors.green)
                Text(String(localized: "Réponse copiée : colle-la dans le champ."))
                    .font(HZ.Fonts.fig(14, .semibold))
                    .foregroundStyle(HZ.Colors.ink)
            } else {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(HZ.Colors.blue)
                            .frame(width: 6, height: 6)
                            .opacity(pulse ? 1 : 0.25)
                            .animation(.easeInOut(duration: 0.65)
                                        .repeatForever()
                                        .delay(Double(i) * 0.18),
                                       value: pulse)
                    }
                }
                Text(String(localized: "En attente de ton double tap"))
                    .font(HZ.Fonts.fig(14, .medium))
                    .foregroundStyle(HZ.Colors.sub)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .onAppear { pulse = true }
    }

    // MARK: - État de configuration

    private var configOK: Int {
        [consentAccepted, shortcutConfirmed, backTapConfirmed].filter { $0 }.count
    }

    private var statusBadge: some View {
        let allOK = configOK == 3
        return HStack(spacing: 6) {
            Circle()
                .fill(allOK ? HZ.Colors.green : HZ.Colors.alarm)
                .frame(width: 8, height: 8)
            Text(allOK
                 ? String(localized: "Prêt")
                 : String(localized: "\(configOK)/3"))
                .font(HZ.Fonts.fig(13.5, .semibold))
                .foregroundStyle(HZ.Colors.ink)
        }
        .padding(.horizontal, 13)
        .frame(height: 32)
        .background(.white, in: Capsule())
        .hzSoft()
    }

    private var missingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(HZ.Colors.alarm)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "Configuration incomplète"))
                    .font(HZ.Fonts.headline)
                    .foregroundStyle(HZ.Colors.ink)
                Text(missingList)
                    .font(HZ.Fonts.sub)
                    .foregroundStyle(HZ.Colors.sub)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hzCard(radius: HZ.Radius.row)
        .hzSoft()
    }

    private var missingList: String {
        var missing: [String] = []
        if !consentAccepted { missing.append(String(localized: "consentement")) }
        if !shortcutConfirmed { missing.append(String(localized: "raccourci")) }
        if !backTapConfirmed { missing.append(String(localized: "Back Tap")) }
        return missing.joined(separator: " · ")
    }

    // MARK: - Carte de conversation

    private var conversationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // En-tête : avatar + nom + REWIND (remet la conversation à zéro)
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: 0xFF9AC0), Color(hex: 0xE0559A)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("A")
                        .font(HZ.Fonts.fig(18, .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Alex")
                        .font(HZ.Fonts.headline)
                        .foregroundStyle(HZ.Colors.ink)
                    Text(String(localized: "conversation de test"))
                        .font(HZ.Fonts.sub)
                        .foregroundStyle(HZ.Colors.sub)
                }
                Spacer(minLength: 0)
                if !sentMessages.isEmpty || !draftText.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            sentMessages = []
                            draftText = ""
                        }
                        composerFocused = false
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HZ.Colors.ink)
                            .frame(width: 34, height: 34)
                            .background(HZ.Colors.card, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Fil de messages
            VStack(spacing: 7) {
                HZChatBubble(text: String(localized: "Bonjour ! Est-ce que le créneau de mardi 15h te convient toujours pour notre point projet ?"), kind: .incoming)
                HZChatBubble(text: String(localized: "Bonjour, oui je vous confirme ça rapidement."), kind: .outgoing)
                HZChatBubble(text: String(localized: "Parfait. Peux-tu aussi m'envoyer le récap budget avant la réunion ? Merci !"), kind: .incoming)

                // Messages « envoyés » par l'utilisateur pendant le test
                ForEach(Array(sentMessages.enumerated()), id: \.offset) { _, message in
                    HZChatBubble(text: message, kind: .outgoing)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // La bulle de SAISIE — le brouillon, c'est la pépite
                composeBubble
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .hzCard(radius: HZ.Radius.card)
        .hzSoft()
    }

    /// Le champ joue DEUX rôles successifs, exactement comme dans une vraie
    /// conversation : AVANT le double tap, c'est là qu'on écrit son idée (le
    /// brouillon que l'IA amplifie) ; APRÈS, c'est là qu'on colle la réponse
    /// pour l'envoyer. Rien ne le disait — le placeholder parlait toujours
    /// d'« idée » alors que l'île venait de demander de coller. Il change donc
    /// de discours selon la phase, et un bouton COLLER apparaît dès que la
    /// réponse est dans le presse-papiers : plus besoin d'appui long.
    private var awaitingPaste: Bool {
        replyReady && draftText.isEmpty
    }

    private var composeBubble: some View {
        HStack {
            Spacer(minLength: 40)
            HStack(spacing: 6) {
                TextField(awaitingPaste
                          ? String(localized: "Colle ta réponse ici…")
                          : String(localized: "Écris une idée (optionnel)…"),
                          text: $draftText, axis: .vertical)
                    .font(HZ.Fonts.body)
                    .foregroundStyle(HZ.Colors.ink)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .tint(HZ.Colors.blue)

                // COLLER en un tap — le geste que l'île réclame.
                if awaitingPaste {
                    Button {
                        if let s = UIPasteboard.general.string, !s.isEmpty {
                            draftText = s
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Text(String(localized: "Coller"))
                            .font(HZ.Fonts.fig(14, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(HZ.Colors.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
                // Envoi simulé (boucle magique : coller → envoyer)
                if !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 27))
                            .foregroundStyle(HZ.Colors.blue)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.25), value: draftText.isEmpty)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20,
                                       bottomTrailingRadius: 6, topTrailingRadius: 20,
                                       style: .continuous)
                    .fill(HZ.Colors.card)
                    .overlay(
                        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20,
                                               bottomTrailingRadius: 6, topTrailingRadius: 20,
                                               style: .continuous)
                            .strokeBorder(HZ.Colors.blue.opacity(0.5), lineWidth: 1.4)
                    )
            )
            .frame(maxWidth: 300, alignment: .trailing)
        }
    }

    // MARK: - Envoi simulé (logique inchangée)

    private func sendMessage() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(duration: 0.35)) {
            sentMessages.append(text)
            draftText = ""
            // La boucle est bouclée : retour en attente du prochain geste.
            replyReady = false
        }
        composerFocused = false
        withAnimation { showSentToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { showSentToast = false }
        }
    }

    // MARK: - Île simulée : détection des runs réels (logique inchangée)

    private func checkIslandProgress() {
        if let e = AppSettings.lastRunErrorAt, e > appearedAt {
            errorMessage = AppSettings.lastRunErrorMessage
            withAnimation { islandPhase = .none }
            appearedAt = Date()
            return
        }
        switch islandPhase {
        case .none:
            if let t = AppSettings.lastRunStartedAt, t > appearedAt {
                withAnimation(.spring(duration: 0.45, bounce: 0.25)) { islandPhase = .generating }
            }
            checkIslandReady()
        case .generating:
            checkIslandReady()
        case .ready:
            break
        }
    }

    private func checkIslandReady() {
        if let t = AppSettings.lastReplyAt, t > appearedAt, islandPhase != .ready {
            islandReply = AppSettings.lastReplyText
            withAnimation(.spring(duration: 0.45)) {
                islandPhase = .ready
                replyReady = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                withAnimation(.spring(duration: 0.4)) { islandPhase = .none }
                appearedAt = Date()
            }
        }
    }

    // MARK: - Test direct (logique inchangée, ton stocké brut pour l'historique)

}

// MARK: - Sheet de résultat (Horizon)

extension ReplyPipeline.Output: Identifiable {
    var id: String { reply }
}

private struct PickedResult: Identifiable {
    let id = UUID()
    let output: ReplyPipeline.Output
}

private struct ResultSheet: View {
    let output: ReplyPipeline.Output
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(String(localized: "Ta réponse"))
                    .font(HZ.Fonts.section)
                    .foregroundStyle(HZ.Colors.ink)
                Spacer()
                HZCloseButton { dismiss() }
            }
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if let tone = ToneItem.resolve(id: UserDefaults.standard.string(forKey: SettingsKeys.defaultTone) ?? output.tone.rawValue) {
                        ToneDotView(tone: tone, size: 30)
                        Text(tone.title)
                            .font(HZ.Fonts.strong)
                            .foregroundStyle(HZ.Colors.sub)
                    }
                    Spacer()
                    if output.parsed.draft?.isEmpty == false {
                        Text(String(localized: "brouillon amplifié"))
                            .font(HZ.Fonts.caption)
                            .foregroundStyle(HZ.Colors.blue)
                    }
                }
                Text(output.reply)
                    .font(HZ.Fonts.body)
                    .foregroundStyle(HZ.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hzCard(fill: HZ.Colors.card, radius: HZ.Radius.card)

            HZPrimaryButton(title: String(localized: "Copier et fermer"),
                            systemIcon: "doc.on.doc",
                            fill: HZ.Colors.blue) {
                UIPasteboard.general.string = output.reply
                dismiss()
            }

            Text(String(localized: "Colle-la ensuite dans le champ de la conversation, puis envoie 👆"))
                .font(HZ.Fonts.sub)
                .foregroundStyle(HZ.Colors.sub)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, HZ.Spacing.gutter)
        .background(HZ.Colors.sheet)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
