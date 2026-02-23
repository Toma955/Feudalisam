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

    /// Intro soundtrack (početna animacija). Datoteka soundtrack.mp3 u Audio folderu.
    static let introSoundtrackName = "soundtrack"
    static let introSoundtrackExtensions = ["mp3", "m4a", "wav"]

    private var mapMusicPlayer: AVAudioPlayer?
    private var introSoundtrackPlayer: AVAudioPlayer?
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

    private static let fadeOutDuration: TimeInterval = 0.6
    private static let fadeOutSteps = 12

    func stopMapMusic() {
        guard let player = mapMusicPlayer else { return }
        mapMusicPlayer = nil
        fadeOutAndStop(player: player, duration: Self.fadeOutDuration)
    }

    // MARK: - Intro soundtrack (početna animacija)

    /// Pokreni intro soundtrack (soundtrack.mp3). volume 0...1. Zaustavi pri stopIntroSoundtrack().
    func playIntroSoundtrackIfAvailable(volume: Double) {
        stopIntroSoundtrack()
        guard let url = urlForIntroSoundtrack(), volume > 0.01 else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.volume = Float(volume)
            player.prepareToPlay()
            player.play()
            introSoundtrackPlayer = player
        } catch {
            introSoundtrackPlayer = nil
        }
    }

    func stopIntroSoundtrack() {
        guard let player = introSoundtrackPlayer else { return }
        introSoundtrackPlayer = nil
        fadeOutAndStop(player: player, duration: Self.fadeOutDuration)
    }

    /// Lagani fade out: smanji glasnoću do 0 pa zaustavi reprodukciju.
    private func fadeOutAndStop(player: AVAudioPlayer, duration: TimeInterval) {
        let startVolume = player.volume
        let stepCount = Self.fadeOutSteps
        let stepDuration = duration / Double(stepCount)
        var step = 0
        func nextStep() {
            step += 1
            if step > stepCount {
                player.stop()
                return
            }
            let progress = Double(step) / Double(stepCount)
            player.volume = max(0, Float(startVolume) * Float(1 - progress))
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) { nextStep() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) { nextStep() }
    }

    private func urlForIntroSoundtrack() -> URL? {
        let bundle = Bundle.main
        for ext in Self.introSoundtrackExtensions {
            if let url = bundle.url(forResource: Self.introSoundtrackName, withExtension: ext) {
                return url
            }
        }
        return nil
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

    /// Podmape u bundleu u kojima tražiti zvuk (npr. place.wav u Audio ili Core/Audio).
    private static let soundSubdirectories = ["Audio", "Core/Audio", "Feudalism/Core/Audio", nil as String?]

    /// Reproduciraj zvuk iz bundlea (npr. "place" → place.wav u folderu Audio). volume 0...1; ako nije proslijeđen, koristi 0.8.
    func playSound(named name: String, volume: Double = 0.8) {
        let bundle = Bundle.main
        let exts = ["wav", "mp3", "m4a"]
        var url: URL?
        for sub in Self.soundSubdirectories {
            for ext in exts {
                if let u = sub != nil
                    ? bundle.url(forResource: name, withExtension: ext, subdirectory: sub)
                    : bundle.url(forResource: name, withExtension: ext) {
                    url = u
                    break
                }
            }
            if url != nil { break }
        }
        guard let url = url else { return }
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
