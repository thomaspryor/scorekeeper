import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isSetUp = false
    private var consecutiveFailures = 0

    private init() {
        setupNotifications()
    }

    // MARK: - Setup with interruption handling

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification, object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            // Try to restart engine after interruption
            try? AVAudioSession.sharedInstance().setActive(true)
            startEngine()
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        // Restart engine on route changes (AirPods disconnect etc.)
        startEngine()
    }

    private func ensureSetup() {
        guard !isSetUp else { return }

        do {
            // Use .ambient so we don't mute other apps, and respect silent switch
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        self.engine = engine
        self.playerNode = playerNode
        self.isSetUp = true
        startEngine()
    }

    private func startEngine() {
        guard let engine, !engine.isRunning else { return }
        do {
            try engine.start()
            consecutiveFailures = 0
        } catch {
            consecutiveFailures += 1
        }
    }

    // MARK: - Sound playback

    func playTick() {
        guard consecutiveFailures < 2 else { return }
        ensureSetup()
        playTone(frequency: 880, duration: 0.12, volume: 0.3)
    }

    func playSortSound() {
        guard consecutiveFailures < 2 else { return }
        ensureSetup()

        // Rising arpeggio: C5, E5, G5, C6
        let notes: [(freq: Double, delay: Double)] = [
            (523, 0.0), (659, 0.08), (784, 0.16), (1047, 0.24)
        ]
        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) { [weak self] in
                self?.playTone(frequency: note.freq, duration: 0.2, volume: 0.15)
            }
        }
    }

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        guard let playerNode, let engine, engine.isRunning else {
            startEngine()
            return
        }

        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = Float(max(0, volume * (1.0 - Float(t / duration))))
            data[i] = envelope * sin(Float(2.0 * .pi * frequency * t))
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
}
