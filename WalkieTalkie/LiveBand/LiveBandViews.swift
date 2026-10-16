//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveBandViews.swift
//  WalkieTalkie
//
//  Le bande HF e POC sulla schermata del walkie: display, stato, comandi e
//  lista dei canali. Tutto quello che si sente arriva da ricevitori e canali
//  veri (vedi Shared/RealRadio).

import SwiftUI

/// Dove punta il walkie: il canale locale fra telefoni vicini, oppure
/// l'ascolto dal vivo delle onde corte o dei canali POC.
enum WalkieBand: String, CaseIterable {
    case local, hf, poc

    var title: String {
        switch self {
        case .local: return "live_band_local".localized
        case .hf: return "HF"
        case .poc: return "POC"
        }
    }

    var icon: String {
        switch self {
        case .local: return "person.2.wave.2"
        case .hf: return "antenna.radiowaves.left.and.right"
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
                    }
                    .foregroundColor(selected == band ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(selected == band ? Color.yellow : Color.black)
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

    /// Accensione delle 5 spie del display: S-meter in HF, voce in POC.
    var meterDots: Int {
        if band == .hf, let dBm = signalDBm {
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
                    Spacer()
                    Circle()
                        .fill(live.statusColor)
                        .frame(width: 7, height: 7)
                    Text("RX")
                        .foregroundColor(.white)
                        .font(.caption.monospaced())
                }

                Spacer(minLength: 0)

                if live.band == .hf {
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
        live.band == .hf ? "HF · \(live.currentHF.name)" : "POC · \(live.sourceName)"
    }

    private var footline: String {
        if live.band == .hf {
            if let dBm = live.signalDBm { return "\(SignalScale.label(dBm: dBm)) · \(live.sourceName)" }
            return live.sourceName
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
                    Text((live.band == .hf ? "live_receiver" : "live_server").localized + ": " + sourceText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                        .lineLimit(1)
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
    }

    private var sourceText: String {
        live.sourceName.isEmpty ? "--" : live.sourceName
    }

    private var detail: String {
        if live.band == .hf {
            let place = live.sourcePlace.isEmpty ? "" : live.sourcePlace + " · "
            return place + live.currentHF.kind.subtitle
        }
        let place = live.sourcePlace.isEmpty ? "" : live.sourcePlace + " · "
        return place + "live_listen_only_note".localized
    }
}

// MARK: - Comandi

@available(iOS 16.0, *)
struct LiveSecondaryRow: View {
    @ObservedObject var live = LiveRadio.shared
    let onList: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            circleButton("list.bullet", label: "live_channels".localized, action: onList)
            Spacer()
            if live.band == .hf {
                textButton("-1 kHz", label: "live_tune_down".localized) { live.nudge(kHz: -1) }
                Spacer()
                textButton("+1 kHz", label: "live_tune_up".localized) { live.nudge(kHz: 1) }
            } else {
                Button(action: {
                    HapticManager.shared.lightTap()
                    live.toggleScan()
                }) {
                    Text("SCAN")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(live.isScanning ? .black : .white)
                        .frame(width: 64, height: 44)
                        .background(Capsule().fill(live.isScanning ? Color.yellow : Color.black))
                }
                .accessibilityLabel("live_scan".localized)
                .accessibilityAddTraits(live.isScanning ? [.isSelected, .isButton] : .isButton)
                Spacer()
                circleButton("arrow.clockwise", label: "live_refresh".localized) { live.rescanPOC() }
                    .disabled(live.isScouting)
                    .opacity(live.isScouting ? 0.4 : 1)
            }
        }
        .padding(.horizontal, 30)
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

    private func textButton(_ text: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 72, height: 44)
                .background(Capsule().fill(Color.black))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Altoparlante e tasto

/// La griglia dell'altoparlante che si accende con l'audio vero in arrivo.
@available(iOS 16.0, *)
struct LiveSpeakerGrid: View {
    @ObservedObject var live = LiveRadio.shared
    let count: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(0 ..< count, id: \.self) { i in
                Circle()
                    .fill(Color.black)
                    .frame(width: 5, height: 5)
                    .opacity(opacity(i))
            }
        }
        .animation(.linear(duration: 0.1), value: live.level)
        .padding(.horizontal, 40)
        .accessibilityHidden(true)
    }

    /// Dal centro verso fuori, come una membrana che vibra.
    private func opacity(_ i: Int) -> Double {
        let row = Double(i / 8), col = Double(i % 8)
        let rows = Double(max(1, count / 8))
        let dx = abs(col - 3.5) / 3.5, dy = abs(row - (rows - 1) / 2) / max(1, (rows - 1) / 2)
        let reach = Double(live.level) * 1.6
        return (dx * dx + dy * dy).squareRoot() / 1.42 < reach ? 1 : 0.25
    }
}

/// Testo al centro del tasto quando il walkie ascolta HF o POC.
@available(iOS 16.0, *)
struct LivePTTFace: View {
    @ObservedObject var live = LiveRadio.shared

    var body: some View {
        VStack(spacing: 4) {
            Text("live_listen_only".localized)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Text(live.band == .hf ? "HF" : "POC")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Text("live_on_air".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .minimumScaleFactor(0.7)
    }
}

/// Riga sotto il tasto: chi parla, o lo stato del collegamento.
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

    var body: some View {
        NavigationStack {
            List {
                if live.band == .hf {
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
            .navigationTitle(live.band == .hf ? "HF" : "POC")
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
