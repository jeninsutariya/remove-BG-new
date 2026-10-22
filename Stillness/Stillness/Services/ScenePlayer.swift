import AVFoundation
import Observation

/// The looping background sound behind every screen. Quieter while a session plays.
@Observable @MainActor
final class ScenePlayer {
    private(set) var activeSceneID: String?
    var volume: Float = 0.6 { didSet { applyVolume() } }
    var isDucked = false { didSet { applyVolume() } }

    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    func play(_ scene: SceneItem) {
        stopTask?.cancel()
        if scene.id == activeSceneID, audioPlayer?.isPlaying == true { return }

        audioPlayer?.stop()
        audioPlayer = nil
        activeSceneID = scene.id
        guard let location = scene.loopAudio, let url = CatalogService.resolve(location) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            audioPlayer = player
            applyVolume()
            player.play()
        } catch {
            print("Scene audio error: \(error)")
        }
    }

    func stop() {
        stopTask?.cancel()
        audioPlayer?.stop()
        audioPlayer = nil
        activeSceneID = nil
    }

    /// Keeps the sound going outside the app for a while, then fades it out. 0 stops it now.
    func stop(afterMinutes minutes: Int) {
        stopTask?.cancel()
        guard audioPlayer != nil else { return }
        guard minutes > 0 else {
            stop()
            return
        }
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(minutes) * 60))
            guard !Task.isCancelled else { return }
            self?.audioPlayer?.setVolume(0, fadeDuration: 3)
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func cancelScheduledStop() {
        stopTask?.cancel()
        stopTask = nil
        applyVolume()
    }

    private func applyVolume() {
        audioPlayer?.volume = isDucked ? volume * 0.4 : volume
    }
}
