//
//  WalkieActivityWidget.swift
//  TalkyLiveActivities
//
//  Live Activity / Dynamic Island presentation for walkie-talkie connected sessions.
//  Purely informational — no buttons (per design decision; PTT from LA is fragile).
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Tiny inline localization for the widget extension. Il target widget non
/// include i Localizable.strings dell'app, quindi mappiamo qui le poche stringhe
/// utente-facing in base al Locale corrente del sistema. Italiano, inglese,
/// spagnolo, malese, cinese tradizionale, indonesiano e polacco.
enum WalkieWidgetL10n {
    static let listening    = pick(it: "In ascolto", en: "Listening", es: "Escuchando", ms: "Mendengar", zh: "正在收聽", id: "Mendengarkan", pl: "Słuchasz", de: "Hört zu", fr: "À l'écoute", ja: "受信中", ko: "수신 중", pt: "Ouvindo", th: "กำลังฟัง", tr: "Dinleniyor", vi: "Đang nghe", zhHans: "正在收听")
    static let allListening = pick(it: "Tutti in ascolto", en: "All listening", es: "Todos escuchando", ms: "Semua mendengar", zh: "全員收聽", id: "Semua mendengarkan", pl: "Wszyscy słuchają", de: "Alle hören zu", fr: "Tous à l'écoute", ja: "全員が受信中", ko: "모두 수신 중", pt: "Todos ouvindo", th: "ทุกคนกำลังฟัง", tr: "Herkes dinliyor", vi: "Mọi người đang nghe", zhHans: "全员收听")
    static func talking(_ name: String) -> String {
        let tpl = pick(it: "%@ sta parlando", en: "%@ is talking", es: "%@ está hablando", ms: "%@ sedang bercakap", zh: "%@ 正在說話", id: "%@ sedang bicara", pl: "%@ mówi", de: "%@ spricht", fr: "%@ parle", ja: "%@ が話しています", ko: "%@ 님이 말하는 중", pt: "%@ está falando", th: "%@ กำลังพูด", tr: "%@ konuşuyor", vi: "%@ đang nói", zhHans: "%@ 正在说话")
        return String(format: tpl, name)
    }
    static func plusOthers(_ n: Int) -> String {
        let tpl = pick(it: "+%d altri", en: "+%d more", es: "+%d más", ms: "+%d lagi", zh: "+%d 人", id: "+%d lainnya", pl: "+%d więcej", de: "+%d weitere", fr: "+%d autres", ja: "ほか%d人", ko: "외 %d명", pt: "+%d outros", th: "+%d คน", tr: "+%d kişi daha", vi: "+%d người khác", zhHans: "+%d 人")
        return String(format: tpl, n)
    }
    static func peerCount(_ n: Int) -> String {
        let tpl = pick(it: "%d peer", en: "%d peer", es: "%d conexiones", ms: "%d peranti", zh: "%d 個設備", id: "%d perangkat", pl: "Urządzenia: %d", de: "%d Geräte", fr: "%d appareils", ja: "%d台", ko: "%d대", pt: "%d aparelhos", th: "%d เครื่อง", tr: "%d cihaz", vi: "%d thiết bị", zhHans: "%d 台设备")
        return String(format: tpl, n)
    }
    static let accPrev  = pick(it: "Stazione precedente", en: "Previous station", es: "Estación anterior", ms: "Stesen sebelumnya", zh: "上一頻道", id: "Stasiun sebelumnya", pl: "Poprzednia stacja", de: "Vorheriger Sender", fr: "Station précédente", ja: "前の局", ko: "이전 방송국", pt: "Estação anterior", th: "สถานีก่อนหน้า", tr: "Önceki istasyon", vi: "Đài trước", zhHans: "上一个电台")
    static let accNext  = pick(it: "Stazione successiva", en: "Next station", es: "Siguiente estación", ms: "Stesen seterusnya", zh: "下一頻道", id: "Stasiun berikutnya", pl: "Następna stacja", de: "Nächster Sender", fr: "Station suivante", ja: "次の局", ko: "다음 방송국", pt: "Próxima estação", th: "สถานีถัดไป", tr: "Sonraki istasyon", vi: "Đài tiếp theo", zhHans: "下一个电台")
    static let accPlay  = pick(it: "Riproduci", en: "Play", es: "Reproducir", ms: "Main", zh: "播放", id: "Putar", pl: "Odtwórz", de: "Abspielen", fr: "Lire", ja: "再生", ko: "재생", pt: "Reproduzir", th: "เล่น", tr: "Oynat", vi: "Phát", zhHans: "播放")
    static let accPause = pick(it: "Pausa", en: "Pause", es: "Pausa", ms: "Jeda", zh: "暫停", id: "Jeda", pl: "Pauza", de: "Pause", fr: "Pause", ja: "一時停止", ko: "일시정지", pt: "Pausar", th: "หยุดชั่วคราว", tr: "Duraklat", vi: "Tạm dừng", zhHans: "暂停")

    private static func pick(it: String, en: String, es: String, ms: String, zh: String, id: String, pl: String,
                             de: String, fr: String, ja: String, ko: String, pt: String, th: String, tr: String,
                             vi: String, zhHans: String) -> String {
        let code: String
        let script: String
        if #available(iOS 16, *) {
            code = Locale.current.language.languageCode?.identifier ?? "en"
            script = Locale.current.language.script?.identifier ?? ""
        } else {
            code = Locale.current.languageCode ?? "en"
            script = Locale.current.scriptCode ?? ""
        }
        switch code.lowercased() {
        case "it": return it
        case "es": return es
        case "ms": return ms
        // Il cinese semplificato prima cadeva sul tradizionale.
        case "zh": return script == "Hans" ? zhHans : zh
        case "id": return id
        case "pl": return pl
        case "de": return de
        case "fr": return fr
        case "ja": return ja
        case "ko": return ko
        case "pt": return pt
        case "th": return th
        case "tr": return tr
        case "vi": return vi
        default:   return en
        }
    }
}

@available(iOS 16.2, *)
struct WalkieActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkieActivityAttributes.self) { context in
            WalkieLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.65))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "talky://walkie"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WalkieLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WalkieTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    WalkieCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WalkieBottomView(state: context.state)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("\(context.state.connectedPeerCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                Text(context.state.channelName.prefix(8).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.state.talkerName != nil ? Color.red : Color.green)
                    .lineLimit(1)
            } minimal: {
                ZStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(context.state.talkerName != nil ? Color.red : Color.green)
                    if context.state.talkerName != nil {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 1.2)
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .widgetURL(URL(string: "talky://walkie"))
            .keylineTint(.green)
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct WalkieLockScreenView: View {
    let state: WalkieActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .shadow(color: .green.opacity(0.4), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.channelName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(peerSummary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
                ConnectionPill(count: state.connectedPeerCount, talking: state.talkerName != nil)
            }
            if let talker = state.talkerName {
                TalkerBanner(name: talker)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var peerSummary: String {
        if state.peerNames.isEmpty {
            return WalkieWidgetL10n.peerCount(state.connectedPeerCount)
        }
        let first = state.peerNames.prefix(2).joined(separator: ", ")
        let extra = state.connectedPeerCount - min(2, state.peerNames.count)
        return extra > 0 ? "\(first) +\(extra)" : first
    }
}

// MARK: - Expanded regions

@available(iOS 16.2, *)
private struct WalkieLeadingView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(state.channelName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(WalkieWidgetL10n.peerCount(state.connectedPeerCount))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

@available(iOS 16.2, *)
private struct WalkieTrailingView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        ConnectionPill(count: state.connectedPeerCount, talking: state.talkerName != nil)
    }
}

@available(iOS 16.2, *)
private struct WalkieCenterView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.peerNames.isEmpty {
                Text(WalkieWidgetL10n.listening)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(state.peerNames.prefix(3), id: \.self) { name in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green.opacity(state.talkerName == name ? 1.0 : 0.6))
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.system(size: 12, weight: state.talkerName == name ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                if state.connectedPeerCount > state.peerNames.count {
                    Text(WalkieWidgetL10n.plusOthers(state.connectedPeerCount - state.peerNames.count))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.2, *)
private struct WalkieBottomView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        if let talker = state.talkerName {
            TalkerBanner(name: talker)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "ear")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                Text(WalkieWidgetL10n.allListening)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Helpers

@available(iOS 16.2, *)
private struct ConnectionPill: View {
    let count: Int
    let talking: Bool
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(talking ? Color.red : Color.green)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white.opacity(0.14))
        )
    }
}

@available(iOS 16.2, *)
private struct TalkerBanner: View {
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Group {
                if #available(iOS 17.0, *) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else {
                    Image(systemName: "waveform")
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.red)
            Text(WalkieWidgetL10n.talking(name))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.red.opacity(0.25))
        )
    }
}
