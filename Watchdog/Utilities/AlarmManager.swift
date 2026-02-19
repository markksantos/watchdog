import AVFoundation
import Combine
import os

class AlarmManager {
    static let shared = AlarmManager()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var autoStopTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Synthesis state — protected by synthLock for audio thread safety
    private var phase: Double = 0.0
    private var currentFrequency: Double = 440.0
    private var targetFrequency: Double = 440.0
    private var isToneOn: Bool = true
    private var phaseToggleTimer: Timer?
    private var sampleRate: Double = 44100.0
    private var synthLock = os_unfair_lock()

    private init() {
        SettingsManager.shared.$alarmEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if !enabled { self?.stop() }
            }
            .store(in: &cancellables)
    }

    func trigger() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.startAlarm()
            self.autoStopTimer?.invalidate()
            self.autoStopTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                self?.stop()
            }
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.stopAlarm()
        }
    }

    func test() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.startAlarm()
            self.autoStopTimer?.invalidate()
            self.autoStopTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.stop()
            }
        }
    }

    private func startAlarm() {
        stopAlarm()

        let sound = SettingsManager.shared.alarmSound
        let volume = Float(SettingsManager.shared.alarmVolume)
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate == 0 { sampleRate = 44100.0 }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("[AlarmManager] Failed to create audio format")
            return
        }

        switch sound {
        case .siren:
            currentFrequency = 440.0
            targetFrequency = 880.0
            scheduleSirenToggle(interval: 0.7)
        case .alert:
            currentFrequency = 1000.0
            schedulePulseToggle(onInterval: 0.3, offInterval: 0.2)
        case .klaxon:
            currentFrequency = 600.0
            targetFrequency = 1200.0
            scheduleSirenToggle(interval: 0.15)
        }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first, let data = buffer.mData else { return noErr }
            let ptr = data.bindMemory(to: Float.self, capacity: Int(frameCount))
            let twoPi = 2.0 * Double.pi

            os_unfair_lock_lock(&self.synthLock)
            let freq = self.currentFrequency
            let sr = self.sampleRate
            let toneOn = self.isToneOn
            var localPhase = self.phase
            os_unfair_lock_unlock(&self.synthLock)

            for frame in 0..<Int(frameCount) {
                let sample: Float
                if toneOn {
                    sample = Float(sin(localPhase)) * volume
                    localPhase += twoPi * freq / sr
                    if localPhase > twoPi { localPhase -= twoPi }
                } else {
                    sample = 0.0
                }
                ptr[frame] = sample
            }

            os_unfair_lock_lock(&self.synthLock)
            self.phase = localPhase
            os_unfair_lock_unlock(&self.synthLock)

            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("[AlarmManager] Failed to start engine: \(error)")
        }
    }

    private func stopAlarm() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        phaseToggleTimer?.invalidate()
        phaseToggleTimer = nil

        if engine.isRunning { engine.stop() }
        engine.reset()
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
        phase = 0.0
        isToneOn = true
    }

    private func scheduleSirenToggle(interval: TimeInterval) {
        isToneOn = true
        phaseToggleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            os_unfair_lock_lock(&self.synthLock)
            swap(&self.currentFrequency, &self.targetFrequency)
            os_unfair_lock_unlock(&self.synthLock)
        }
    }

    private func schedulePulseToggle(onInterval: TimeInterval, offInterval: TimeInterval) {
        isToneOn = true
        func scheduleNext() {
            let interval = isToneOn ? onInterval : offInterval
            phaseToggleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                guard let self else { return }
                os_unfair_lock_lock(&self.synthLock)
                self.isToneOn.toggle()
                os_unfair_lock_unlock(&self.synthLock)
                scheduleNext()
            }
        }
        scheduleNext()
    }
}
