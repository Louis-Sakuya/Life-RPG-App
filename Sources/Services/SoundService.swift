import AVFoundation
import Foundation

enum SoundCue: String, Sendable {
    case complete
    case levelUp
    case purchase
    case checkIn
}

/// 用内存里的短正弦波模拟复古 RPG 提示音，不依赖资源文件。
final class SoundService {
    static let shared = SoundService()

    private var players: [AVAudioPlayer] = []
    private var sessionReady = false

    private init() {}

    func play(_ cue: SoundCue) {
        let notes: [(frequency: Double, duration: Double)]
        switch cue {
        case .checkIn:
            notes = [(659.25, 0.08)]
        case .purchase:
            notes = [(880.0, 0.07), (1174.66, 0.11)]
        case .complete:
            notes = [(523.25, 0.08), (659.25, 0.08), (783.99, 0.14)]
        case .levelUp:
            notes = [(523.25, 0.08), (659.25, 0.08), (783.99, 0.08), (1046.5, 0.2)]
        }

        var delay: Double = 0
        for note in notes {
            let captured = note
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.playTone(frequency: captured.frequency, duration: captured.duration)
            }
            delay += note.duration * 0.82
        }
    }

    private func playTone(frequency: Double, duration: Double) {
        prepareSession()
        guard let data = Self.wav(frequency: frequency, duration: duration),
              let player = try? AVAudioPlayer(data: data) else { return }
        player.prepareToPlay()
        player.volume = 0.55
        player.play()
        players.append(player)
        players = players.filter(\.isPlaying) + [player]
    }

    private func prepareSession() {
        guard !sessionReady else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            sessionReady = true
        } catch {
            sessionReady = false
        }
    }

    private static func wav(frequency: Double, duration: Double) -> Data? {
        let sampleRate = 22_050.0
        let count = max(64, Int(sampleRate * duration))
        let fade = min(800, count / 6)
        var samples = [Int16](repeating: 0, count: count)
        for index in 0..<count {
            let attack = min(1, Double(index) / Double(max(1, fade)))
            let release = min(1, Double(count - index) / Double(max(1, fade)))
            let envelope = attack * release
            let value = sin(2 * Double.pi * frequency * Double(index) / sampleRate)
            samples[index] = Int16((value * envelope * 0.32 * Double(Int16.max)).rounded())
        }

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: u32(36 + UInt32(count * 2)))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.append(contentsOf: u32(16))
        data.append(contentsOf: u16(1))
        data.append(contentsOf: u16(1))
        data.append(contentsOf: u32(UInt32(sampleRate)))
        data.append(contentsOf: u32(UInt32(sampleRate * 2)))
        data.append(contentsOf: u16(2))
        data.append(contentsOf: u16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: u32(UInt32(count * 2)))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private static func u16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8)]
    }

    private static func u32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
}
