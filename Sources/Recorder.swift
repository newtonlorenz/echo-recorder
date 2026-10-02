import Foundation
import AVFoundation
import CoreAudio
import Observation
import AppKit
import IOKit.pwr_mgt

@MainActor @Observable
final class Recorder: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    var inputs: [AudioInput] = []
    var selectedID: AudioDeviceID = 0
    var library: [SavedAudio] = []
    var recording = false
    var starting = false
    var elapsed: Double = 0
    var level: Float = -160
    var spectrum = SpectrumState()
    var monitorIssue: String?
    var inputName = ""
    var error: String?
    var playingURL: URL?
    var playing = false
    var position: Double = 0
    let folder: URL
    @ObservationIgnored private var monitor: InputMonitor?
    @ObservationIgnored private var fallbackHeldPeaks: [Float] = []
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var sleepAssertion: IOPMAssertionID = 0
    @ObservationIgnored private var priorInput: AudioDeviceID?
    @ObservationIgnored private var expectedInput: AudioDeviceID?
    @ObservationIgnored private var currentURL: URL?
    @ObservationIgnored private var healthCheck = Date.distantPast

    override init() {
        folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EchoRecorder", isDirectory: true)
        super.init()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            refreshInputs()
            refreshLibrary()
        } catch { self.error = error.localizedDescription }
    }

    var selected: AudioInput? { inputs.first { $0.id == selectedID } }
    var freeBytes: Int64 {
        guard let values = try? FileManager.default.attributesOfFileSystem(forPath: folder.path) else { return 0 }
        return (values[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }

    func refreshInputs() {
        inputs = AudioInput.all()
        if !inputs.contains(where: { $0.id == selectedID }) {
            selectedID = inputs.first(where: { !$0.builtIn })?.id ?? AudioInput.defaultID()
        }
    }

    func refreshLibrary() {
        do { library = try AudioFiles.library(in: folder, excluding: currentURL) }
        catch { self.error = error.localizedDescription }
    }

    func start() async {
        guard !recording, !starting else { return }
        starting = true
        defer { starting = false }
        guard let input = selected, !input.builtIn else {
            error = "Choose the iPhone USB input or a stereo line-input audio interface."
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            error = "Allow Echo Recorder in System Settings → Privacy & Security → Microphone. macOS requires this permission for wired audio inputs too."
            return
        }
        do {
            guard freeBytes > 128 * 1024 * 1024 else { throw failure("There is not enough free storage to start.") }
            stopPlayback()
            priorInput = AudioInput.defaultID()
            try AudioInput.select(input.id)
            expectedInput = input.id
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let url = folder.appendingPathComponent("Recording \(stamp)-\(UUID().uuidString.prefix(6)).caf")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: input.rate,
                AVNumberOfChannelsKey: min(2, input.channels),
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let next = try AVAudioRecorder(url: url, settings: settings)
            next.delegate = self
            next.isMeteringEnabled = true
            guard next.prepareToRecord(), next.record() else { throw failure("The audio input could not start recording.") }
            recorder = next
            currentURL = url
            inputName = input.name
            recording = true
            elapsed = 0
            level = -160
            spectrum = SpectrumState()
            monitorIssue = nil
            fallbackHeldPeaks = []
            do {
                let nextMonitor = try InputMonitor()
                try nextMonitor.start()
                monitor = nextMonitor
            } catch {
                monitorIssue = "Spectrum unavailable: " + error.localizedDescription
            }
            healthCheck = .distantPast
            let status = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), "Echo audio recording" as CFString, &sleepAssertion)
            if status != kIOReturnSuccess {
                sleepAssertion = 0
                error = "Recording started, but Echo could not prevent Mac sleep. Keep the Mac awake and powered."
            }
        } catch {
            self.error = error.localizedDescription
            restoreInput()
        }
    }

    func tick() {
        if recording, let recorder {
            elapsed = recorder.currentTime
            recorder.updateMeters()
            let channels = recorder.settings[AVNumberOfChannelsKey] as? Int ?? 1
            let rms = (0..<max(1, channels)).map { recorder.averagePower(forChannel: $0) }
            let peaks = (0..<max(1, channels)).map { recorder.peakPower(forChannel: $0) }
            level = rms.max() ?? -160
            if fallbackHeldPeaks.count != peaks.count { fallbackHeldPeaks = Array(repeating: -100, count: peaks.count) }
            for index in peaks.indices { fallbackHeldPeaks[index] = max(fallbackHeldPeaks[index], peaks[index]) }
            if let monitor {
                spectrum = monitor.snapshot()
                monitorIssue = spectrum.issue
                if elapsed > 3 && !spectrum.live {
                    monitorIssue = "The spectrum tap is not receiving audio. Peak meters remain available."
                }
            }
            if !spectrum.live {
                spectrum.peaksDB = peaks
                spectrum.rmsDB = rms
                spectrum.heldPeaksDB = fallbackHeldPeaks
                spectrum.hasFullScalePeak = fallbackHeldPeaks.contains { $0 >= -0.001 }
            }
            if !recorder.isRecording {
                stop()
                error = "The audio input stopped. Captured audio has been saved."
                return
            }
            if Date().timeIntervalSince(healthCheck) >= 2 {
                healthCheck = Date()
                if freeBytes < 64 * 1024 * 1024 {
                    stop()
                    error = "Storage is almost full. Captured audio has been saved."
                    return
                }
                if let expectedInput,
                    AudioInput.defaultID() != expectedInput || !AudioInput.all().contains(where: { $0.id == expectedInput }) {
                    stop()
                    error = "The selected input changed or disconnected. Captured audio has been saved."
                }
            }
        }
        position = player?.currentTime ?? 0
        playing = player?.isPlaying ?? false
    }

    func stop() {
        if let monitor { monitor.stop(); spectrum = monitor.snapshot() }
        monitor = nil
        recorder?.stop()
        recorder = nil
        recording = false
        level = -160
        currentURL = nil
        if sleepAssertion != 0 { IOPMAssertionRelease(sleepAssertion); sleepAssertion = 0 }
        restoreInput()
        refreshLibrary()
    }

    func resetPeaks() {
        monitor?.resetPeaks()
        fallbackHeldPeaks = Array(repeating: -100, count: fallbackHeldPeaks.count)
        spectrum.heldPeaksDB = Array(repeating: -100, count: spectrum.heldPeaksDB.count)
        spectrum.fullScaleSamples = 0
        spectrum.invalidSamples = 0
        spectrum.hasFullScalePeak = false
    }

    private func restoreInput() {
        if let priorInput, let expectedInput, AudioInput.defaultID() == expectedInput {
            try? AudioInput.select(priorInput)
        }
        priorInput = nil
        expectedInput = nil
    }

    func toggle(_ audio: SavedAudio) {
        guard !recording else { return }
        do {
            if playingURL == audio.url, let player {
                if player.isPlaying { player.pause() } else { player.play() }
            } else {
                stopPlayback()
                let next = try AVAudioPlayer(contentsOf: audio.url)
                next.delegate = self
                guard next.play() else { throw failure("This audio could not be played.") }
                player = next
                playingURL = audio.url
            }
            tick()
        } catch { self.error = error.localizedDescription }
    }

    func seek(_ time: Double) { player?.currentTime = time; position = time }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingURL = nil
        position = 0
        playing = false
    }

    func export(_ audio: SavedAudio) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = audio.url.lastPathComponent
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }
            do { try AudioFiles.export(audio.url, to: destination) }
            catch { self?.error = error.localizedDescription }
        }
    }

    func delete(_ audio: SavedAudio) {
        if playingURL == audio.url { stopPlayback() }
        do { try FileManager.default.removeItem(at: audio.url); refreshLibrary() }
        catch { self.error = error.localizedDescription }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "EchoRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.stop()
            self?.error = error?.localizedDescription ?? "Recording was interrupted."
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.stopPlayback()
        }
    }
}
