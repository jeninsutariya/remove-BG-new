import AVFoundation
import MediaPlayer
import Observation

/// Plays one session at a time, keeps playing with the screen locked,
/// and shows on the lock screen and Control Center.
@Observable @MainActor
final class PlayerController {
    private(set) var current: ContentItem?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    /// Set when a session plays to the end. The player shows the completion screen.
    private(set) var finishedItem: ContentItem?
    private(set) var sleepTimerEndsAt: Date?

    /// Called once per session when it ends or is stopped: item, start time, seconds listened, completed.
    @ObservationIgnored var onSessionEnded: (@MainActor (ContentItem, Date, Double, Bool) -> Void)?

    private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var sessionObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var sleepTimerTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var furthestTime: Double = 0
    @ObservationIgnored private var sessionOpen = false

    init() {
        configureRemoteCommands()
        observeAudioSession()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
    }

    // MARK: Controls

    func play(_ item: ContentItem, from url: URL) {
        endCurrentSession(completed: false)
        activateAudioSession()

        let playerItem = AVPlayerItem(url: url)
        current = item
        finishedItem = nil
        currentTime = 0
        furthestTime = 0
        duration = Double(item.durationSeconds)
        startedAt = .now
        sessionOpen = true

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.didReachEnd() }
        }

        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true
        updateNowPlaying()

        Task { [weak self] in
            guard let seconds = try? await playerItem.asset.load(.duration).seconds,
                  seconds.isFinite, seconds > 0 else { return }
            self?.duration = seconds
            self?.updateNowPlaying()
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard current != nil else { return }
        if finishedItem != nil {
            finishedItem = nil
            startedAt = .now
            furthestTime = 0
            sessionOpen = true
            seek(to: 0)
        }
        activateAudioSession()
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func skip(by seconds: Double) {
        seek(to: min(max(0, currentTime + seconds), duration))
    }

    func seek(to seconds: Double) {
        currentTime = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        updateNowPlaying()
    }

    /// Stops playback, logs the session if one is open, and hides the mini player.
    func stop() {
        endCurrentSession(completed: false)
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        finishedItem = nil
        isPlaying = false
        setSleepTimer(minutes: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setSleepTimer(minutes: Int?) {
        sleepTimerTask?.cancel()
        guard let minutes else {
            sleepTimerEndsAt = nil
            return
        }
        let seconds = Double(minutes) * 60
        sleepTimerEndsAt = Date.now.addingTimeInterval(seconds)
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.pause()
            self?.sleepTimerEndsAt = nil
        }
    }

    // MARK: Session bookkeeping

    private func tick(_ seconds: Double) {
        guard current != nil, seconds.isFinite else { return }
        currentTime = seconds
        furthestTime = max(furthestTime, seconds)
        isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    private func didReachEnd() {
        guard let item = current else { return }
        if item.kind.loops {
            player.seek(to: .zero)
            player.play()
            return
        }
        isPlaying = false
        currentTime = duration
        furthestTime = max(furthestTime, duration)
        endCurrentSession(completed: true)
        finishedItem = item
        updateNowPlaying()
    }

    private func endCurrentSession(completed: Bool) {
        guard sessionOpen, let item = current else { return }
        sessionOpen = false
        let listened = item.kind.loops ? Date.now.timeIntervalSince(startedAt) : furthestTime
        onSessionEnded?(item, startedAt, listened, completed)
    }

    // MARK: Audio session

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated { self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw) }
        })
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated {
                // Headphones unplugged: pause instead of playing out loud.
                if let reasonRaw, AVAudioSession.RouteChangeReason(rawValue: reasonRaw) == .oldDeviceUnavailable {
                    self?.pause()
                }
            }
        })
    }

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            isPlaying = false
            updateNowPlaying()
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if options.contains(.shouldResume), current != nil, finishedItem == nil {
                resume()
            }
        @unknown default:
            break
        }
    }

    // MARK: Lock screen

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        _ = commands.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
            return .success
        }
        _ = commands.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        _ = commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.togglePlayPause() }
            return .success
        }
        commands.skipForwardCommand.preferredIntervals = [15]
        _ = commands.skipForwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.skip(by: 15) }
            return .success
        }
        commands.skipBackwardCommand.preferredIntervals = [15]
        _ = commands.skipBackwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.skip(by: -15) }
            return .success
        }
        _ = commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            MainActor.assumeIsolated { self?.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let item = current else { return }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.kind.label,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
