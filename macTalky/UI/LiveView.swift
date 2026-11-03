//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveView.swift
//  macTalky
//
//  Modulo Live: onde corte e CB vere dai KiwiSDR pubblici e canali POC veri
//  su Mumble, solo in ascolto. Il motore e' in Shared/RealRadio, lo stesso
//  dell'iPhone.

import SwiftUI

struct LiveView: View {
    @ObservedObject private var live = LiveRadio.shared
    @ObservedObject private var iap = IAPManager.shared
    @Binding var showPaywall: Bool
    @State private var band: LiveRadio.Band = .hf
    @State private var typedFrequency = ""
    @State private var typedWrong = false

    var body: some View {
        VStack(spacing: 16) {
            header
            HStack(alignment: .top, spacing: 16) {
                channelList
                    .frame(width: 300)
                VStack(spacing: 16) {
                    display
                    controls
                    Spacer(minLength: 0)
                    footnote
                }
            }
        }
        .padding(24)
        .onDisappear { live.stop() }
        // Minuti gratis di oggi finiti: il Mac non ha video premio, solo Pro.
        .onChange(of: live.proPrompt) { _, prompt in
            guard prompt == .freeTime else { return }
            live.proPrompt = nil
            showPaywall = true
        }
        .onChange(of: iap.isProUser) { _, _ in live.entitlementsChanged() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            PanelLabel("Live receiver")
            Spacer()
            ForEach([LiveRadio.Band.hf, .cb, .poc], id: \.self) { b in
                Button(b == .hf ? "HF SHORTWAVE" : b == .cb ? "CB 27 MHZ" : "POC CHANNELS") {
                    band = b
                    if live.isOn { live.start(b) }
                }
                .buttonStyle(ChipButtonStyle(accent: band == b ? Talky.amber : Talky.dim, filled: band == b))
            }
            Button(live.isOn ? "STOP" : "LISTEN") {
                live.isOn ? live.stop() : live.start(band)
            }
            .buttonStyle(ChipButtonStyle(accent: live.isOn ? Talky.alarm : Talky.signal, filled: true))
            .keyboardShortcut(.space, modifiers: [])
        }
    }

    // MARK: - Channels

    private var channelList: some View {
        ConsolePanel(padding: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if band == .cb {
                        row(title: "DX 27.555",
                            subtitle: "27.555 MHz USB · SSB DX calling frequency",
                            selected: live.band == .cb && live.tuning.hz == CitizensBand.dxCall) {
                            live.tuneCB(hz: CitizensBand.dxCall)
                            if live.band != .cb { live.start(.cb) }
                        }
                        ForEach(1 ... 40, id: \.self) { n in
                            row(title: "CH \(n)",
                                subtitle: "\(Tuning(hz: CitizensBand.channels[n - 1], emission: .am, bandwidth: 0).megahertzText) MHz \(CitizensBand.usualEmission(channel: n).rawValue)",
                                selected: live.band == .cb && live.cbChannel == n) {
                                live.selectCBChannel(n)
                                if live.band != .cb { live.start(.cb) }
                            }
                        }
                    } else if band == .hf {
                        ForEach(Array(live.hfChannels.enumerated()), id: \.element.id) { i, ch in
                            row(title: ch.name,
                                subtitle: "\(ch.tuning.megahertzText) MHz \(ch.tuning.emission.rawValue) · \(kindText(ch.kind))",
                                selected: live.band == .hf && i == live.hfIndex) {
                                live.selectHF(i)
                                if live.band != .hf { live.start(.hf) }
                            }
                        }
                    } else {
                        if live.pocChannels.isEmpty {
                            HStack(spacing: 8) {
                                if live.isScouting { ProgressView().controlSize(.small) }
                                Text(live.isScouting ? "Looking for channels with people on them…" : "Press LISTEN to find live channels")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Talky.dim)
                            }
                            .padding(14)
                        }
                        ForEach(Array(live.pocChannels.enumerated()), id: \.element.id) { i, ch in
                            row(title: ch.channel,
                                subtitle: "\(ch.server.name) · \(ch.users) in channel",
                                selected: live.band == .poc && i == live.pocIndex) {
                                live.stopScan()
                                live.selectPOC(i)
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private func row(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                StatusLamp(color: Talky.signal, on: selected && live.state == .online)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.vfd(12, weight: .bold))
                        .foregroundStyle(selected ? Talky.amber : Talky.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Talky.dim)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Talky.amber.opacity(0.10) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Display

    private var display: some View {
        ConsolePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusLamp(color: statusColor, on: live.isOn)
                    Text(live.isOn ? statusText : "STANDBY")
                        .font(.vfd(10, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(live.isOn ? statusColor : Talky.dim)
                        .lineLimit(1)
                    Spacer()
                    Text("LISTEN ONLY")
                        .font(.vfd(9, weight: .bold))
                        .kerning(1.4)
                        .foregroundStyle(Talky.dim)
                }

                if band == .cb {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(cbBig)
                            .font(.vfd(48, weight: .heavy))
                            .foregroundStyle(Talky.amber)
                            .shadow(color: Talky.amberDeep.opacity(0.6), radius: 10)
                        Text(cbSmall)
                            .font(.vfd(14, weight: .bold))
                            .foregroundStyle(Talky.amber.opacity(0.8))
                        Spacer()
                        if live.squelchOn {
                            Text(live.squelchOpen ? "BUSY" : "SQL")
                                .font(.vfd(11, weight: .bold))
                                .foregroundStyle(live.squelchOpen ? Talky.signal : Talky.dim)
                        }
                        if let dBm = live.signalDBm, live.band == .cb {
                            Text(SignalScale.label(dBm: dBm))
                                .font(.vfd(18, weight: .bold))
                                .foregroundStyle(Talky.signal)
                        }
                    }
                    Text(cbLine)
                        .font(.vfd(11))
                        .foregroundStyle(live.squelchOpen ? Talky.signal : Talky.text)
                } else if band == .hf {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(live.tuning.megahertzText)
                            .font(.vfd(48, weight: .heavy))
                            .foregroundStyle(Talky.amber)
                            .shadow(color: Talky.amberDeep.opacity(0.6), radius: 10)
                        Text("MHz \(live.tuning.emission.rawValue)")
                            .font(.vfd(14, weight: .bold))
                            .foregroundStyle(Talky.amber.opacity(0.8))
                        Spacer()
                        if let dBm = live.signalDBm, live.band == .hf {
                            Text(SignalScale.label(dBm: dBm))
                                .font(.vfd(18, weight: .bold))
                                .foregroundStyle(Talky.signal)
                        }
                    }
                    Text(live.currentHF.name + " · " + kindText(live.currentHF.kind))
                        .font(.vfd(11))
                        .foregroundStyle(Talky.text)
                } else {
                    Text(live.channelName.isEmpty ? "- - -" : live.channelName.uppercased())
                        .font(.vfd(34, weight: .heavy))
                        .foregroundStyle(Talky.amber)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(pocLine)
                        .font(.vfd(11))
                        .foregroundStyle(live.talker != nil ? Talky.signal : Talky.text)
                }

                SegmentedMeter(level: meterLevel, segments: 24)

                if band == .poc || (band.isKiwi && !live.hasWaterfall && live.state == .online && !live.isOutOfFreeTime), live.isOn {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: live.state != .online)) { _ in
                        SoundBandsView(display: live.soundBands.display(), color: Talky.amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .frame(height: 230)
                }

                if band.isKiwi, live.isOn, live.hasWaterfall || live.state != .online || live.isOutOfFreeTime {
                    PanoramaView(panorama: live.panorama,
                                 tuning: live.tuning,
                                 signalDBm: live.signalDBm,
                                 words: PanoramaWords(overNoise: "%d dB ABOVE NOISE",
                                                      noiseOnly: "NOISE ONLY",
                                                      waiting: live.isOutOfFreeTime ? freeTimeUp
                                                          : live.spectrumSearching ? "LOOKING FOR A RECEIVER WITH SPECTRUM"
                                                          : live.spectrumMissing ? "NO SPECTRUM FROM THESE RECEIVERS, AUDIO ONLY"
                                                          : "WAITING FOR SPECTRUM"))
                        .frame(height: 230)
                        .onTapGesture { if live.isOutOfFreeTime { showPaywall = true } }
                }

                HStack {
                    Text((band.isKiwi ? "RECEIVER " : "SERVER ") + (live.sourceName.isEmpty ? "--" : live.sourceName.uppercased()))
                        .font(.vfd(9, weight: .semibold))
                        .foregroundStyle(Talky.dim)
                        .lineLimit(1)
                    Spacer()
                    Text(live.sourcePlace.uppercased())
                        .font(.vfd(9, weight: .semibold))
                        .foregroundStyle(Talky.dim)
                        .lineLimit(1)
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if band == .cb { cbControls }
            mainControls
        }
        .disabled(!live.isOn)
        .opacity(live.isOn ? 1 : 0.5)
    }

    /// CB: canali o DX, modo, squelch, frequenza scritta a mano.
    private var cbControls: some View {
        HStack(spacing: 10) {
            Button(live.cbIsDX ? "CHANNELS" : "DX 27.555") { live.toggleCBSection() }
                .buttonStyle(ChipButtonStyle(accent: Talky.teal))
            Button("MODE \(live.tuning.emission.rawValue)") { live.cycleCBMode() }
                .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                .help("AM, FM, LSB or USB")
            Button("SQL") { live.toggleSquelch() }
                .buttonStyle(ChipButtonStyle(accent: Talky.teal, filled: live.squelchOn))
                .help("Squelch: silence when nobody is transmitting")
            Spacer()
            TextField("27.555", text: $typedFrequency)
                .textFieldStyle(.roundedBorder)
                .font(.vfd(12))
                .frame(width: 90)
                .onSubmit(tuneTyped)
            Text("MHz")
                .font(.vfd(10))
                .foregroundStyle(typedWrong ? Talky.alarm : Talky.dim)
            Button("TUNE", action: tuneTyped)
                .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                .disabled(typedFrequency.isEmpty)
        }
    }

    /// Accetta "27.555", "27,555" e anche "27555" (kHz).
    private func tuneTyped() {
        let text = typedFrequency.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else {
            typedWrong = true
            return
        }
        typedWrong = !live.tuneCB(hz: Int((value < 100 ? value * 1_000_000 : value * 1000).rounded()))
    }

    private var mainControls: some View {
        HStack(spacing: 10) {
            Button { live.step(-1) } label: { Label("PREV", systemImage: "backward.fill") }
                .buttonStyle(ChipButtonStyle())
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button { live.step(1) } label: { Label("NEXT", systemImage: "forward.fill") }
                .buttonStyle(ChipButtonStyle())
                .keyboardShortcut(.rightArrow, modifiers: [])
            if band.isKiwi {
                Button("-1 kHz") { live.nudge(kHz: -1) }
                    .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("+1 kHz") { live.nudge(kHz: 1) }
                    .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                    .keyboardShortcut(.upArrow, modifiers: [])
            }
            if band != .hf {
                Button {
                    live.toggleScan()
                    if live.proPrompt != nil {
                        live.proPrompt = nil
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(live.isScanning ? "SCAN ON" : "SCAN")
                        if !iap.isProUser { ProBadge() }
                    }
                }
                .buttonStyle(ChipButtonStyle(accent: Talky.teal, filled: live.isScanning))
                if band == .poc {
                    Button("REFRESH") { live.rescanPOC() }
                        .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                        .disabled(live.isScouting)
                }
            }
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(Talky.dim)
            Slider(value: Binding(get: { Double(live.volume) }, set: { live.volume = Float($0) }), in: 0 ... 1)
                .frame(width: 140)
                .tint(Talky.amber)
        }
    }

    private var footnote: some View {
        Text(band == .hf
             ? "You listen through public KiwiSDR receivers, shared for free by radio amateurs around the world. Talky picks a receiver near the station."
             : band == .cb
             ? "Real CB, from the public KiwiSDR receivers nearest to you. You hear whoever is transmitting when propagation opens the band, usually during the day. With squelch on, the hiss stays muted between transmissions."
             : "Public Mumble channels with people on them right now. Talky joins muted and only listens.")
            .font(.system(size: 11))
            .foregroundStyle(Talky.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Testi

    private var meterLevel: Float {
        if live.band?.isKiwi == true, let dBm = live.signalDBm { return Float(SignalScale.fraction(dBm: dBm)) }
        return live.level
    }

    private var cbBig: String {
        live.cbChannel.map { "CH \($0)" } ?? live.tuning.megahertzText
    }

    private var cbSmall: String {
        live.cbChannel != nil ? "\(live.tuning.megahertzText) \(live.tuning.emission.rawValue)"
                              : "MHz \(live.tuning.emission.rawValue)" + (live.cbIsDX ? " · DX" : "")
    }

    private var cbLine: String {
        if live.isScanning { return live.scanHolding ? "SCAN STOPPED, SOMEONE IS TRANSMITTING" : "SCANNING" }
        if live.squelchOpen { return "SIGNAL ON THE CHANNEL" }
        return live.squelchOn ? "CHANNEL CLEAR, SQUELCH CLOSED" : "SQUELCH OFF, YOU HEAR THE BAND NOISE"
    }

    private var pocLine: String {
        if let t = live.talker { return "SPEAKING: \(t.uppercased())" }
        if live.isScanning { return live.scanHolding ? "SCAN STOPPED, SOMEONE IS TALKING" : "SCANNING" }
        if let n = live.audience { return "\(n) IN CHANNEL · NOBODY TALKING RIGHT NOW" }
        return live.sourceName.uppercased()
    }

    private var statusColor: Color {
        switch live.state {
        case .online: return Talky.signal
        case .idle, .connecting: return Talky.amber
        case .refused, .dropped: return Talky.alarm
        }
    }

    private var freeTimeUp: String { "TODAY'S \(FreeListening.secondsPerDay / 60) FREE MINUTES ARE USED" }

    private var statusText: String {
        if live.isOutOfFreeTime { return freeTimeUp }
        if let left = live.freeSecondsLeft, live.state == .online {
            return String(format: "LIVE · FREE %d:%02d", left / 60, left % 60)
        }
        if live.band == .poc, live.isScouting, live.pocChannels.isEmpty { return "SEARCHING CHANNELS" }
        switch live.state {
        case .idle, .connecting: return "CONNECTING"
        case .online: return "LIVE"
        case .refused(let p), .dropped(let p):
            switch p {
            case .full: return live.band == .poc ? "SERVER FULL" : "NO FREE RECEIVER RIGHT NOW"
            case .refused, .needsCertificate: return "ACCESS REFUSED"
            case .down: return live.band == .poc ? "NO LIVE CHANNELS, PRESS REFRESH" : "RECEIVER LIST UNREACHABLE"
            case .closed: return "LINK CLOSED"
            case .timeout: return "NO RESPONSE"
            }
        }
    }

    private func kindText(_ kind: HFChannel.Kind) -> String {
        switch kind {
        case .aviation: return "Aviation weather, around the clock"
        case .time: return "Time signal, around the clock"
        case .amateur: return "Radio amateurs, activity varies"
        case .citizens: return "CB citizens band, activity varies"
        case .digital: return "FT8 digital signals"
        }
    }
}
