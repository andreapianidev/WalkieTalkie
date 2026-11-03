//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - RadioScope.swift
//  Talky (iOS e Mac)
//
//  Le bande di quello che suona la radio, per lo schermo al posto del tasto.
//  AVPlayer non da' i campioni degli stream dal vivo (il tap di MediaToolbox
//  non riceve niente: misurato il 03/11/2026), quindi StreamTap legge lo
//  stesso stream e lo decodifica. Il grafico si allinea a quello che il player
//  sta suonando: il secondo t della lettura parallela va in onda quando il
//  player arriva a `origin + t`.
//  La lettura parallela gira solo mentre la radio suona e l'app e' in primo
//  piano: in background e in pausa non consuma dati.

import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class RadioScope: NSObject, @unchecked Sendable {
    static let shared = RadioScope()

    let bands = SoundBands()
    private var url: URL?
    private weak var player: AVPlayer?
    private var tap: StreamTap?
    private var origin: Double = 0
    private var statusObservation: NSKeyValueObservation?
    private var isForeground = true

    override init() {
        super.init()
        let center = NotificationCenter.default
        #if canImport(UIKit)
        let away = UIApplication.didEnterBackgroundNotification, back = UIApplication.willEnterForegroundNotification
        #else
        let away = NSApplication.didHideNotification, back = NSApplication.didUnhideNotification
        #endif
        center.addObserver(forName: away, object: nil, queue: .main) { [weak self] _ in
            self?.isForeground = false
            self?.stopTap()
        }
        center.addObserver(forName: back, object: nil, queue: .main) { [weak self] _ in
            self?.isForeground = true
            self?.startTapIfPlaying()
        }
    }

    func attach(url: URL, player: AVPlayer) {
        stopTap()
        self.url = url
        self.player = player
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                if player.timeControlStatus == .paused { self?.stopTap() } else { self?.startTapIfPlaying() }
            }
        }
        startTapIfPlaying(starting: true)
    }

    func detach() {
        statusObservation = nil
        stopTap()
        url = nil
        player = nil
    }

    /// Le bande di quello che si sente adesso.
    func display() -> SoundBands.Display {
        let position = player?.currentTime().seconds ?? 0
        return bands.display(at: (position.isFinite ? position : 0) - origin)
    }

    private func startTapIfPlaying(starting: Bool = false) {
        guard tap == nil, isForeground, let url, let player,
              starting || player.timeControlStatus != .paused else { return }
        bands.reset()
        let position = player.currentTime().seconds
        let now = position.isFinite ? position : 0
        // Quello che arriva adesso dal server il player lo suonera' dopo aver
        // finito il suo buffer. Sugli HLS AVPlayer parte gia' tre segmenti
        // indietro, ed e' da li' che parte anche StreamTap.
        let tap = StreamTap(url: url, bands: bands)
        origin = now + (tap.isHLS ? 0 : bufferedAhead(of: player, at: now))
        self.tap = tap
        tap.start()
    }

    private func stopTap() {
        tap?.stop()
        tap = nil
    }

    private func bufferedAhead(of player: AVPlayer, at now: Double) -> Double {
        guard let range = player.currentItem?.loadedTimeRanges.last?.timeRangeValue else { return 0 }
        let end = range.end.seconds
        return end.isFinite ? max(0, end - now) : 0
    }
}
