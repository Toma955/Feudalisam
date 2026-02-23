//
//  AudioManager.swift
//  Feudalism
//
//  Muzika mape, zvukovi i govor. Glasnoće proslijedi pozivatelj (npr. iz GameState, Postavke → Audio).
//

import AVFoundation
import AppKit

/// Jedan upravitelj za muziku mape (loop), zvukove (jednokratno) i govor (TTS).
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    /// Ime datoteke muzike mape u bundleu (bez ekstenzije). Dodaj map_music.mp3 ili .m4a u Copy Bundle Resources.
    static let mapMusicAssetName = "map_music"
    static let mapMusicExtensions = ["mp3", "m4a", "wav"]

    private var mapMusicPlayer: AVAudioPlayer?
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private let speechSynthesizer = AVSpeechSynthesizer()

    private init() {}

    // MARK: - Muzika mape

    /// Pokreni muziku mape u petlji. Ako datoteka ne postoji, ništa se ne reproducira. volume 0...1.
    func playMapMusicIfAvailable(volume: Double) {
        stopMapMusic()
        guard let url = urlForMapMusic(), volume > 0.01 else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(volume)
            player.prepareToPlay()
            player.play()
            mapMusicPlayer = player
        } catch {
            mapMusicPlayer = nil
        }
    }

    func stopMapMusic() {
        mapMusicPlayer?.stop()
        mapMusicPlayer = nil
    }

    /// Ažuriraj glasnoću trenutno puštane muzike mape (npr. kad korisnik mijenja Postavke → Audio).
    func updateMapMusicVolume(volume: Double) {
        mapMusicPlayer?.volume = Float(volume)
    }

    private func urlForMapMusic() -> URL? {
        let bundle = Bundle.main
        for ext in Self.mapMusicExtensions {
            if let url = bundle.url(forResource: Self.mapMusicAssetName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    // MARK: - Zvukovi

    /// Reproduciraj zvuk iz bundlea (npr. "place_wall", "click"). volume 0...1; ako nije proslijeđen, koristi 0.8.
    func playSound(named name: String, volume: Double = 0.8) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        guard volume > 0.01 else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(volume)
            player.prepareToPlay()
            player.play()
            soundPlayers[name] = player
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
                self?.soundPlayers.removeValue(forKey: name)
            }
        } catch {
            soundPlayers.removeValue(forKey: name)
        }
    }

    // MARK: - Govor (TTS)

    /// Reproduciraj govor (sintetizator). volume 0...1.
    func speak(_ text: String, volume: Double = 0.8) {
        guard volume > 0.01, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.volume = Float(volume)
        if #available(macOS 14.0, *) {
            utterance.voice = AVSpeechSynthesisVoice(language: "hr-HR") ?? AVSpeechSynthesisVoice(language: "en-US")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "hr-HR")
        }
        speechSynthesizer.speak(utterance)
    }

    func stopSpeech() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
