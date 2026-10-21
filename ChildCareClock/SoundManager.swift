import AVFoundation
import UIKit

/// Haptics always play; the app's soft chimes (in Sounds/) follow the Sounds setting, which by
/// default keeps them quiet at night.
@MainActor
final class SoundManager {
    static let shared = SoundManager()
    var mode = SoundMode.daytime

    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let chimes = ChimePlayer()

    private init() {
        softImpact.prepare()
        notification.prepare()
    }

    func done() {
        play("done")
        notification.notificationOccurred(.success)
    }

    func snooze() {
        play("snooze")
        softImpact.impactOccurred()
    }

    func selection() {
        play("tap")
        softImpact.impactOccurred()
    }

    func warning() {
        notification.notificationOccurred(.warning)
    }

    private func play(_ name: String) {
        guard mode.allowsSound(at: Date()) else { return }
        chimes.play(name)
    }
}

/// Loads and plays the chimes on its own queue, because starting the audio session can block
/// for a moment and would otherwise stall taps. The ambient session follows the ring/silent
/// switch and mixes with music instead of stopping it.
private final class ChimePlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.rajathverse.childcareclock.chimes", qos: .userInitiated)
    private var players: [String: AVAudioPlayer] = [:]

    init() {
        queue.async { [self] in
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            for name in ["done", "snooze", "tap"] {
                guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                      let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.prepareToPlay()
                players[name] = player
            }
        }
    }

    func play(_ name: String) {
        queue.async { [self] in
            guard let player = players[name] else { return }
            player.currentTime = 0
            player.play()
        }
    }
}
