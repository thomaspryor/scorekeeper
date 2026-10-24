import AVFoundation

/// Synthesized sound effects. Every sound is generated from tones, so the app ships no audio files.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    struct Note {
        let frequency: Double
        let start: Double
        let duration: Double
        let volume: Float
    }

    static let tickNotes = [Note(frequency: 880, start: 0, duration: 0.12, volume: 0.3)]

    // Rising arpeggio: C5, E5, G5, C6
    static let sortNotes = [
        Note(frequency: 523, start: 0.0, duration: 0.2, volume: 0.15),
        Note(frequency: 659, start: 0.08, duration: 0.2, volume: 0.15),
        Note(frequency: 784, start: 0.16, duration: 0.2, volume: 0.15),
        Note(frequency: 1047, start: 0.24, duration: 0.2, volume: 0.15),
    ]

    // Fanfare C5, E5, G5 (hold), C6, with a shimmer chord on the last note
    static let celebrationNotes = [
        Note(frequency: 523, start: 0, duration: 0.15, volume: 0.2),
        Note(frequency: 659, start: 0.12, duration: 0.15, volume: 0.2),
        Note(frequency: 784, start: 0.24, duration: 0.3, volume: 0.2),
        Note(frequency: 1047, start: 0.5, duration: 0.5, volume: 0.2),
        Note(frequency: 1047, start: 0.5, duration: 0.8, volume: 0.08),
        Note(frequency: 1319, start: 0.5, duration: 0.8, volume: 0.08),
        Note(frequency: 1568, start: 0.5, duration: 0.8, volume: 0.08),
    ]

    private let sampleRate = 44100.0
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var isSetUp = false
    private var consecutiveFailures = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var observers: [NSObjectProtocol] = []

    private init() {
        // AVAudioSession posts these on a background thread. Deliver them on the main
        // queue: a selector-based observer on this main-actor class trips Swift 6's
        // runtime isolation check and crashes the app (e.g. when AirPods connect).
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended else { return }
            MainActor.assumeIsolated {
                try? AVAudioSession.sharedInstance().setActive(true)
                self?.startEngine()
            }
        })
        // Route changes (headphones, AirPods) and configuration changes stop the engine.
        for name in [AVAudioSession.routeChangeNotification, .AVAudioEngineConfigurationChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.startEngine()
                }
            })
        }
    }

    // MARK: - Setup

    private func ensureSetup() {
        guard !isSetUp else { return }

        do {
            // .ambient mixes with other apps' audio and respects the silent switch
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        self.engine = engine
        self.playerNode = playerNode
        self.format = format
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

    // MARK: - Playback

    func playTick() {
        play("tick", Self.tickNotes)
    }

    func playSortSound() {
        play("sort", Self.sortNotes)
    }

    func playCelebration() {
        play("celebration", Self.celebrationNotes)
    }

    private func play(_ key: String, _ notes: [Note]) {
        guard consecutiveFailures < 2 else { return }
        ensureSetup()
        guard let engine, let playerNode else { return }
        if !engine.isRunning {
            startEngine()
            guard engine.isRunning else { return }
        }
        guard let buffer = buffers[key] ?? makeBuffer(notes) else { return }
        buffers[key] = buffer
        // .interrupts: a new sound replaces the current one, so rapid ticks
        // during a long press never queue up and lag behind the finger.
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    /// Mixes the notes into one buffer so chords sound together.
    private func makeBuffer(_ notes: [Note]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let length = notes.map { $0.start + $0.duration }.max() ?? 0
        let frameCount = AVAudioFrameCount(length * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let total = Int(frameCount)
        for i in 0..<total { data[i] = 0 }

        for note in notes {
            let startFrame = Int(note.start * sampleRate)
            let frames = Int(note.duration * sampleRate)
            for i in 0..<frames where startFrame + i < total {
                let t = Double(i) / sampleRate
                let attack = min(1, t / 0.005) // 5 ms fade-in avoids a click
                let envelope = Float(attack * (1 - t / note.duration)) * note.volume
                data[startFrame + i] += envelope * Float(sin(2 * .pi * note.frequency * t))
            }
        }
        return buffer
    }
}
