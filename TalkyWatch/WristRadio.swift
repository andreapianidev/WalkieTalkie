//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - WristRadio.swift
//  TalkyWatch
//
//  La radio che suona sul Watch, senza l'iPhone. watchOS lascia suonare uno
//  stream solo in audio "long form", cioe' su cuffie o altoparlanti
//  Bluetooth: se non ce ne sono, il sistema propone di collegarle.

import AVFoundation
import Combine
import MediaPlayer

final class WristRadio: ObservableObject {
    enum Phase: Equatable {
        case off, connecting, playing
        case failed(String)
    }

    @Published private(set) var station: WristStation?
    @Published private(set) var phase: Phase = .off

    private var player: AVPlayer?
    private var watchers: Set<AnyCancellable> = []

    func play(_ next: WristStation) async {
        stop()
        station = next
        phase = .connecting
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            guard try await session.activate(options: []) else {
                phase = .failed("wr_headphones".wrist)
                return
            }
        } catch {
            phase = .failed("wr_headphones".wrist)
            return
        }
        // Mentre si sceglievano le cuffie si puo' aver cambiato stazione.
        guard station == next, let url = URL(string: next.url) else { return }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.station == next, status == .playing else { return }
                self.phase = .playing
            }
            .store(in: &watchers)
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.station == next, status == .failed else { return }
                self.phase = .failed("wr_cant_play".wrist)
            }
            .store(in: &watchers)
        player.play()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: next.name,
            MPMediaItemPropertyArtist: "\(next.flag) \(next.place)",
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
    }

    func stop() {
        watchers = []
        player?.pause()
        player = nil
        station = nil
        phase = .off
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
