import Foundation
import AVFoundation

// A separate input tap monitors the same selected device without audio playback.
// The OS recorder remains responsible for the continuous audio file.
final class InputMonitor: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private var copyBuffer: AVAudioPCMBuffer?
    private let analyzer: SpectrumAnalyzer
    private let analysisQueue = DispatchQueue(label: "local.echo.spectrum", qos: .utility)
    private let analysisSlot = DispatchSemaphore(value: 1)
    private let analysisKey = DispatchSpecificKey<Bool>()
    private let lock = NSLock()
    private var state = SpectrumState()
    private var intervalPeaks: [Float] = []
    private var accepting = false

    init() throws {
        analyzer = try SpectrumAnalyzer()
        analysisQueue.setSpecific(key: analysisKey, value: true)
    }

    func start() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0, format.commonFormat == .pcmFormatFloat32,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384) else {
            throw NSError(domain: "EchoSpectrum", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "This device does not provide a supported spectrum-monitor format."])
        }
        copyBuffer = buffer
        lock.lock()
        accepting = true
        state = SpectrumState()
        intervalPeaks = []
        lock.unlock()
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] audio, _ in
            self?.receive(audio)
        }
        self.engine = engine
        do { engine.prepare(); try engine.start() }
        catch { stop(); throw error }
    }

    private func receive(_ buffer: AVAudioPCMBuffer) {
        let levels = SignalMeter.measure(buffer)
        lock.lock()
        guard accepting else { lock.unlock(); return }
        if intervalPeaks.count != levels.peaksDB.count {
            intervalPeaks = Array(repeating: -100, count: levels.peaksDB.count)
            state.heldPeaksDB = intervalPeaks
        }
        for index in levels.peaksDB.indices {
            intervalPeaks[index] = max(intervalPeaks[index], levels.peaksDB[index])
            state.heldPeaksDB[index] = max(state.heldPeaksDB[index], levels.peaksDB[index])
        }
        state.peaksDB = levels.peaksDB
        state.rmsDB = levels.rmsDB
        state.fullScaleSamples += levels.fullScaleSamples
        state.invalidSamples += levels.invalidSamples
        state.framesReceived += Int64(buffer.frameLength)
        state.updatedAt = Date()
        lock.unlock()

        // Never queue an unbounded number of buffers on the audio callback.
        guard analysisSlot.wait(timeout: .now()) == .success else { return }
        guard let copyBuffer, buffer.format == copyBuffer.format,
            buffer.frameLength <= copyBuffer.frameCapacity else {
            analysisSlot.signal()
            lock.lock()
            state.issue = "The input format changed or the monitoring buffer is too large."
            lock.unlock()
            return
        }
        copyBuffer.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let destination = UnsafeMutableAudioBufferListPointer(copyBuffer.mutableAudioBufferList)
        for index in source.indices {
            guard let sourceData = source[index].mData, let destinationData = destination[index].mData else { continue }
            let bytes = Int(buffer.frameLength) * Int(source[index].mNumberChannels) * MemoryLayout<Float>.size
            guard bytes <= Int(source[index].mDataByteSize), bytes <= Int(destination[index].mDataByteSize) else {
                analysisSlot.signal()
                lock.lock()
                state.issue = "Monitoring received an inconsistent audio buffer."
                lock.unlock()
                return
            }
            memcpy(destinationData, sourceData, bytes)
        }
        analysisQueue.async { [self] in
            let bands = analyzer.analyze(copyBuffer)
            lock.lock()
            state.bandsDB = bands
            lock.unlock()
            analysisSlot.signal()
        }
    }

    func snapshot() -> SpectrumState {
        lock.lock()
        defer { lock.unlock() }
        var result = state
        result.peaksDB = intervalPeaks.enumerated().map { index, peak in
            peak > -100 ? peak : (index < state.peaksDB.count ? state.peaksDB[index] : -100)
        }
        intervalPeaks = Array(repeating: -100, count: intervalPeaks.count)
        return result
    }

    func resetPeaks() {
        lock.lock()
        state.heldPeaksDB = Array(repeating: -100, count: state.heldPeaksDB.count)
        state.fullScaleSamples = 0
        state.invalidSamples = 0
        lock.unlock()
    }

    func stop() {
        lock.lock()
        accepting = false
        lock.unlock()
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        self.engine = nil
        if DispatchQueue.getSpecific(key: analysisKey) != true { analysisQueue.sync {} }
        copyBuffer = nil
    }

    deinit { stop() }
}
