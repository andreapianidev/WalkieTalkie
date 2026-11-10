//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveBandViews.swift
//  WalkieTalkie
//
//  Le bande HF, CB e POC sulla schermata del walkie: display, stato, comandi e
//  lista dei canali. Tutto quello che si sente arriva da ricevitori e canali
//  veri (vedi Shared/RealRadio).

import SwiftUI

/// Dove punta il walkie: il canale locale fra telefoni vicini, oppure
/// l'ascolto dal vivo delle onde corte, della CB o dei canali POC.
enum WalkieBand: String, CaseIterable {
    case local, hf, cb, poc

    var title: String {
        switch self {
        case .local: return "live_band_local".localized
        case .hf: return "HF"
        case .cb: return "CB"
        case .poc: return "POC"
        }
    }

    var icon: String {
        switch self {
        case .local: return "person.2.wave.2"
        case .hf: return "antenna.radiowaves.left.and.right"
        case .cb: return "radio"
        case .poc: return "dot.radiowaves.up.forward"
        }
    }
}

@available(iOS 16.0, *)
extension WalkieBand {
    var live: LiveRadio.Band? {
        switch self {
        case .local: return nil
        case .hf: return .hf
        case .cb: return .cb
        case .poc: return .poc
        }
    }
}

// MARK: - Selettore di banda

struct BandSelectorRow: View {
    let selected: WalkieBand
    let enabled: Bool
    let onSelect: (WalkieBand) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WalkieBand.allCases, id: \.self) { band in
                Button(action: { onSelect(band) }) {
                    HStack(spacing: 5) {
                        Image(systemName: band.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(band.title)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundColor(selected == band ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(selected == band ? Color.yellow : Color.black)
                    )
                    // Sul walkie giallo un tasto giallo sparirebbe: il bordo nero
                    // lo stacca, come le altre manopole.
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.black, lineWidth: selected == band ? 2.5 : 0)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == band ? [.isSelected, .isButton] : .isButton)
            }
        }
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .padding(.horizontal, 20)
    }
}

// MARK: - Testi di stato

@available(iOS 16.0, *)
extension LiveRadio {
    var statusText: String {
        if isOutOfFreeTime {
            return "live_free_time_up".localized
        }
        if band == .poc, isScouting, pocChannels.isEmpty {
            return "live_scouting".localized
        }
        switch state {
        case .idle, .connecting:
            return "live_connecting".localized
        case .online:
            return "live_online".localized
        case .refused(let p), .dropped(let p):
            return Self.text(for: p, band: band)
        }
    }

    var statusColor: Color {
        if isOutOfFreeTime { return .orange }
        switch state {
        case .online: return .green
        case .idle, .connecting: return .orange
        case .refused, .dropped: return .red
        }
    }

    static func text(for problem: LiveProblem, band: Band?) -> String {
        switch problem {
        case .full: return (band == .poc ? "live_problem_full_poc" : "live_problem_full").localized
        case .refused: return "live_problem_refused".localized
        case .down: return (band == .poc ? "live_problem_no_channels" : "live_problem_down").localized
        case .closed: return "live_problem_closed".localized
        case .timeout: return "live_problem_timeout".localized
        case .needsCertificate: return "live_problem_refused".localized
        }
    }

    /// Da dove si ascolta, in poche parole: per un KiwiSDR il luogo, perche'
    /// i nomi scritti dai proprietari sono lunghi ("0-30 MHz SDR, EA8-DF4UE,
    /// Fuerteventura, Canary Islands") e su un telefono finivano in puntini.
    var shortSource: String {
        if band?.isKiwi == true, !sourcePlace.isEmpty { return sourcePlace }
        return sourceName
    }

    /// Accensione delle 5 spie del display: S-meter in HF e CB, voce in POC.
    var meterDots: Int {
        if band?.isKiwi == true, let dBm = signalDBm {
            return Int((SignalScale.fraction(dBm: dBm) * 5).rounded())
        }
        return Int((Double(level) * 5).rounded(.up))
    }
}

@available(iOS 16.0, *)
extension HFChannel.Kind {
    var subtitle: String {
        switch self {
        case .aviation: return "live_hf_kind_aviation".localized
        case .time: return "live_hf_kind_time".localized
        case .amateur: return "live_hf_kind_amateur".localized
        case .citizens: return "live_hf_kind_citizens".localized
        case .digital: return "live_hf_kind_digital".localized
        }
    }
}

// MARK: - Display

@available(iOS 16.0, *)
struct LiveDisplayView: View {
    @ObservedObject var live = LiveRadio.shared
    let compact: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black)
                .frame(height: compact ? 80 : 100)

            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(headline)
                        .foregroundColor(.white)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Circle()
                        .fill(live.statusColor)
                        .frame(width: 7, height: 7)
                    Text("RX")
                        .foregroundColor(.white)
                        .font(.caption.monospaced())
                }

                Spacer(minLength: 0)

                if live.band == .cb, let ch = live.cbChannel {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("CH \(ch)")
                            .font(.system(size: compact ? 30 : 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        Text("\(live.tuning.megahertzText) " + live.tuning.emission.rawValue)
                            .font(.caption.monospaced())
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                } else if live.band?.isKiwi == true {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(live.tuning.megahertzText)
                            .font(.system(size: compact ? 30 : 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        Text("MHz " + live.tuning.emission.rawValue)
                            .font(.caption.monospaced())
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                } else {
                    Text(live.channelName.isEmpty ? "- - -" : live.channelName.uppercased())
                        .font(.system(size: compact ? 22 : 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Spacer(minLength: 0)

                HStack {
                    Text(footline)
                        .foregroundColor(.white.opacity(0.85))
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0 ..< 5, id: \.self) { i in
                            Circle()
                                .fill(i < live.meterDots ? meterColor(i) : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .animation(.linear(duration: 0.1), value: live.meterDots)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .frame(height: compact ? 80 : 100)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch live.band {
        case .hf: return "HF · \(live.currentHF.name)"
        case .cb:
            let where_ = live.cbChannel.map { "CH \($0)" } ?? (live.cbIsDX ? "DX" : "CB")
            return "CB · " + where_ + (live.squelchOn ? " · SQL" : "")
        default: return "POC · \(live.shortSource)"
        }
    }

    private var footline: String {
        if live.band == .cb, live.isScanning {
            return (live.scanHolding ? "live_scan_holding" : "live_scan_searching").localized
        }
        if live.band?.isKiwi == true {
            if let dBm = live.signalDBm { return "\(SignalScale.label(dBm: dBm)) · \(live.shortSource)" }
            return live.shortSource
        }
        if let talker = live.talker { return String(format: "live_speaking".localized, talker) }
        if let n = live.audience { return String(format: "live_listeners".localized, n) }
        return live.statusText
    }

    private func meterColor(_ i: Int) -> Color {
        i >= 4 ? .red : i >= 3 ? .orange : .green
    }
}

// MARK: - Riquadro di stato

@available(iOS 16.0, *)
struct LiveStatusCard: View {
    @ObservedObject var live = LiveRadio.shared
    let compact: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text((live.band?.isKiwi == true ? "live_receiver" : "live_server").localized + ": " + sourceText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if live.state == .connecting || live.isScouting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                Text(live.statusText)
                    .font(.caption)
                    .foregroundColor(live.statusColor)
                    .lineLimit(2)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
            Circle()
                .fill(live.statusColor)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, compact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SurfaceColor"))
        )
        .padding(.horizontal, 20)
        .padding(.top, compact ? 6 : 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if live.isOutOfFreeTime { live.proPrompt = .freeTime }
        }
        .onAppear { noteListening(live.state) }
        .onChange(of: live.state) { noteListening($0) }
    }

    /// Il riquadro c'e' solo mentre una banda dal vivo e' accesa, quindi e' il
    /// posto dove l'app sa che si sta ascoltando davvero.
    private func noteListening(_ state: LinkState) {
        guard state == .online, let band = live.band else { return }
        Funnel.once(Funnel.liveListen, ["band": band.rawValue])
        // Il permesso delle notifiche dopo un ascolto vero, non al primo
        // fruscio: se dopo dieci secondi la banda e' ancora collegata, ha funzionato.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            guard live.state == .online, live.band != nil else { return }
            NotificationManager.shared.requestAfterFirstSuccess("live_\(band.rawValue)")
        }
    }

    private var sourceText: String {
        live.shortSource.isEmpty ? "--" : live.shortSource
    }

    /// Minuti gratis rimasti oggi davanti a tutto, poi da dove si ascolta.
    private var detail: String {
        guard let left = live.freeSecondsLeft, !live.isOutOfFreeTime else { return place }
        return String(format: "live_free_left".localized, String(format: "%d:%02d", left / 60, left % 60)) + " · " + place
    }

    private var place: String {
        if live.band?.isKiwi == true {
            return (live.band == .cb ? HFChannel.Kind.citizens : live.currentHF.kind).subtitle
        }
        // Su POC dalla 4.0 si parla: qui resta solo il server.
        return live.sourcePlace
    }
}

// MARK: - Comandi

@available(iOS 16.0, *)
struct LiveSecondaryRow: View {
    @ObservedObject var live = LiveRadio.shared
    let onList: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if live.band == .cb { cbRow }
            mainRow
        }
        .confirmationDialog("live_pro_title".localized,
                            isPresented: Binding(get: { live.proPrompt != nil },
                                                 set: { if !$0 { live.proPrompt = nil } }),
                            titleVisibility: .visible,
                            presenting: live.proPrompt) { prompt in
            Button("live_pro_video".localized) {
                AdManager.shared.presentRewardedLivePass(source: "live_\(prompt.rawValue)", onGranted: {
                    live.entitlementsChanged()
                    if prompt == .scan { live.startScan() }
                    if prompt == .room { live.createRoom() }
                }, onUnavailable: {
                    HapticManager.shared.warning()
                })
            }
            Button("live_pro_discover".localized) {
                PaywallTriggerManager.shared.requestForLiveFeature()
            }
            Button("cancel".localized, role: .cancel) {}
        } message: { prompt in
            Text(message(for: prompt))
        }
    }

    private func message(for prompt: LiveRadio.ProPrompt) -> String {
        switch prompt {
        case .scan: return "live_pro_scan_message".localized
        case .background: return "live_pro_background_message".localized
        case .freeTime: return String(format: "live_pro_free_message".localized, FreeListening.secondsPerDay / 60)
        case .room: return "live_pro_room_message".localized
        }
    }

    /// CB: parte (canali o DX), modo, squelch e sintonia fine.
    private var cbRow: some View {
        HStack(spacing: 8) {
            pill(live.cbIsDX ? "CH" : "DX", label: "live_cb_section".localized) { live.toggleCBSection() }
            pill(live.tuning.emission.rawValue, label: "live_cb_mode".localized) { live.cycleCBMode() }
            pill("SQL", label: "live_cb_squelch".localized, lit: live.squelchOn) { live.toggleSquelch() }
            pill("-1k", label: "live_tune_down".localized) { live.nudge(kHz: -1) }
            pill("+1k", label: "live_tune_up".localized) { live.nudge(kHz: 1) }
        }
        .padding(.horizontal, 20)
    }

    private var mainRow: some View {
        HStack(spacing: live.band == .cb ? 8 : 24) {
            circleButton("list.bullet", label: "live_channels".localized, action: onList)
            Spacer()
            if live.band == .hf {
                textButton("-1 kHz", label: "live_tune_down".localized) { live.nudge(kHz: -1) }
                Spacer()
                textButton("+1 kHz", label: "live_tune_up".localized) { live.nudge(kHz: 1) }
            } else {
                if live.band == .cb {
                    textButton("CH -", label: "live_cb_prev".localized, width: 60) { live.step(-1) }
                    Spacer()
                }
                Button(action: {
                    HapticManager.shared.lightTap()
                    live.toggleScan()
                }) {
                    HStack(spacing: 4) {
                        Text("SCAN")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                        if !live.proGate() {
                            Text("PRO")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.yellow))
                        }
                    }
                    .foregroundColor(live.isScanning ? .black : .white)
                    .frame(minWidth: 64, minHeight: 44)
                    .padding(.horizontal, 6)
                    .background(Capsule().fill(live.isScanning ? Color.yellow : Color.black))
                }
                .accessibilityLabel("live_scan".localized)
                .accessibilityAddTraits(live.isScanning ? [.isSelected, .isButton] : .isButton)
                Spacer()
                if live.band == .cb {
                    textButton("CH +", label: "live_cb_next".localized, width: 60) { live.step(1) }
                } else {
                    circleButton("arrow.clockwise", label: "live_refresh".localized) { live.rescanPOC() }
                        .disabled(live.isScouting)
                        .opacity(live.isScouting ? 0.4 : 1)
                }
            }
        }
        .padding(.horizontal, 30)
    }

    private func pill(_ text: String, label: String, lit: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(lit ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule().fill(lit ? Color.yellow : Color.black))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(lit ? [.isSelected, .isButton] : .isButton)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.title3)
            }
        }
        .accessibilityLabel(label)
    }

    private func textButton(_ text: String, label: String, width: CGFloat = 72, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: width, height: 44)
                .background(Capsule().fill(Color.black))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Display a barre del POC

/// Sul POC non c'e' un ricevitore da mostrare: il display a barre della voce
/// che arriva dal canale, e chi sta parlando.
/// Altezza dello schermo con spettro, cascata o barre. Sul telefono e' quella
/// di sempre; nei pannelli larghi (iPad, display interno del Duo) lo schermo
/// prende tutta l'altezza libera, e le letture restano sotto.
struct ScopeFrame: ViewModifier {
    let compact: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.talkyScopeFills) private var fills

    func body(content: Content) -> some View {
        if fills {
            content
                .frame(minHeight: 340, maxHeight: .infinity)
                .layoutPriority(1)
        } else {
            content.frame(height: compact ? 132 : (sizeClass == .regular ? 340 : 185))
        }
    }
}

extension View {
    func scopeFrame(compact: Bool) -> some View { modifier(ScopeFrame(compact: compact)) }
}

@available(iOS 16.0, *)
struct LiveSoundScreen: View {
    @ObservedObject var live = LiveRadio.shared
    let compact: Bool
    /// In HF e CB senza cascata: cosa si sta guardando.
    var label: String?

    private let amber = Color(red: 1.0, green: 0.8, blue: 0.0)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: live.state != .online)) { _ in
            let display = live.soundBands.display()
            ZStack {
                Color.black
                SoundBandsView(display: display, color: amber)
                    .padding(.horizontal, 6)
                    .padding(.top, 22)
                    .padding(.bottom, 6)
                    .opacity(live.state == .online ? 1 : 0.35)
                HStack(spacing: 5) {
                    Circle().fill(live.talker != nil ? Color.red : Color.white.opacity(0.3)).frame(width: 6, height: 6)
                    Text(label?.uppercased() ?? live.talker?.uppercased() ?? live.channelName.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .scopeFrame(compact: compact)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

/// Una lettura del pannello: etichetta piccola, valore grande, acceso in ambra
/// quando conta adesso.
struct DialReading {
    let label: String
    let value: String
    var lit = false
}

/// Il pannello nero delle letture, tre colonne, sotto lo schermo della radio.
struct DialReadings: View {
    let cells: [DialReading]
    let compact: Bool

    private let amber = Color(red: 1.0, green: 0.8, blue: 0.0)

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: compact ? 6 : 8) {
            ForEach(cells, id: \.label) { cell in
                VStack(alignment: .leading, spacing: 2) {
                    Text(cell.label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(cell.value)
                        .font(.system(size: compact ? 12 : 13, weight: .bold, design: .monospaced))
                        .foregroundColor(cell.lit ? amber : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 7 : 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

/// HF, CB e POC si ascoltano soltanto: al posto del tasto per parlare, lo
/// schermo del ricevitore a tutta larghezza e le letture che servono.
@available(iOS 16.0, *)
struct LiveListeningDeck: View {
    let band: WalkieBand
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            if band == .poc {
                LiveSoundScreen(compact: compact)
            } else {
                LivePanoramaScreen(compact: compact)
            }
            LiveReadings(band: band, compact: compact)
            LiveSpeakerStatus()
            if band == .poc {
                POCTalkControls(compact: compact)
            }
        }
    }
}

/// Le letture di una radio vera: da dove si ascolta, quanto arriva forte,
/// come si sta demodulando, quanto ascolto gratis resta.
@available(iOS 16.0, *)
struct LiveReadings: View {
    @ObservedObject var live = LiveRadio.shared
    let band: WalkieBand
    let compact: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            DialReadings(cells: cells(at: context.date), compact: compact)
        }
    }

    private typealias Cell = DialReading

    private func cells(at date: Date) -> [Cell] {
        let none = "--"
        var out: [Cell] = []
        if band == .poc {
            out.append(Cell(label: "live_server".localized, value: live.sourceName.isEmpty ? none : live.sourceName))
            out.append(Cell(label: "live_info_channel".localized, value: live.channelName.isEmpty ? none : live.channelName))
            out.append(Cell(label: "live_info_listeners".localized, value: live.audience.map(String.init) ?? none))
            out.append(Cell(label: "live_info_talker".localized, value: live.talker ?? none, lit: live.talker != nil))
        } else {
            out.append(Cell(label: "live_receiver".localized, value: live.shortSource.isEmpty ? none : live.shortSource))
            out.append(Cell(label: "live_info_distance".localized, value: live.receiverKm.map { "\($0) km" } ?? none))
            out.append(Cell(label: "live_info_signal".localized,
                            value: live.signalDBm.map { "\(SignalScale.label(dBm: $0)) \(Int($0.rounded())) dBm" } ?? none,
                            lit: live.squelchOpen))
            let pb = KiwiFrame.passband(live.tuning)
            out.append(Cell(label: "live_info_mode".localized,
                            value: live.tuning.emission.rawValue + String(format: " %.1f kHz", Double(pb.high - pb.low) / 1000)))
            if band == .cb {
                let sql = !live.squelchOn ? "OFF" : (live.squelchOpen ? "live_info_open" : "live_info_closed").localized
                out.append(Cell(label: "live_info_squelch".localized, value: sql, lit: live.squelchOpen))
            }
        }
        if band != .cb {
            out.append(Cell(label: "UTC", value: Self.utc.string(from: date)))
        }
        out.append(freeCell)
        return out
    }

    private var freeCell: Cell {
        guard let left = live.freeSecondsLeft else { return Cell(label: "live_info_listening".localized, value: "PRO", lit: true) }
        return Cell(label: "live_info_free".localized, value: String(format: "%d:%02d", left / 60, left % 60), lit: left < 60)
    }

    private static let utc: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

/// Lo schermo con lo spettro e la cascata del ricevitore, in HF e CB.
@available(iOS 16.0, *)
struct LivePanoramaScreen: View {
    @ObservedObject var live = LiveRadio.shared
    let compact: Bool

    var body: some View {
        if live.hasWaterfall || live.isOutOfFreeTime || live.state != .online {
            panorama
        } else {
            LiveSoundScreen(compact: compact, label: live.spectrumSearching ? "live_pan_searching".localized : "live_audio_spectrum".localized)
        }
    }

    private var panorama: some View {
        PanoramaView(panorama: live.panorama,
                     tuning: live.tuning,
                     signalDBm: live.signalDBm,
                     words: PanoramaWords(overNoise: "live_pan_over_noise".localized,
                                          noiseOnly: "live_pan_noise_only".localized,
                                          waiting: (live.isOutOfFreeTime ? "live_free_time_up"
                                                            : live.spectrumSearching ? "live_pan_searching"
                                                            : live.spectrumMissing ? "live_pan_missing"
                                                            : "live_pan_waiting").localized))
            .scopeFrame(compact: compact)
            .padding(.horizontal, 12)
            .onTapGesture {
                if live.isOutOfFreeTime { live.proPrompt = .freeTime }
            }
    }
}

/// Riga sotto le letture: chi parla, o lo stato del collegamento.
@available(iOS 16.0, *)
struct LiveSpeakerStatus: View {
    @ObservedObject var live = LiveRadio.shared

    var body: some View {
        HStack(spacing: 6) {
            if let talker = live.talker {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(.blue)
                Text(String(format: "live_speaking".localized, talker))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            } else if live.state == .online {
                Image(systemName: live.level > 0.02 ? "speaker.wave.2" : "speaker")
                    .foregroundColor(.green)
                Text(onlineText)
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text(live.statusText)
                    .font(.caption2)
                    .foregroundColor(live.statusColor)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var onlineText: String {
        if live.band == .cb {
            if live.isScanning { return (live.scanHolding ? "live_scan_holding" : "live_scan_searching").localized }
            if live.squelchOn, !live.squelchOpen { return "live_cb_quiet".localized }
            return "reception_in_progress".localized
        }
        if live.band == .poc {
            if live.isScanning { return (live.scanHolding ? "live_scan_holding" : "live_scan_searching").localized }
            return "live_silence".localized
        }
        return "reception_in_progress".localized
    }
}

// MARK: - Lista dei canali

@available(iOS 16.0, *)
struct LiveChannelsSheet: View {
    @ObservedObject var live = LiveRadio.shared
    @Environment(\.dismiss) private var dismiss
    @State private var typedFrequency = ""
    @State private var typedWrong = false

    var body: some View {
        NavigationStack {
            List {
                if live.band == .cb {
                    cbSections
                } else if live.band == .hf {
                    Section {
                        ForEach(Array(live.hfChannels.enumerated()), id: \.element.id) { i, ch in
                            Button(action: {
                                live.selectHF(i)
                                dismiss()
                            }) {
                                row(title: ch.name,
                                    subtitle: "\(ch.tuning.megahertzText) MHz \(ch.tuning.emission.rawValue) · \(ch.kind.subtitle)",
                                    selected: i == live.hfIndex)
                            }
                        }
                    } footer: {
                        Text("live_hf_footer".localized)
                    }
                } else {
                    POCRoomsSection { dismiss() }
                    Section {
                        if live.pocChannels.isEmpty {
                            HStack {
                                if live.isScouting { ProgressView() }
                                Text(live.isScouting ? "live_scouting".localized : "live_problem_no_channels".localized)
                                    .foregroundColor(.secondary)
                            }
                        }
                        ForEach(Array(live.pocChannels.enumerated()), id: \.element.id) { i, ch in
                            Button(action: {
                                live.stopScan()
                                live.selectPOC(i)
                                dismiss()
                            }) {
                                row(title: ch.channel,
                                    subtitle: "\(ch.server.name) · " + String(format: "live_listeners".localized, ch.users),
                                    selected: i == live.pocIndex)
                            }
                        }
                    } footer: {
                        Text("live_poc_footer".localized)
                    }
                }
            }
            .navigationTitle(live.band == .hf ? "HF" : live.band == .cb ? "CB" : "POC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ok".localized) { dismiss() }
                }
                if live.band == .poc {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("live_refresh".localized) { live.rescanPOC() }
                            .disabled(live.isScouting)
                    }
                }
            }
        }
    }

    /// Frequenza a mano, i 40 canali e la chiamata DX.
    @ViewBuilder
    private var cbSections: some View {
        Section {
            HStack {
                TextField("27.555", text: $typedFrequency)
                    .keyboardType(.decimalPad)
                    .font(.body.monospaced())
                    .onSubmit(tuneTyped)
                Text("MHz")
                    .foregroundColor(.secondary)
                Button("live_cb_tune".localized, action: tuneTyped)
                    .disabled(typedFrequency.isEmpty)
            }
        } header: {
            Text("live_cb_enter_frequency".localized)
        } footer: {
            if typedWrong { Text("live_cb_out_of_band".localized).foregroundColor(.red) }
        }
        Section {
            Button(action: {
                live.tuneCB(hz: CitizensBand.dxCall)
                dismiss()
            }) {
                row(title: "DX 27.555",
                    subtitle: "27.555 MHz USB · " + "live_cb_dx_call".localized,
                    selected: live.tuning.hz == CitizensBand.dxCall)
            }
        } header: {
            Text("DX")
        }
        Section {
            ForEach(1 ... 40, id: \.self) { n in
                let hz = CitizensBand.channels[n - 1]
                Button(action: {
                    live.selectCBChannel(n)
                    dismiss()
                }) {
                    row(title: "CH \(n)",
                        subtitle: "\(Tuning(hz: hz, emission: .am, bandwidth: 0).megahertzText) MHz " + CitizensBand.usualEmission(channel: n).rawValue,
                        selected: live.cbChannel == n)
                }
            }
        } header: {
            Text("live_cb_channels".localized)
        } footer: {
            Text("live_cb_footer".localized)
        }
    }

    /// Accetta "27.555", "27,555" e anche "27555" (kHz).
    private func tuneTyped() {
        let text = typedFrequency.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else {
            typedWrong = true
            return
        }
        let hz = Int((value < 100 ? value * 1_000_000 : value * 1000).rounded())
        if live.tuneCB(hz: hz) {
            typedWrong = false
            dismiss()
        } else {
            typedWrong = true
        }
    }

    private func row(title: String, subtitle: String, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
    }
}
