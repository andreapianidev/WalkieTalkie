//creato da Andrea Piani - Immaginet Srl - 02/08/26 - https://www.andreapiani.com - OnboardingView.swift
//  macTalky
//
//  Onboarding al primo avvio, replicato dallo spirito di quello iOS ma in
//  forma di sheet desktop: 3 pagine (Walkie, Rete+Microfono, Radio+Pro).
//  Localizzato in-code in 14 lingue (le 13 dell'App Store + malese, come iOS).

import SwiftUI

// MARK: - Localizzazione onboarding

/// Stringhe dell'onboarding per lingua. Chiave = code ISO 639-1 (+ script per il cinese).
private enum OBString {
    case welcomeTitle, welcomeBody
    case networkTitle, networkBody, micButton, micGranted
    case radioTitle, radioBody
    case proNote
    case next, back, start, skip

    var text: String {
        let lang = Self.languageKey
        return Self.table[lang]?[self] ?? Self.table["en"]![self]!
    }

    private static var languageKey: String {
        let locale = Locale.current
        let code = locale.language.languageCode?.identifier ?? "en"
        if code == "zh" {
            let script = locale.language.script?.identifier ?? "Hans"
            return script == "Hant" ? "zh-Hant" : "zh-Hans"
        }
        return code
    }

    private static let table: [String: [OBString: String]] = [
        "en": [
            .welcomeTitle: "Your Mac is now a walkie-talkie",
            .welcomeBody: "Hold the big TALK key — or the Space bar — to speak. Release to listen. One voice at a time, like a real radio.",
            .networkTitle: "No internet. No accounts.",
            .networkBody: "macTalky finds Talky devices (iPhone, Android, Mac) on your Wi-Fi network automatically. Grant microphone access to transmit your voice.",
            .micButton: "Enable microphone",
            .micGranted: "Microphone authorized",
            .radioTitle: "343 world radio stations",
            .radioBody: "Switch to the Radio module for verified stations from 50+ countries, with favorites, filters and media keys.",
            .proNote: "Talky Pro and the Themes Pack are shared with the iOS app: one purchase unlocks iPhone, iPad and Mac.",
            .next: "Continue", .back: "Back", .start: "Start", .skip: "Skip",
        ],
        "it": [
            .welcomeTitle: "Il tuo Mac ora è un walkie-talkie",
            .welcomeBody: "Tieni premuto il grande tasto TALK — o la barra spaziatrice — per parlare. Rilascia per ascoltare. Una voce alla volta, come una radio vera.",
            .networkTitle: "Niente internet. Niente account.",
            .networkBody: "macTalky trova i dispositivi Talky (iPhone, Android, Mac) sulla tua rete Wi-Fi automaticamente. Concedi il microfono per trasmettere la voce.",
            .micButton: "Attiva microfono",
            .micGranted: "Microfono autorizzato",
            .radioTitle: "343 stazioni radio dal mondo",
            .radioBody: "Passa al modulo Radio per stazioni verificate da oltre 50 Paesi, con preferiti, filtri e tasti multimediali.",
            .proNote: "Talky Pro e il Pacchetto Temi sono condivisi con l'app iOS: un solo acquisto sblocca iPhone, iPad e Mac.",
            .next: "Continua", .back: "Indietro", .start: "Inizia", .skip: "Salta",
        ],
        "de": [
            .welcomeTitle: "Dein Mac ist jetzt ein Funkgerät",
            .welcomeBody: "Halte die große TALK-Taste — oder die Leertaste — gedrückt, um zu sprechen. Loslassen zum Zuhören. Eine Stimme nach der anderen, wie bei einem echten Funkgerät.",
            .networkTitle: "Kein Internet. Keine Konten.",
            .networkBody: "macTalky findet Talky-Geräte (iPhone, Android, Mac) in deinem WLAN automatisch. Erlaube den Mikrofonzugriff, um deine Stimme zu übertragen.",
            .micButton: "Mikrofon aktivieren",
            .micGranted: "Mikrofon autorisiert",
            .radioTitle: "343 Radiosender aus aller Welt",
            .radioBody: "Wechsle zum Radio-Modul: verifizierte Sender aus über 50 Ländern, mit Favoriten, Filtern und Medientasten.",
            .proNote: "Talky Pro und das Themes-Paket werden mit der iOS-App geteilt: Ein Kauf schaltet iPhone, iPad und Mac frei.",
            .next: "Weiter", .back: "Zurück", .start: "Los geht's", .skip: "Überspringen",
        ],
        "es": [
            .welcomeTitle: "Tu Mac ahora es un walkie-talkie",
            .welcomeBody: "Mantén pulsada la gran tecla TALK — o la barra espaciadora — para hablar. Suelta para escuchar. Una voz a la vez, como una radio de verdad.",
            .networkTitle: "Sin internet. Sin cuentas.",
            .networkBody: "macTalky encuentra automáticamente los dispositivos Talky (iPhone, Android, Mac) en tu red Wi-Fi. Concede acceso al micrófono para transmitir tu voz.",
            .micButton: "Activar micrófono",
            .micGranted: "Micrófono autorizado",
            .radioTitle: "343 emisoras de radio del mundo",
            .radioBody: "Cambia al módulo Radio: emisoras verificadas de más de 50 países, con favoritos, filtros y teclas multimedia.",
            .proNote: "Talky Pro y el Pack de Temas se comparten con la app de iOS: una sola compra desbloquea iPhone, iPad y Mac.",
            .next: "Continuar", .back: "Atrás", .start: "Empezar", .skip: "Saltar",
        ],
        "fr": [
            .welcomeTitle: "Votre Mac est maintenant un talkie-walkie",
            .welcomeBody: "Maintenez la grande touche TALK — ou la barre d'espace — pour parler. Relâchez pour écouter. Une voix à la fois, comme une vraie radio.",
            .networkTitle: "Pas d'internet. Pas de compte.",
            .networkBody: "macTalky trouve automatiquement les appareils Talky (iPhone, Android, Mac) sur votre réseau Wi-Fi. Autorisez le micro pour transmettre votre voix.",
            .micButton: "Activer le micro",
            .micGranted: "Micro autorisé",
            .radioTitle: "343 stations de radio du monde",
            .radioBody: "Passez au module Radio : stations vérifiées de plus de 50 pays, avec favoris, filtres et touches multimédia.",
            .proNote: "Talky Pro et le Pack de thèmes sont partagés avec l'app iOS : un seul achat débloque iPhone, iPad et Mac.",
            .next: "Continuer", .back: "Retour", .start: "Commencer", .skip: "Passer",
        ],
        "ja": [
            .welcomeTitle: "Macがトランシーバーに",
            .welcomeBody: "大きなTALKキー、またはスペースキーを押し続けて話します。離すと受信。本物の無線機のように、一度に一人ずつ。",
            .networkTitle: "インターネット不要。アカウント不要。",
            .networkBody: "macTalkyはWi-Fiネットワーク上のTalkyデバイス(iPhone、Android、Mac)を自動で見つけます。声を送信するにはマイクを許可してください。",
            .micButton: "マイクを有効にする",
            .micGranted: "マイク許可済み",
            .radioTitle: "世界343のラジオ局",
            .radioBody: "ラジオモジュールに切り替えると、50か国以上の検証済みステーションをお気に入り・フィルタ・メディアキーで楽しめます。",
            .proNote: "Talky ProとテーマパックはiOSアプリと共通。1回の購入でiPhone・iPad・Macすべてで使えます。",
            .next: "続ける", .back: "戻る", .start: "開始", .skip: "スキップ",
        ],
        "ko": [
            .welcomeTitle: "Mac이 워키토키가 됩니다",
            .welcomeBody: "큰 TALK 버튼이나 스페이스바를 누른 채 말하세요. 놓으면 수신합니다. 진짜 무전기처럼 한 번에 한 명씩.",
            .networkTitle: "인터넷 불필요. 계정 불필요.",
            .networkBody: "macTalky는 Wi-Fi 네트워크의 Talky 기기(iPhone, Android, Mac)를 자동으로 찾습니다. 음성을 전송하려면 마이크를 허용하세요.",
            .micButton: "마이크 활성화",
            .micGranted: "마이크 허용됨",
            .radioTitle: "세계 343개 라디오 방송국",
            .radioBody: "라디오 모듈로 전환하면 50개국 이상의 검증된 방송국을 즐겨찾기, 필터, 미디어 키와 함께 들을 수 있습니다.",
            .proNote: "Talky Pro와 테마 팩은 iOS 앱과 공유됩니다. 한 번 구매로 iPhone, iPad, Mac 모두 잠금 해제.",
            .next: "계속", .back: "뒤로", .start: "시작", .skip: "건너뛰기",
        ],
        "pt": [
            .welcomeTitle: "Seu Mac agora é um walkie-talkie",
            .welcomeBody: "Segure a grande tecla TALK — ou a barra de espaço — para falar. Solte para ouvir. Uma voz por vez, como um rádio de verdade.",
            .networkTitle: "Sem internet. Sem contas.",
            .networkBody: "O macTalky encontra automaticamente os dispositivos Talky (iPhone, Android, Mac) na sua rede Wi-Fi. Conceda o microfone para transmitir sua voz.",
            .micButton: "Ativar microfone",
            .micGranted: "Microfone autorizado",
            .radioTitle: "343 estações de rádio do mundo",
            .radioBody: "Mude para o módulo Rádio: estações verificadas de mais de 50 países, com favoritos, filtros e teclas de mídia.",
            .proNote: "O Talky Pro e o Pacote de Temas são compartilhados com o app iOS: uma compra desbloqueia iPhone, iPad e Mac.",
            .next: "Continuar", .back: "Voltar", .start: "Começar", .skip: "Pular",
        ],
        "th": [
            .welcomeTitle: "Mac ของคุณคือวิทยุสื่อสารแล้ว",
            .welcomeBody: "กดปุ่ม TALK ขนาดใหญ่ — หรือแป้น Space — ค้างไว้เพื่อพูด ปล่อยเพื่อฟัง ทีละเสียงเหมือนวิทยุจริง",
            .networkTitle: "ไม่ต้องใช้อินเทอร์เน็ต ไม่ต้องมีบัญชี",
            .networkBody: "macTalky ค้นหาอุปกรณ์ Talky (iPhone, Android, Mac) บนเครือข่าย Wi-Fi โดยอัตโนมัติ อนุญาตไมโครโฟนเพื่อส่งเสียงของคุณ",
            .micButton: "เปิดใช้ไมโครโฟน",
            .micGranted: "อนุญาตไมโครโฟนแล้ว",
            .radioTitle: "วิทยุ 343 สถานีทั่วโลก",
            .radioBody: "สลับไปที่โมดูลวิทยุ: สถานีที่ตรวจสอบแล้วจากกว่า 50 ประเทศ พร้อมรายการโปรด ตัวกรอง และปุ่มมีเดีย",
            .proNote: "Talky Pro และแพ็กธีมใช้ร่วมกับแอป iOS: ซื้อครั้งเดียวปลดล็อกทั้ง iPhone, iPad และ Mac",
            .next: "ต่อไป", .back: "ย้อนกลับ", .start: "เริ่ม", .skip: "ข้าม",
        ],
        "tr": [
            .welcomeTitle: "Mac'iniz artık bir telsiz",
            .welcomeBody: "Konuşmak için büyük TALK tuşunu — veya boşluk tuşunu — basılı tutun. Dinlemek için bırakın. Gerçek bir telsiz gibi, aynı anda tek ses.",
            .networkTitle: "İnternet yok. Hesap yok.",
            .networkBody: "macTalky, Wi-Fi ağınızdaki Talky cihazlarını (iPhone, Android, Mac) otomatik bulur. Sesinizi iletmek için mikrofona izin verin.",
            .micButton: "Mikrofonu etkinleştir",
            .micGranted: "Mikrofon izni verildi",
            .radioTitle: "Dünyadan 343 radyo istasyonu",
            .radioBody: "Radyo modülüne geçin: 50'den fazla ülkeden doğrulanmış istasyonlar, favoriler, filtreler ve medya tuşlarıyla.",
            .proNote: "Talky Pro ve Tema Paketi iOS uygulamasıyla ortaktır: tek satın alma iPhone, iPad ve Mac'i açar.",
            .next: "Devam", .back: "Geri", .start: "Başla", .skip: "Atla",
        ],
        "vi": [
            .welcomeTitle: "Mac của bạn giờ là bộ đàm",
            .welcomeBody: "Giữ phím TALK lớn — hoặc phím Space — để nói. Thả ra để nghe. Mỗi lần một giọng nói, như bộ đàm thật.",
            .networkTitle: "Không cần internet. Không cần tài khoản.",
            .networkBody: "macTalky tự động tìm các thiết bị Talky (iPhone, Android, Mac) trên mạng Wi-Fi của bạn. Cho phép micrô để truyền giọng nói.",
            .micButton: "Bật micrô",
            .micGranted: "Đã cho phép micrô",
            .radioTitle: "343 đài radio khắp thế giới",
            .radioBody: "Chuyển sang mô-đun Radio: các đài đã xác minh từ hơn 50 quốc gia, với yêu thích, bộ lọc và phím media.",
            .proNote: "Talky Pro và Gói chủ đề dùng chung với ứng dụng iOS: mua một lần, mở khóa iPhone, iPad và Mac.",
            .next: "Tiếp tục", .back: "Quay lại", .start: "Bắt đầu", .skip: "Bỏ qua",
        ],
        "ms": [
            .welcomeTitle: "Mac anda kini walkie-talkie",
            .welcomeBody: "Tahan kekunci TALK besar — atau bar Space — untuk bercakap. Lepaskan untuk mendengar. Satu suara pada satu masa, seperti radio sebenar.",
            .networkTitle: "Tiada internet. Tiada akaun.",
            .networkBody: "macTalky mencari peranti Talky (iPhone, Android, Mac) pada rangkaian Wi-Fi anda secara automatik. Benarkan mikrofon untuk menghantar suara anda.",
            .micButton: "Aktifkan mikrofon",
            .micGranted: "Mikrofon dibenarkan",
            .radioTitle: "343 stesen radio dunia",
            .radioBody: "Tukar ke modul Radio: stesen yang disahkan dari lebih 50 negara, dengan kegemaran, penapis dan kekunci media.",
            .proNote: "Talky Pro dan Pek Tema dikongsi dengan apl iOS: satu pembelian membuka iPhone, iPad dan Mac.",
            .next: "Teruskan", .back: "Kembali", .start: "Mula", .skip: "Langkau",
        ],
        "zh-Hans": [
            .welcomeTitle: "你的 Mac 现在是一台对讲机",
            .welcomeBody: "按住大大的 TALK 键——或空格键——即可说话。松开即收听。一次一个声音,就像真正的对讲机。",
            .networkTitle: "无需互联网。无需账号。",
            .networkBody: "macTalky 会自动发现 Wi-Fi 网络中的 Talky 设备(iPhone、Android、Mac)。授权麦克风即可传输语音。",
            .micButton: "启用麦克风",
            .micGranted: "麦克风已授权",
            .radioTitle: "343 个全球电台",
            .radioBody: "切换到电台模块:来自 50 多个国家的经过验证的电台,支持收藏、筛选和媒体键。",
            .proNote: "Talky Pro 和主题包与 iOS 应用通用:一次购买,解锁 iPhone、iPad 和 Mac。",
            .next: "继续", .back: "返回", .start: "开始", .skip: "跳过",
        ],
        "zh-Hant": [
            .welcomeTitle: "你的 Mac 現在是一台對講機",
            .welcomeBody: "按住大大的 TALK 鍵——或空白鍵——即可說話。放開即收聽。一次一個聲音,就像真正的對講機。",
            .networkTitle: "無需網際網路。無需帳號。",
            .networkBody: "macTalky 會自動發現 Wi-Fi 網路中的 Talky 裝置(iPhone、Android、Mac)。授權麥克風即可傳送語音。",
            .micButton: "啟用麥克風",
            .micGranted: "麥克風已授權",
            .radioTitle: "343 個全球電台",
            .radioBody: "切換到電台模組:來自 50 多個國家的已驗證電台,支援收藏、篩選與媒體鍵。",
            .proNote: "Talky Pro 與主題包與 iOS 應用程式通用:一次購買,解鎖 iPhone、iPad 與 Mac。",
            .next: "繼續", .back: "返回", .start: "開始", .skip: "略過",
        ],
    ]
}

// MARK: - View

struct OnboardingView: View {
    @EnvironmentObject private var engine: WalkieEngine
    @Environment(\.dismiss) private var dismiss

    var onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 26)

            Group {
                switch page {
                case 0: pageView(icon: "mic.circle.fill",
                                 tint: Talky.signal,
                                 title: OBString.welcomeTitle.text,
                                 body: OBString.welcomeBody.text)
                case 1: networkPage
                default: radioPage
                }
            }
            .frame(maxHeight: .infinity)

            // Dots
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Talky.amber : Talky.dim.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 18)

            // Controls
            HStack {
                Button(OBString.skip.text) { finish() }
                    .buttonStyle(ChipButtonStyle(accent: Talky.dim))

                Spacer()

                if page > 0 {
                    Button(OBString.back.text) {
                        withAnimation(.easeOut(duration: 0.18)) { page -= 1 }
                    }
                    .buttonStyle(ChipButtonStyle(accent: Talky.dim))
                }

                Button(page == pageCount - 1 ? OBString.start.text : OBString.next.text) {
                    if page == pageCount - 1 {
                        finish()
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) { page += 1 }
                    }
                }
                .buttonStyle(ChipButtonStyle(filled: true))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
        .frame(width: 480, height: 430)
        .background(Talky.coal)
    }

    private func finish() {
        onFinish()
        dismiss()
    }

    // MARK: - Pages

    private func pageView(icon: String, tint: Color, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.6), radius: 14)
            Text(title)
                .font(.talkyTitle(21))
                .foregroundStyle(Talky.text)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Talky.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
    }

    private var networkPage: some View {
        VStack(spacing: 16) {
            pageView(icon: "wifi.circle.fill",
                     tint: Talky.teal,
                     title: OBString.networkTitle.text,
                     body: OBString.networkBody.text)
            if engine.hasMicPermission {
                Label(OBString.micGranted.text, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Talky.signal)
            } else {
                Button(OBString.micButton.text) { engine.requestMicPermission() }
                    .buttonStyle(ChipButtonStyle(accent: Talky.amber, filled: true))
            }
        }
    }

    private var radioPage: some View {
        VStack(spacing: 16) {
            pageView(icon: "antenna.radiowaves.left.and.right.circle.fill",
                     tint: Talky.amber,
                     title: OBString.radioTitle.text,
                     body: OBString.radioBody.text)
            Text(OBString.proNote.text)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Talky.dim.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 46)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
