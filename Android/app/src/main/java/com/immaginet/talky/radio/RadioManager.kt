package com.immaginet.talky.radio

import android.media.AudioAttributes
import android.media.MediaPlayer
import java.io.Closeable

class RadioManager : Closeable {

    private var mediaPlayer: MediaPlayer? = null
    private var currentStationId: Int = -1
    private var currentStationName: String = ""
    private var currentStationCountry: String = ""
    private var isPlayingState: Boolean = false
    private var onStatusChanged: ((RadioStatus) -> Unit)? = null

    data class RadioStatus(
        val isPlaying: Boolean,
        val stationName: String,
        val stationCountry: String,
        val isBuffering: Boolean,
        val error: String?
    )

    companion object {
        val stations: List<RadioStation> = listOf(
            RadioStation(1, "RTL 102.5", "Italia", "102.5", "https://streamingv2.shoutcast.com/rtl-1025", "Pop"),
            RadioStation(2, "Radio Deejay", "Italia", "106.2", "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiodeejay/radiodeejay/master_ma.m3u8", "Pop"),
            RadioStation(3, "Rai Radio 1", "Italia", "89.7", "http://icestreaming.rai.it/1.mp3", "News"),
            RadioStation(4, "Rai Radio 2", "Italia", "91.7", "http://icestreaming.rai.it/2.mp3", "Pop"),
            RadioStation(5, "Rai Radio 3", "Italia", "93.7", "http://icestreaming.rai.it/3.mp3", "Classical"),
            RadioStation(6, "Radio Italia", "Italia", "98.7", "https://radioitaliasmi.akamaized.net/hls/live/2093120/RISMI/stream01/streamPlaylist.m3u8", "Italian"),
            RadioStation(7, "Radio 24", "Italia", "104.4", "http://shoutcast2.radio24.it:8000/", "News"),
            RadioStation(8, "Radio 105", "Italia", "105.0", "http://icecast.unitedradio.it/Radio105.mp3", "Pop"),
            RadioStation(9, "Virgin Radio Italia", "Italia", "104.5", "http://icecast.unitedradio.it/Virgin.mp3", "Rock"),
            RadioStation(10, "Radio Capital", "Italia", "103.0", "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiocapital/radiocapital/master_ma.m3u8", "Rock"),
            RadioStation(11, "Radio Kiss Kiss", "Italia", "97.0", "http://wma08.fluidstream.net:4610/", "Pop"),
            RadioStation(12, "RMC Radio Monte Carlo", "Italia", "100.7", "http://icecast.unitedradio.it/RMC.mp3", "Easy"),
            RadioStation(13, "RDS", "Italia", "100.3", "https://stream.rds.radio/audio/rds.stream_aac64/chunklist.m3u8", "Pop"),
            RadioStation(14, "Radio M2O", "Italia", "92.8", "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiom2o/radiom2o/master_ma.m3u8", "Dance"),
            RadioStation(15, "Radio Freccia", "Italia", "94.5", "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S3160845/0tuSetc8UFkF/playlist_audio.m3u8", "Rock"),
            RadioStation(16, "NRJ", "Francia", "100.3", "https://streaming.nrjaudio.fm/oumvmk8fnozc", "Pop"),
            RadioStation(17, "France Inter", "Francia", "87.8", "http://icecast.radiofrance.fr/franceinter-hifi.aac", "Talk"),
            RadioStation(18, "France Info", "Francia", "105.5", "http://direct.franceinfo.fr/live/franceinfo-midfi.mp3", "News"),
            RadioStation(19, "FIP", "Francia", "105.1", "http://icecast.radiofrance.fr/fip-hifi.aac", "Eclectic"),
            RadioStation(20, "Antenne Bayern", "Germania", "103.2", "https://s1-webradio.antenne.de/antenne", "Pop"),
            RadioStation(21, "1LIVE", "Germania", "106.7", "http://wdr-1live-live.icecast.wdr.de/wdr/1live/live/mp3/128/stream.mp3", "Pop"),
            RadioStation(22, "SWR3", "Germania", "99.9", "https://liveradio.swr.de/sw282p3/swr3/play.mp3", "Pop"),
            RadioStation(23, "BBC Radio 2", "UK", "88.0", "http://as-hls-ww-live.akamaized.net/pool_74208725/live/ww/bbc_radio_two/bbc_radio_two.isml/bbc_radio_two-audio%3d128000.norewind.m3u8", "Pop"),
            RadioStation(24, "BBC Radio 4", "UK", "92.4", "http://as-hls-ww-live.akamaized.net/pool_55057080/live/ww/bbc_radio_fourfm/bbc_radio_fourfm.isml/bbc_radio_fourfm-audio%3d128000.norewind.m3u8", "Talk"),
            RadioStation(25, "BBC World Service", "UK", "648", "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service", "News"),
            RadioStation(26, "Capital FM", "UK", "95.8", "https://media-ssl.musicradio.com/CapitalMP3", "Pop"),
            RadioStation(27, "Los 40", "Spagna", "93.9", "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40.mp3", "Pop"),
            RadioStation(28, "Cadena SER", "Spagna", "105.4", "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENASER.mp3", "News"),
            RadioStation(29, "Radio 538", "Olanda", "102.1", "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO538.mp3", "Dance"),
            RadioStation(30, "Studio Brussel", "Belgio", "100.7", "https://icecast.vrtcdn.be/stubru-high.mp3", "Alternative"),
            RadioStation(31, "Europe 1", "Francia", "104.7", "https://europe1.lmn.fm/europe1.mp3", "News"),
            RadioStation(32, "BBC Radio 6 Music", "UK", "—", "http://as-hls-ww-live.akamaized.net/pool_81827798/live/ww/bbc_6music/bbc_6music.isml/bbc_6music-audio%3d320000.norewind.m3u8", "Alternative"),
            RadioStation(33, "Classic FM", "UK", "100.0", "http://ice-the.musicradio.com/ClassicFMMP3", "Classical"),
            RadioStation(34, "LBC", "UK", "97.3", "http://media-ice.musicradio.com/LBCUK", "Talk"),
            RadioStation(35, "Cadena 100", "Spagna", "100.0", "http://cadena100-streamers-mp3.flumotion.com/cope/cadena100.mp3", "Pop"),
            RadioStation(36, "Radio Paradise", "USA", "—", "http://stream-uk1.radioparadise.com/aac-320", "Eclectic"),
            RadioStation(37, "101 Smooth Jazz", "USA", "101.0", "http://jking.cdnstream1.com/b22139_128mp3", "Jazz"),
            RadioStation(38, "Classic Vinyl HD", "USA", "—", "https://icecast.walmradio.com:8443/classic", "Oldies"),
            RadioStation(39, "Adroit Jazz Underground", "USA", "—", "https://icecast.walmradio.com:8443/jazz", "Jazz"),
            RadioStation(40, "Triple J", "Australia", "105.7", "https://live-radio01.mediahubaustralia.com/2TJW/mp3/", "Alternative"),
            RadioStation(41, "ABC News Radio", "Australia", "630", "http://abc.streamguys1.com/live/newsradio/icecast.audio", "News"),
            RadioStation(42, "2GB Sydney", "Australia", "873", "http://playerservices.streamtheworld.com/api/livestream-redirect/2GB.mp3", "Talk"),
            RadioStation(43, "NPO Radio 2", "Olanda", "92.6", "http://icecast.omroep.nl/radio2-bb-mp3", "Pop"),
            RadioStation(44, "Qmusic", "Olanda", "100.7", "https://icecast-qmusicnl-cdp.triple-it.nl/Qmusic_nl_live_96.mp3", "Pop"),
            RadioStation(45, "VRT Radio 1", "Belgio", "91.7", "http://icecast.vrtcdn.be/radio1-high.mp3", "Talk"),
            RadioStation(46, "Joe", "Belgio", "95.0", "https://icecast-qmusicbe-cdp.triple-it.nl/joe.mp3", "Oldies"),
            RadioStation(47, "Energy Zurich", "Svizzera", "100.9", "https://energyzuerich.ice.infomaniak.ch/energyzuerich-high.mp3", "Dance"),
            RadioStation(48, "SRF 3", "Svizzera", "99.1", "http://stream.srg-ssr.ch/m/drs3/mp3_128", "Pop"),
            RadioStation(49, "Radio Swiss Jazz", "Svizzera", "—", "http://stream.srg-ssr.ch/m/rsj/mp3_128", "Jazz"),
            RadioStation(50, "Ö3 Hitradio", "Austria", "99.9", "https://orf-live.ors-shoutcast.at/oe3-q2a", "Pop"),
            RadioStation(51, "FM4", "Austria", "103.8", "https://orf-live.ors-shoutcast.at/fm4-q2a", "Alternative"),
            RadioStation(52, "NRK P3", "Norvegia", "92.0", "https://cdn0-47115-liveicecast0.dna.contentdelivery.net/p3_mp3_h", "Pop"),
            RadioStation(53, "P4 Norge", "Norvegia", "100.7", "https://p4.p4groupaudio.com/P04_AH", "Pop"),
            RadioStation(54, "DR P3", "Danimarca", "96.5", "http://live-icy.gslb01.dr.dk/A/A05H.mp3", "Pop"),
            RadioStation(55, "Nova FM", "Danimarca", "94.6", "https://live-bauerdk.sharp-stream.com/nova_dk_mp3", "Pop"),
            RadioStation(56, "Sveriges Radio P3", "Svezia", "99.3", "https://live1.sr.se/p3-mp3-96", "Pop"),
            RadioStation(57, "RIX FM", "Svezia", "106.7", "https://fm01-ice.stream.khz.se/fm01_mp3", "Pop"),
            RadioStation(58, "Bandit Rock", "Svezia", "106.3", "http://fm02-ice.stream.khz.se/fm02_mp3", "Rock"),
            RadioStation(59, "Yle Radio Suomi", "Finlandia", "94.0", "http://icecast.live.yle.fi/radio/YleRS/icecast.audio", "Talk"),
            RadioStation(60, "YleX", "Finlandia", "91.9", "http://icecast.live.yle.fi/radio/YleX/icecast.audio", "Pop"),
            RadioStation(61, "Bylgjan", "Islanda", "98.9", "http://icecast.365net.is:8000/orbbylgjan.aac", "Pop"),
            RadioStation(62, "Rás 2", "Islanda", "90.1", "http://netradio.ruv.is/ras2.aac", "Pop"),
            RadioStation(63, "RMF FM", "Polonia", "102.8", "http://195.150.20.242:8000/rmf_fm", "Pop"),
            RadioStation(64, "Radio Zet", "Polonia", "90.9", "http://zet-net-01.cdn.eurozet.pl:8400/", "Pop"),
            RadioStation(65, "Radio 357", "Polonia", "—", "https://n-11-21.dcs.redcdn.pl/sc/o2/radio357/live/radio357_pr.livx?preroll=0", "Talk"),
            RadioStation(66, "Evropa 2", "Rep. Ceca", "88.2", "https://ice.actve.net/fm-evropa2-128", "Pop"),
            RadioStation(67, "Frekvence 1", "Rep. Ceca", "102.5", "https://ice.actve.net/fm-frekvence1-128", "Pop"),
            RadioStation(68, "Fun Radio", "Slovacchia", "94.3", "http://stream.funradio.sk:8000/fun128.mp3", "Pop"),
            RadioStation(69, "Rádio Expres", "Slovacchia", "92.5", "https://stream.bauermedia.sk/128.mp3", "Pop"),
            RadioStation(70, "Radio 1", "Slovenia", "94.9", "http://live.radio.si/Radio1", "Pop"),
            RadioStation(71, "Val 202", "Slovenia", "98.9", "http://mp3.rtvslo.si/val202", "Pop"),
            RadioStation(72, "Otvoreni Radio", "Croazia", "97.1", "http://stream.otvoreni.hr/otvoreni", "Pop"),
            RadioStation(73, "Extra FM", "Croazia", "93.6", "http://streams.extrafm.hr:8110/", "Pop"),
            RadioStation(74, "Naxi ExYu", "Serbia", "—", "https://naxidigital-exyu128ssl.streaming.rs:8242/", "Pop"),
            RadioStation(75, "BG Radio", "Bulgaria", "91.9", "http://stream.radioreklama.bg/bgradio128", "Pop"),
            RadioStation(76, "NRJ Bulgaria", "Bulgaria", "104.5", "http://play.global.audio/nrj128", "Pop"),
            RadioStation(77, "Vikerraadio", "Estonia", "104.1", "http://icecast.err.ee/vikerraadio.mp3", "Talk"),
            RadioStation(78, "Retro FM Estonia", "Estonia", "92.8", "https://edge02.cdn.bitflip.ee:8888/RETRO?_i=258f436b", "Oldies"),
            RadioStation(79, "Radio SWH", "Lettonia", "105.2", "http://80.232.162.149:8000/swh96mp3", "Pop"),
            RadioStation(80, "M-1 Plius", "Lituania", "106.8", "http://radio.m-1.fm/m1plius/mp3", "Pop"),
            RadioStation(81, "Retro Rádió", "Ungheria", "104.2", "https://icast.connectmedia.hu/5001/live.mp3", "Oldies"),
            RadioStation(82, "Klubrádió", "Ungheria", "92.9", "https://a7.asurahosting.com:8160/radio.mp3", "Talk"),
            RadioStation(83, "Kiss FM", "Romania", "96.1", "https://live.kissfm.ro/kissfm.aacp", "Pop"),
            RadioStation(84, "Radio România", "Romania", "98.6", "http://89.238.227.6:8006/", "News"),
            RadioStation(85, "Hit FM", "Ucraina", "96.4", "http://195.95.206.17/HitFM", "Pop"),
            RadioStation(86, "Kiss FM Ukraine", "Ucraina", "106.5", "http://online.kissfm.ua/KissFM", "Dance"),
            RadioStation(87, "Europa Plus", "Russia", "106.2", "http://ep256.hostingradio.ru:8052/europaplus256.mp3", "Pop"),
            RadioStation(88, "Vesti FM", "Russia", "97.6", "http://icecast.vgtrk.cdnvideo.ru/vestifm_mp3_192kbps", "News"),
            RadioStation(89, "Retro FM", "Russia", "88.3", "http://retroserver.streamr.ru:8043/retro256.mp3", "Oldies"),
            RadioStation(90, "Sfera", "Grecia", "102.2", "http://sfera.live24.gr/sfera4132", "Pop"),
            RadioStation(91, "Sport FM", "Grecia", "94.6", "http://netradio.live24.gr/sportfm7712", "Sport"),
            RadioStation(92, "Power FM", "Turchia", "103.2", "https://listen.powerapp.com.tr/powerfm/mpeg/icecast.audio", "Pop"),
            RadioStation(93, "Galgalatz", "Israele", "91.8", "https://glzwizzlv.bynetcdn.com/glglz_mp3", "Rock"),
            RadioStation(94, "Kan Bet", "Israele", "95.5", "https://25583.live.streamtheworld.com/KAN_BET.mp3", "Talk"),
            RadioStation(95, "Antena 1", "Portogallo", "95.7", "http://streaming-live-app.rtp.pt/liveradio/antena180a/playlist.m3u8", "Pop"),
            RadioStation(96, "RFM", "Portogallo", "93.2", "https://23603.live.streamtheworld.com/RFMAAC.aac", "Pop"),
            RadioStation(97, "5FM", "Sud Africa", "98.4", "https://playerservices.streamtheworld.com/api/livestream-redirect/5FM.mp3", "Pop"),
            RadioStation(98, "Metro FM", "Sud Africa", "94.7", "https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM.mp3", "Urban"),
            RadioStation(99, "Jacaranda FM", "Sud Africa", "94.2", "https://edge.iono.fm/xice/jacarandafm_live_medium.aac", "Pop"),
            RadioStation(100, "Radio Aswat", "Marocco", "97.9", "http://broadcast.ice.infomaniak.ch/aswat-high.mp3", "Pop"),
            RadioStation(101, "Radio Mars", "Marocco", "98.4", "https://radiomars.ice.infomaniak.ch/radiomars-128.mp3", "Sport"),
            RadioStation(102, "Nogoum FM", "Egitto", "100.6", "https://9090streaming.mobtada.com/9090FMEGYPT", "Pop"),
            RadioStation(103, "Kameme FM", "Kenya", "101.1", "https://kamemefm-atunwadigital.streamguys1.com/kamemefm", "World"),
            RadioStation(104, "Splash FM", "Nigeria", "105.5", "https://edge.mixlr.com/channel/cfeki", "World"),
            RadioStation(105, "Red FM", "India", "93.5", "http://air.pc.cdn.bitgravity.com/air/live/pbaudio056/playlist.m3u8", "Bollywood"),
            RadioStation(106, "Vividh Bharati", "India", "1188", "https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8", "Bollywood"),
            RadioStation(107, "FM 101 Islamabad", "Pakistan", "101.0", "https://whmsonic.radio.gov.pk:7008/stream", "World"),
            RadioStation(108, "Japan Hits", "Giappone", "—", "http://quincy.torontocast.com:2020/stream.mp3", "J-Pop"),
            RadioStation(109, "Jazz Sakura", "Giappone", "—", "http://kathy.torontocast.com:3330/stream/1/", "Jazz"),
            RadioStation(110, "Cool Fahrenheit", "Thailandia", "93.0", "https://coolism-web.cdn.byteark.com/live/playlist.m3u8", "Pop"),
            RadioStation(111, "Prambors FM", "Indonesia", "102.2", "http://103.24.105.90:9300/pjkt", "Pop"),
            RadioStation(112, "988 FM", "Malesia", "98.8", "https://28103.live.streamtheworld.com/988_FMAAC.aac", "Pop"),
            RadioStation(113, "Easy Rock Manila", "Filippine", "96.3", "https://azura.easyrock.com.ph/listen/easy_rock_manila/radio.mp3", "Rock"),
            RadioStation(114, "YES 933", "Singapore", "93.3", "https://playerservices.streamtheworld.com/api/livestream-redirect/YES933_PREM.aac", "Pop"),
            RadioStation(115, "Love 972", "Singapore", "97.2", "http://playerservices.streamtheworld.com/api/livestream-redirect/LOVE972FMAAC.aac", "Pop"),
            RadioStation(116, "VOV1", "Vietnam", "100.0", "https://str.vov.gov.vn/vovlive/vov1vov5Vietnamese.sdp_aac/playlist.m3u8", "News"),
            RadioStation(117, "The Rock", "Nuova Zelanda", "90.2", "https://digitalstreams.mediaworks.nz/rock_net_icy", "Rock"),
            RadioStation(118, "Magic FM NZ", "Nuova Zelanda", "97.4", "https://mediaworks.streamguys1.com/magic_net_icy", "Easy"),
            RadioStation(119, "Los 40 México", "Messico", "102.5", "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40_MEXICOAAC.aac", "Pop"),
            RadioStation(120, "Exa FM", "Messico", "104.9", "https://playerservices.streamtheworld.com/api/livestream-redirect/XHPSFMAAC.aac", "Pop"),
            RadioStation(121, "Aspen 102.3", "Argentina", "102.3", "https://playerservices.streamtheworld.com/api/livestream-redirect/ASPEN.mp3", "Pop"),
            RadioStation(122, "La 100", "Argentina", "99.9", "https://playerservices.streamtheworld.com/api/livestream-redirect/FM999_56.mp3", "Pop"),
            RadioStation(123, "Alpha FM", "Brasile", "101.7", "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ALPHAFM_ADP.aac", "Easy"),
            RadioStation(124, "Rádio Mix FM", "Brasile", "106.3", "https://playerservices.streamtheworld.com/api/livestream-redirect/MIXFM_SAOPAULOAAC.aac", "Pop"),
            RadioStation(125, "Pudahuel", "Cile", "90.5", "http://26593.live.streamtheworld.com:3690/PUDAHUEL_SC", "Pop"),
            RadioStation(126, "Caracol Radio", "Colombia", "100.9", "https://playerservices.streamtheworld.com/api/livestream-redirect/CARACOL_RADIOAAC.aac", "News"),
            RadioStation(127, "RPP Noticias", "Perù", "89.7", "https://mdstrm.com/audio/5fab3416b5f9ef165cfab6e9/icecast.audio", "News"),
            RadioStation(128, "Radio Panamericana", "Perù", "100.5", "https://mdstrm.com/audio/6598b62dded1380470f4e539/icecast.audio", "Pop"),
            RadioStation(129, "Azul FM", "Uruguay", "101.9", "https://azul-2.nty.uy/", "Pop"),
            RadioStation(130, "Del Sol FM", "Uruguay", "99.5", "http://radio.dl.uy:9950/radio", "Talk"),
            RadioStation(131, "Cubania Radio", "Cuba", "—", "https://streamingv2.shoutcast.com/cubania?type=.mp3", "Latin"),
            RadioStation(132, "Frisky", "Internet", "—", "http://stream2.friskyradio.com/frisky_mp3_hi", "Electronic"),
            RadioStation(133, "Dance Wave!", "Internet", "—", "https://dancewave.online/dance.mp3", "Dance"),
            RadioStation(134, "Rock Antenne Heavy Metal", "Internet", "—", "http://mp3channels.webradio.rockantenne.de/heavy-metal", "Metal"),
            RadioStation(135, "Deep House Lounge", "Internet", "—", "http://198.15.94.34:8006/stream", "Electronic"),
            RadioStation(136, "RTL 102.5 Best", "Italia", "—", "https://streamingv2.shoutcast.com/rtl-1025-best", "Pop", false),
            RadioStation(137, "Skyrock", "Francia", "96.0", "http://icecast.skyrock.net/s/natio_mp3_128k", "Hip-Hop", false),
            RadioStation(138, "RFI Monde", "Francia", "89.0", "http://live02.rfi.fr/rfimonde-64.mp3", "News", false),
            RadioStation(139, "NDR 2", "Germania", "87.6", "https://icecast.ndr.de/ndr/ndr2/niedersachsen/mp3/128/stream.mp3", "Pop", false),
            RadioStation(140, "Heart London", "UK", "106.2", "https://media-ssl.musicradio.com/HeartLondon", "Pop", false),
            RadioStation(141, "Smooth Radio", "UK", "100.0", "https://media-ssl.musicradio.com/SmoothUK", "Easy", false),
            RadioStation(142, "talkSPORT", "UK", "1089", "https://radio.talksport.com/stream", "Sport", false),
            RadioStation(143, "NPO Radio 1", "Olanda", "97.5", "https://icecast.omroep.nl/radio1-bb-mp3", "News", false),
            RadioStation(144, "NPO 3FM", "Olanda", "96.5", "https://icecast.omroep.nl/3fm-bb-mp3", "Pop"),
            RadioStation(145, "Sky Radio NL", "Olanda", "101.2", "https://22343.live.streamtheworld.com/SKYRADIO.mp3", "Pop"),
            RadioStation(146, "Antyradio", "Polonia", "94.0", "https://an.cdn.eurozet.pl/ant-waw.mp3", "Rock"),
            RadioStation(147, "talkRADIO", "UK", "—", "https://radio.talkradio.co.uk/stream", "Talk"),
            RadioStation(148, "Times Radio", "UK", "—", "https://timesradio.wireless.radio/stream", "News"),
            RadioStation(149, "Heart 80s", "UK", "—", "https://media-ssl.musicradio.com/Heart80s", "Oldies"),
            RadioStation(150, "KEXP 90.3", "USA", "90.3", "https://kexp.streamguys1.com/kexp160.aac", "Alternative"),
            RadioStation(151, "WNYC FM", "USA", "93.9", "https://fm939.wnyc.org/wnycfm", "News"),
            RadioStation(152, "WBEZ Chicago", "USA", "91.5", "https://stream.wbez.org/wbez128.mp3", "News"),
            RadioStation(153, "KQED FM", "USA", "88.5", "https://streams.kqed.org/kqedradio", "News"),
            RadioStation(154, "WFMU", "USA", "91.1", "https://stream0.wfmu.org/freeform-128k", "Eclectic"),
            RadioStation(155, "NPR News", "USA", "—", "https://npr-ice.streamguys1.com/live.mp3", "News"),
            RadioStation(156, "WBLS", "USA", "107.5", "https://stream.revma.ihrhls.com/zc3073", "Urban"),
            RadioStation(157, "Hot 97", "USA", "97.1", "https://playerservices.streamtheworld.com/api/livestream-redirect/WQHTFMAAC.aac", "Hip-Hop"),
            RadioStation(158, "Bloomberg Radio", "USA", "1130", "https://playerservices.streamtheworld.com/api/livestream-redirect/WBBRAMAAC.aac", "News"),
            RadioStation(159, "W Radio", "Messico", "96.9", "https://playerservices.streamtheworld.com/api/livestream-redirect/WRADIO_MEXICOAAC.aac", "News"),
            RadioStation(160, "ABC Classic FM", "Australia", "92.9", "https://live-radio01.mediahubaustralia.com/2FMW/mp3/", "Classical"),
            RadioStation(161, "RTHK Radio 1", "Hong Kong", "92.6", "http://stm.rthk.hk/radio1", "Talk"),
            RadioStation(162, "RTHK Radio 2", "Hong Kong", "94.8", "http://stm.rthk.hk/radio2", "Pop"),
            RadioStation(163, "RTHK Radio 3", "Hong Kong", "97.9", "http://stm.rthk.hk/radio3", "Talk"),
            RadioStation(164, "RTÉ Radio 1", "Irlanda", "89.0", "http://icecast.rte.ie/radio1", "News", false),
            RadioStation(165, "Today FM", "Irlanda", "100.0", "https://stream.audioxi.com/TD", "Pop", false),
            RadioStation(166, "Rádio Renascença", "Portogallo", "103.4", "http://22653.live.streamtheworld.com/RADIO_RENASCENCA_SC", "News", false),
            RadioStation(167, "Newstalk", "Irlanda", "106.0", "https://edge.audioxi.com/NT", "News"),
            RadioStation(168, "8radio", "Irlanda", "—", "https://edge4.audioxi.com/8RADIO", "Alternative"),
            RadioStation(169, "Rádio Observador", "Portogallo", "98.7", "http://195.23.85.126:8455/stream", "News"),
            RadioStation(170, "X977", "Islanda", "97.7", "http://icecast.365net.is:8000/orbXid.aac", "Rock"),
            RadioStation(171, "RCV Rádio Cabo Verde", "Capo Verde", "—", "https://a3.asurahosting.com:6980/radio.mp3", "World"),
            RadioStation(172, "Nanoq FM", "Groenlandia", "—", "http://getnanoq.retro-radio.dk/Nanoq-TX-1", "Pop"),
            RadioStation(173, "Dr. Dick's Dub Shack", "Bermuda", "—", "http://streamer.radio.co/s0635c8b0d/listen", "Reggae"),
            RadioStation(174, "Dakar Musique", "Senegal", "—", "http://listen.senemultimedia.net:8090/stream", "World"),
            RadioStation(175, "Alpha Boys School Radio", "Giamaica", "—", "http://alphaboys-live.streamguys1.com/alphaboys.mp3", "Jazz"),
            RadioStation(176, "Mello FM", "Giamaica", "88.0", "http://peridot.streamguys.com:5660/live", "Reggae"),
            RadioStation(177, "Global FM", "Bahamas", "99.5", "http://ice64.securenetsystems.net/GLOBALBS", "Pop"),
            RadioStation(178, "Guardian Radio", "Bahamas", "96.9", "https://radiostreams.streamcomedia.com:8000/969guardianradio", "News"),
            RadioStation(179, "BOOM 94FM", "Trinidad", "94.1", "https://s8.yesstreaming.net:17103/stream", "Pop"),
            RadioStation(180, "Radio Tambrin", "Trinidad", "92.7", "http://ice42.securenetsystems.net/TAMBRIN", "News"),
            RadioStation(181, "680 News Toronto", "Canada", "680", "https://rogers-hls.leanstream.co/rogers/tor680.stream/playlist.m3u8", "News"),
            RadioStation(182, "CCTV-13 News", "Cina", "—", "https://piccpndali.v.myalicdn.com/audio/cctv13_2.m3u8", "News"),
            RadioStation(183, "FM Kahoku", "Giappone", "78.7", "http://radio.kahoku.net:8000/;", "Talk"),
            RadioStation(184, "J1 Gold", "Giappone", "—", "http://jenny.torontocast.com:8062/", "J-Pop"),
            RadioStation(185, "Taipei Radio", "Taiwan", "93.1", "https://stream.ginnet.cloud/live0130lo-yfyo/_definst_/fm/playlist.m3u8", "News"),
            RadioStation(186, "Radio Taiwan International", "Taiwan", "—", "https://streamak0138.akamaized.net/live0138lh-mbm9/_definst_/rti3/chunklist.m3u8", "News"),
            RadioStation(187, "Barangay LS 97.1", "Filippine", "97.1", "http://28093.live.streamtheworld.com:3690/MORFM_S01AAC_SC", "Talk"),
            RadioStation(188, "Love Radio Dagupan", "Filippine", "98.3", "https://loveradiodagupan.radioca.st/", "Pop"),
            RadioStation(189, "RFI Tiếng Việt", "Vietnam", "—", "https://rfienvietnamien64k.ice.infomaniak.ch/rfienvietnamien-64.mp3", "News"),
            RadioStation(190, "VOV Giao Thong", "Vietnam", "91.0", "https://play.vovgiaothong.vn/live/gthn/playlist.m3u8", "News"),
            RadioStation(191, "Real FM", "Grecia", "97.8", "http://netradio.live24.gr/realfm", "News"),
            RadioStation(192, "Arabesk FM", "Turchia", "—", "http://yayin.arabeskfm.biz:8042/", "Pop"),
            RadioStation(193, "Al Arabiya FM", "Arabia Saudita", "99.0", "https://fm.alarabiya.net/fm/myStream/playlist.m3u8", "News"),
            RadioStation(194, "Mp3Quran Tarateel", "Arabia Saudita", "—", "https://qurango.net/radio/tarateel", "World"),
            RadioStation(195, "La Ranchera Monterrey", "Messico", "1050", "http://streamingcwsradio20.com:9410/stream", "Latin"),
            RadioStation(196, "La Kalle", "Colombia", "96.9", "http://26683.live.streamtheworld.com/LA_KALLE_SC", "Urban"),
            RadioStation(197, "Radiónica RTVC", "Colombia", "99.1", "http://shoutcast.rtvc.gov.co:8010/;", "Alternative"),
            RadioStation(198, "Unión Radio", "Venezuela", "90.3", "http://ur58.lorini.net:2080/stream", "News"),
            RadioStation(199, "Bío-Bío Chile", "Cile", "99.7", "https://unlimited3-cl.dps.live/biobiosantiago/aac/icecast.audio", "News"),
            RadioStation(200, "Radio Rivadavia", "Argentina", "630", "https://playerservices.streamtheworld.com/api/livestream-redirect/RIVADAVIA.mp3", "News"),
            RadioStation(201, "Rock & Pop", "Argentina", "95.9", "https://playerservices.streamtheworld.com/api/livestream-redirect/ROCKANDPOPAAC.aac", "Rock"),
            RadioStation(202, "Rádio Saudade FM", "Brasile", "99.7", "https://playerservices.streamtheworld.com/api/livestream-redirect/SAUDADE_FMAAC.aac", "Oldies"),
            RadioStation(203, "ABC Radio National", "Australia", "—", "http://abc.streamguys1.com/live/rnnsw/icecast.audio", "News"),
            RadioStation(204, "ABC Country", "Australia", "—", "http://live-radio01.mediahubaustralia.com/CTRW/mp3/", "Country"),
            RadioStation(205, "RNZ National", "Nuova Zelanda", "101.4", "http://radionz-ice.streamguys.com/national.mp3", "News"),
            RadioStation(206, "Rádió 1 Budapest", "Ungheria", "96.4", "http://icast.connectmedia.hu/5201/live.mp3", "Pop"),
            RadioStation(207, "Kossuth Rádió", "Ungheria", "107.8", "http://mr-stream.mediaconnect.hu/4734/mr1.aac", "News"),
            RadioStation(208, "94.7 Joburg", "Sud Africa", "94.7", "http://27953.live.streamtheworld.com/FM947AAC_SC", "Pop"),
            RadioStation(209, "702 Johannesburg", "Sud Africa", "92.7", "http://23543.live.streamtheworld.com:3690/FM702_SC", "Talk"),
            RadioStation(210, "FIP Jazz", "Francia", "—", "https://icecast.radiofrance.fr/fipjazz-midfi.mp3", "Jazz", false),
            RadioStation(211, "Smooth Jazz Florida", "USA", "—", "https://ais-sa2.cdnstream1.com/2319_128.mp3", "Jazz", false),
            RadioStation(212, "WDR 4", "Germania", "100.5", "https://wdr-wdr4-live.icecastssl.wdr.de/wdr/wdr4/live/mp3/128/stream.mp3", "Oldies", false),
            RadioStation(213, "181.fm Oldies", "USA", "—", "http://listen.181fm.com/181-greatoldies_128k.mp3", "Oldies", false),
            RadioStation(214, "FIP Electro", "Francia", "—", "https://icecast.radiofrance.fr/fipelectro-midfi.mp3", "Electronic", false),
            RadioStation(215, "FIP World", "Francia", "—", "https://icecast.radiofrance.fr/fipworld-midfi.mp3", "World", false),
            RadioStation(216, "FIP Reggae", "Francia", "—", "https://icecast.radiofrance.fr/fipreggae-midfi.mp3", "Reggae", false),
            RadioStation(217, "181.fm Old School HipHop", "USA", "—", "http://listen.181fm.com/181-oldschool_128k.mp3", "Hip-Hop", false),
            RadioStation(218, "Los 40 Urban", "Spagna", "—", "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40_URBAN.mp3", "Urban", false),
            RadioStation(219, "90s90s Heavy Metal", "Germania", "—", "http://streams.90s90s.de/metal/mp3-192/streams.90s90s.de/", "Metal", false),
            RadioStation(220, "J-Pop Sakura", "Giappone", "—", "https://quincy.torontocast.com:2070/stream.mp3", "J-Pop", false),
            RadioStation(221, "977 Country", "USA", "—", "https://playerservices.streamtheworld.com/api/livestream-redirect/977_COUNTRY.mp3", "Country", false),
            RadioStation(222, "1.fm Country", "Internet", "—", "https://strm112.1.fm/country_mobile_mp3", "Country", false),
            RadioStation(223, "Bollywood Radio", "India", "—", "https://drive.uber.radio/uber/bollywoodnow/icecast.audio", "Bollywood", false),
            RadioStation(224, "Hits Of Bollywood", "India", "—", "http://stream.zeno.fm/8ty8szwpwfeuv", "Bollywood", false),
            RadioStation(225, "1.fm Reggaeton", "Internet", "—", "https://strm112.1.fm/reggaeton_mobile_mp3", "Latin", false),
            RadioStation(226, "1.fm Samba", "Internet", "—", "https://strm112.1.fm/samba_mobile_mp3", "Latin", false),
            RadioStation(227, "FIP Rock", "Francia", "—", "https://icecast.radiofrance.fr/fiprock-midfi.mp3", "Rock", false),
            RadioStation(228, "FIP Groove", "Francia", "—", "https://icecast.radiofrance.fr/fipgroove-midfi.mp3", "Eclectic", false),
            RadioStation(229, "FIP Pop", "Francia", "—", "https://icecast.radiofrance.fr/fippop-midfi.mp3", "Pop", false),
            RadioStation(230, "Mouv'", "Francia", "—", "https://icecast.radiofrance.fr/mouv-midfi.mp3", "Hip-Hop", false),
            RadioStation(231, "Oldie Antenne", "Germania", "—", "https://s1-webradio.oldie-antenne.de/oldie-antenne", "Oldies"),
            RadioStation(232, "181.fm The Beat", "USA", "—", "http://listen.181fm.com/181-beat_128k.mp3", "Hip-Hop"),
            RadioStation(233, "90s90s HipHop", "Germania", "—", "http://streams.90s90s.de/hiphop/mp3-192/streams.90s90s.de/", "Hip-Hop"),
            RadioStation(234, "America's Country", "USA", "—", "https://ais-sa2.cdnstream1.com/1976_128.mp3", "Country"),
            RadioStation(235, "181.fm Kickin' Country", "USA", "—", "http://listen.181fm.com/181-kickincountry_128k.mp3", "Country"),
            RadioStation(236, "181.fm Rock 40", "USA", "—", "http://listen.181fm.com/181-rock40_128k.mp3", "Rock"),
            RadioStation(237, "181.fm 80s Hairband", "USA", "—", "http://listen.181fm.com/181-hairband_128k.mp3", "Rock"),
            RadioStation(238, "Jazz Radio Blues", "Francia", "—", "http://jazzblues.ice.infomaniak.ch/jazzblues-high.mp3", "Jazz"),
            RadioStation(239, "Bayern 1 Oberbayern", "Germania", "93.7", "https://dispatcher.rndfnk.com/br/br1/obb/mp3/mid", "Oldies"),
            RadioStation(240, "Radio Paradise World", "USA", "—", "https://stream.radioparadise.com/world-etc-128", "World"),
            RadioStation(241, "FIP Nouveautés", "Francia", "—", "https://icecast.radiofrance.fr/fipnouveautes-midfi.mp3", "Pop"),
            RadioStation(242, "ItaliaRadio MRG", "Italia", "—", "http://listen.mrg.fm:8120/stream", "Italian", false),
            RadioStation(243, "Big R Radio 80s Metal", "USA", "—", "http://bigrradio.cdnstream1.com/5186_128", "Metal", false),
            RadioStation(244, "France Musique", "Francia", "91.7", "http://direct.francemusique.fr/live/francemusique-midfi.mp3", "Classical", false),
            RadioStation(245, "EuroDance 90", "Francia", "—", "https://stream-eurodance90.fr/radio/8000/128.mp3", "Electronic", false),
            RadioStation(246, "Stereo Anime", "Giappone", "—", "https://radio.stereoanime.com/listen/stereoanime/128", "J-Pop", false),
            RadioStation(247, "Reggae Chill Cafe", "Canada", "—", "https://maggie.torontocast.com:2020/stream/reggaechillcafe", "Reggae", false),
            RadioStation(248, "RMC Sport", "Francia", "—", "https://audio.bfmtv.com/rmcradio_128.mp3", "Sport", false),
            RadioStation(249, "Rumba 98.1", "Venezuela", "98.1", "https://cast20.plugstreaming.com:2020/stream/r981/", "Latin", false),
            RadioStation(250, "Radio Birikina", "Italia", "—", "http://wma01.fluidstream.net/birikina", "Italian"),
            RadioStation(251, "Your Classical Relax", "USA", "—", "http://relax.stream.publicradio.org/relax.mp3", "Classical"),
            RadioStation(252, "Radio Ibiza", "Italia", "—", "http://wma08.fluidstream.net:5010/", "Electronic"),
            RadioStation(253, "Anime Para Ti", "Giappone", "—", "https://stream.zeno.fm/qpn8mkt8c4duv", "J-Pop"),
            RadioStation(254, "BBC Radio 5 Live", "UK", "909", "http://as-hls-ww-live.akamaized.net/pool_89021708/live/ww/bbc_radio_five_live/bbc_radio_five_live.isml/bbc_radio_five_live-audio%3d128000.norewind.m3u8", "Sport"),
            RadioStation(255, "RdMix Classic Rock", "Canada", "—", "https://cast1.torontocast.com:4610/stream", "Rock"),
            RadioStation(256, "Latvijas Radio 2", "Lettonia", "91.5", "http://lr2mp1.latvijasradio.lv:8002/", "Pop"),
            RadioStation(257, "Relax FM Lietuva", "Lituania", "—", "https://stream1.relaxfm.lt/relaxfm128.mp3", "Easy"),
            RadioStation(258, "OK Radio", "Serbia", "—", "https://sslstream.okradio.net/", "Pop"),
            RadioStation(259, "Ocean 89", "Bermuda", "89.1", "https://us2.internet-radio.com/proxy/ocean89?mp=/stream", "Pop"),
            RadioStation(260, "ZFB Power 95", "Bermuda", "94.9", "http://us3.internet-radio.com:8026/live", "Pop"),
            RadioStation(261, "Cuban Flow Radio", "Cuba", "—", "http://nap.casthost.net:9194/stream.mp3", "Latin"),
            RadioStation(262, "Romance 106", "Cuba", "106.1", "http://s13.myradiostream.com:41400/;", "Latin"),
            RadioStation(263, "Radio Pakistan MW", "Pakistan", "1008", "https://whmsonic.radio.gov.pk:8042/stream", "World"),
            RadioStation(264, "106 Family News", "Thailandia", "106.0", "https://radio11.plathong.net/7138/;stream.mp3", "News"),
            RadioStation(265, "Bond 92.9 FM", "Nigeria", "92.9", "https://go.webgateready.com/bondfm", "World"),
            RadioStation(266, "Melody FM Malaysia", "Malesia", "103.0", "https://n09.rcs.revma.com/2u1n6dtbv4uvv/9_11l86ncot7z1w02/playlist.m3u8", "Pop"),
            RadioStation(267, "CNR China News", "Cina", "—", "https://lhttp.qtfm.cn/live/15318317/64k.mp3", "News"),
            RadioStation(268, "France Culture", "Francia", "93.5", "http://icecast.radiofrance.fr/franceculture-hifi.aac", "Talk", false),
            RadioStation(269, "Deutschlandfunk", "Germania", "101.8", "https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3", "News", false),
            RadioStation(270, "SRo1 Rádio Slovensko", "Slovacchia", "93.9", "http://live.slovakradio.sk:8000/Slovensko_256.mp3", "News", false),
            RadioStation(271, "Sveriges Radio P1", "Svezia", "92.4", "https://live1.sr.se/p1-mp3-192", "Talk", false),
            RadioStation(272, "DR P4 København", "Danimarca", "94.9", "http://live-icy.gslb01.dr.dk/A/A08H.mp3", "Pop", false),
            RadioStation(273, "NRK P1", "Norvegia", "89.3", "https://cdn0-47115-liveicecast0.dna.contentdelivery.net/p1_mp3_h", "Pop", false),
            RadioStation(274, "MNM", "Belgio", "101.4", "https://icecast.vrtcdn.be/mnm-high.mp3", "Pop", false),
            RadioStation(275, "Radio Swiss Classic", "Svizzera", "—", "http://stream.srg-ssr.ch/m/rsc_fr/mp3_128", "Classical", false),
            RadioStation(276, "RTL2 France", "Francia", "103.5", "http://streamer-02.rtl.fr/rtl2-1-44-128", "Rock", false),
            RadioStation(277, "Rock Antenne", "Germania", "—", "http://mp3channels.webradio.rockantenne.de/rockantenne", "Rock", false),
            RadioStation(278, "MANGORADIO", "Germania", "—", "https://mangoradio.stream.laut.fm/mangoradio", "Pop"),
            RadioStation(279, "REYFM Original", "Germania", "—", "https://listen.reyfm.de/original_192kbps.mp3", "Pop"),
            RadioStation(280, "RFI Afrique", "Francia", "—", "http://live02.rfi.fr/rfiafrique-64.mp3", "World"),
            RadioStation(281, "Mosaique FM", "Tunisia", "94.9", "http://radio.mosaiquefm.net:8000/mosalive", "World"),
            RadioStation(282, "Antinea Radio", "Algeria", "—", "https://listen.radioking.com/radio/6640/stream/347", "World"),
            RadioStation(283, "Deep House Radio", "USA", "—", "http://62.210.105.16:7000/stream", "Electronic"),
            RadioStation(284, "Bassdrive", "USA", "—", "http://stream.bassdrive.uk:8200", "Electronic"),
            RadioStation(285, "Christmas Vinyl HD", "USA", "—", "https://icecast.walmradio.com:8443/christmas", "Easy"),
            RadioStation(286, "80s80s Radio", "Germania", "—", "http://streams.80s80s.de/web/mp3-192/streams.80s80s.de/", "Oldies"),
            RadioStation(287, "977 80s", "USA", "—", "https://playerservices.streamtheworld.com/api/livestream-redirect/977_80.mp3", "Oldies"),
            RadioStation(288, "977 The Mix", "USA", "—", "https://playerservices.streamtheworld.com/api/livestream-redirect/977_MIX.mp3", "Pop"),
            RadioStation(289, "Radio Kiss Kiss Napoli", "Italia", "—", "http://wma08.fluidstream.net:3612/", "Pop"),
            RadioStation(290, "RFE/RL Radio Farda", "Rep. Ceca", "—", "http://rfe21.akacast.akamaistream.net/7/751/437779/v1/ibb.akacast.akamaistream.net/rfe/radiofarda", "News"),
            RadioStation(291, "NPO Radio 4", "Olanda", "94.3", "https://icecast.omroep.nl/radio4-bb-mp3", "Classical", false),
            RadioStation(292, "ABC Triple J Unearthed", "Australia", "—", "https://live-radio01.mediahubaustralia.com/UNEW/mp3/", "Alternative", false),
            RadioStation(293, "Radio Mitre", "Argentina", "790", "https://playerservices.streamtheworld.com/api/livestream-redirect/AM790_56.mp3", "News", false),
            RadioStation(294, "METRO 95.1", "Argentina", "95.1", "https://playerservices.streamtheworld.com/api/livestream-redirect/METRO.mp3", "Pop", false),
            RadioStation(295, "Kronehit", "Austria", "105.8", "https://secureonair.krone.at/kronehit.mp3", "Pop", false),
            RadioStation(296, "Fun Radio France", "Francia", "101.9", "http://streaming.radio.funradio.fr/fun-1-44-128", "Pop", false),
            RadioStation(297, "CADENA 100", "Spagna", "100.0", "https://cadena100-cope-rrcast.flumotion.com/cope/cadena100-low.mp3", "Pop", false),
            RadioStation(311, "CBS Music FM", "Corea del Sud", "—", "https://m-aac.cbs.co.kr/mweb_cbs939/_definst_/cbs939.stream/playlist.m3u8", "Classical", false),
            RadioStation(312, "103 FM", "Costa Rica", "103.1", "https://playerservices.streamtheworld.com/api/livestream-redirect/CRC_103_1AAC.aac", "Pop", false),
            RadioStation(313, "Radio La Otra", "Ecuador", "91.3", "https://laotrafm.makrodigital.com/stream/laotrafmquito", "Talk", false),
            RadioStation(314, "Stereo 100", "Guatemala", "100.0", "https://sh1.radioonlinehd.com:8056/stream?type=.mp3", "Latin", false),
            RadioStation(315, "Fabulosa Estéreo", "Panama", "100.5", "https://www.streaming507.net:8130/stream", "Latin", false),
            RadioStation(316, "Salsa Radio", "Rep. Dominicana", "—", "http://radio.domiplay.net:2002/", "Salsa", false),
            RadioStation(317, "Al Bal Radio", "Libano", "—", "https://albal-lbnet2.radioca.st/stream", "Arabic", false),
            RadioStation(318, "Sky News Arabia Radio", "Emirati Arabi Uniti", "—", "https://stream.skynewsarabia.com/hls/sna.m3u8", "News", false),
            RadioStation(298, "ROCK FM Russia", "Russia", "—", "http://nashe1.hostingradio.ru/rock-128.mp3", "Rock"),
            RadioStation(299, "Dorozhnoe Radio", "Russia", "—", "http://dorognoe.hostingradio.ru:8000/radio", "Pop"),
            RadioStation(300, "Radio Vanya", "Russia", "—", "https://icecast-radiovanya.cdnvideo.ru/radiovanya", "Pop"),
            RadioStation(301, "DFM Russian Dance", "Russia", "—", "https://dfm-dfmrusdance.hostingradio.ru/dfmrusdance96.aacp", "Dance"),
            RadioStation(302, "Radio Russkie Pesni", "Russia", "—", "http://listen.rusongs.ru/ru-mp3-128", "Pop"),
            RadioStation(303, "WALM HD", "USA", "—", "https://icecast.walmradio.com:8443/walm", "Eclectic"),
            RadioStation(304, "WALM Old Time Radio", "USA", "—", "https://icecast.walmradio.com:8443/otr", "Eclectic"),
            RadioStation(305, "Ambient Sleeping Pill", "USA", "—", "http://radio.stereoscenic.com/asp-h", "Electronic"),
            RadioStation(306, "Classic Hits 70-80", "USA", "—", "https://radiopanther.radiolebowski.com/play", "Oldies"),
            RadioStation(307, "Dance Wave Retro!", "Ungheria", "—", "https://retro.dancewave.online/retrodance.mp3", "Dance"),
            RadioStation(308, "Radio Disney Mexico", "Messico", "92.1", "https://playerservices.streamtheworld.com/api/livestream-redirect/XHFOFMAAC.aac", "Pop"),
            RadioStation(309, "Radio FG", "Francia", "—", "https://radiofg.impek.com/fg.mp3", "Dance"),
            RadioStation(310, "Antena 3 Portugal", "Portogallo", "100.3", "http://streaming-live-app.rtp.pt/liveradio/antena380a/playlist.m3u8", "Pop"),
            RadioStation(319, "95.5 Jazz", "Costa Rica", "—", "https://streaming.radio.co/s36bd2a451/listen", "Jazz"),
            RadioStation(320, "Radio Canela", "Ecuador", "—", "https://canelaradio.makrodigital.com:9280/stream", "Latin"),
            RadioStation(321, "L.A. Mega", "Panama", "98.1", "https://www.streaming507.net:8152/stream", "Latin"),
            RadioStation(322, "Bachata Radio", "Rep. Dominicana", "—", "http://radio.domiplay.net:8002/", "Bachata"),
            RadioStation(323, "Adeem", "Libano", "—", "https://usa19.fastcast4u.com/adeem", "Arabic"),
            RadioStation(324, "Free FM 80 Tokyo", "Giappone", "—", "https://freefm80.radioca.st/", "80s"),
            RadioStation(325, "Exclusively Pink Floyd", "Emirati Arabi Uniti", "—", "https://streaming.exclusive.radio/er/pinkfloyd/icecast.audio", "Rock"),
            RadioStation(326, "RMC", "Francia", "—", "https://audio.bfmtv.com/rmcradio_128.mp3", "Talk", false),
            RadioStation(327, "BFM Radio", "Francia", "—", "https://audio.bfmtv.com/bfmradio_128.mp3", "News", false),
            RadioStation(328, "Sud Radio", "Francia", "—", "https://ice.creacast.com/sudradio", "Talk", false),
            RadioStation(329, "LOS 40 Principales", "Spagna", "—", "https://playerservices.streamtheworld.com/api/livestream-redirect/Los40.mp3", "Pop", false),
            RadioStation(330, "Heart 70s", "UK", "—", "https://media-ssl.musicradio.com/Heart70sMP3", "Oldies", false),
            RadioStation(331, "Gold", "UK", "—", "https://media-ssl.musicradio.com/GoldMP3", "Oldies", false),
            RadioStation(332, "SomaFM Groove Salad", "USA", "—", "https://ice5.somafm.com/groovesalad-128-mp3", "Electronic", false),
            RadioStation(333, "SomaFM Secret Agent", "USA", "—", "https://ice6.somafm.com/secretagent-128-mp3", "Easy", false),
            RadioStation(334, "Kiss FM Romania", "Romania", "—", "https://live.kissfm.ro/kissfm.aacp", "Dance", false),
            RadioStation(335, "SomaFM Space Station", "USA", "—", "https://ice5.somafm.com/spacestation-128-aac", "Electronic", true),
            RadioStation(336, "SomaFM Underground 80s", "USA", "—", "https://ice6.somafm.com/u80s-128-mp3", "80s", true),
            RadioStation(337, "SomaFM Indie Pop Rocks", "USA", "—", "https://ice6.somafm.com/indiepop-128-aac", "Alternative", true),
            RadioStation(338, "SomaFM PopTron", "USA", "—", "https://ice2.somafm.com/poptron-128-mp3", "Electronic", true),
            RadioStation(339, "REYFM Original", "Germania", "—", "https://listen.reyfm.de/original_192kbps.mp3", "Dance", true),
            RadioStation(340, "EuroDance 90", "Francia", "—", "https://stream-eurodance90.fr/radio/8000/128.mp3", "Dance", true),
            RadioStation(341, "Radio Mirchi", "India", "—", "https://eu8.fastcast4u.com/proxy/clyedupq/stream", "Bollywood", true),
            RadioStation(342, "Funky Radio", "USA", "—", "https://funkyradio.streamingmedia.it/play.mp3", "Urban", true),
            RadioStation(343, "ABC Lounge Radio", "Francia", "—", "https://eu1.fastcast4u.com/proxy/kpmxz?mp=/1", "Jazz", true)
        )

        val channelDisplayNames = listOf(
            "public" to "Pubblico",
            "ch1" to "Canale 1",
            "ch2" to "Canale 2",
            "ch3" to "Canale 3",
            "ch4" to "Canale 4",
            "ch5" to "Canale 5",
            "ch6" to "Canale 6",
            "ch7" to "Canale 7",
            "ch8" to "Canale 8"
        )
    }

    fun setStatusListener(listener: (RadioStatus) -> Unit) {
        onStatusChanged = listener
    }

    fun playStation(station: RadioStation) {
        val sameStation = currentStationId == station.id
        if (sameStation && isPlayingState) return

        stop()

        val mp = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            setOnPreparedListener {
                start()
                isPlayingState = true
                currentStationId = station.id
                currentStationName = station.name
                currentStationCountry = station.country
                emitStatus(isBuffering = false)
            }
            setOnErrorListener { _, _, _ ->
                emitStatus(error = "Errore streaming")
                true
            }
            setOnInfoListener { _, what, _ ->
                if (what == MediaPlayer.MEDIA_INFO_BUFFERING_START) {
                    emitStatus(isBuffering = true)
                } else if (what == MediaPlayer.MEDIA_INFO_BUFFERING_END) {
                    emitStatus(isBuffering = false)
                }
                true
            }
        }

        mediaPlayer = mp
        emitStatus(isBuffering = true)

        try {
            mp.setDataSource(station.streamUrl)
            mp.prepareAsync()
        } catch (e: Exception) {
            emitStatus(error = "URL non valido: ${e.message}")
            mp.release()
            mediaPlayer = null
        }
    }

    fun stop() {
        mediaPlayer?.let { mp ->
            try {
                if (mp.isPlaying) mp.stop()
            } catch (_: Exception) {}
            mp.reset()
            mp.release()
        }
        mediaPlayer = null
        currentStationId = -1
        currentStationName = ""
        currentStationCountry = ""
        isPlayingState = false
        emitStatus()
    }

    fun isPlaying(): Boolean = isPlayingState

    fun getCurrentStationId(): Int = currentStationId

    fun getNextStation(): RadioStation? {
        val idx = stations.indexOfFirst { it.id == currentStationId }
        if (idx < 0) return null
        return stations[(idx + 1) % stations.size]
    }

    fun getPreviousStation(): RadioStation? {
        val idx = stations.indexOfFirst { it.id == currentStationId }
        if (idx < 0) return null
        return stations[(idx - 1 + stations.size) % stations.size]
    }

    private var lastBuffering = false
    private var lastError: String? = null

    private fun emitStatus(isBuffering: Boolean? = null, error: String? = null) {
        if (isBuffering != null) lastBuffering = isBuffering
        if (error != null) lastError = error
        onStatusChanged?.invoke(
            RadioStatus(
                isPlaying = isPlayingState,
                stationName = currentStationName,
                stationCountry = currentStationCountry,
                isBuffering = lastBuffering,
                error = lastError
            )
        )
        if (error == null) lastError = null
    }

    override fun close() {
        stop()
    }
}
