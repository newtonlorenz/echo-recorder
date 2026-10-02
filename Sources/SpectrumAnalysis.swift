import Foundation
import AVFoundation
import Accelerate

struct SignalLevels {
    let peaksDB: [Float]
    let rmsDB: [Float]
    let fullScaleSamples: Int
    let invalidSamples: Int
}

struct SpectrumState {
    var bandsDB = [Float](repeating: -100, count: SpectrumAnalyzer.frequencies.count)
    var peaksDB: [Float] = []
    var rmsDB: [Float] = []
    var heldPeaksDB: [Float] = []
    var fullScaleSamples: Int = 0
    var hasFullScalePeak = false
    var invalidSamples: Int = 0
    var framesReceived: Int64 = 0
    var updatedAt: Date?
    var issue: String?
    var live: Bool { updatedAt.map { Date().timeIntervalSince($0) < 2 } ?? false }
    var possibleClipping: Bool { fullScaleSamples > 0 || hasFullScalePeak || invalidSamples > 0 }
}

enum SignalMeter {
    static let fullScaleThreshold: Float = 1 - 1 / 32768
    static func db(_ amplitude: Float) -> Float {
        guard amplitude.isFinite else { return amplitude > 0 ? 60 : -100 }
        return min(60, max(-100, 20 * log10(max(amplitude, 0.00001))))
    }
    static func measure(_ buffer: AVAudioPCMBuffer) -> SignalLevels {
        let count = Int(buffer.frameLength)
        guard count > 0, let data = buffer.floatChannelData else {
            return SignalLevels(peaksDB: [], rmsDB: [], fullScaleSamples: 0, invalidSamples: 0)
        }
        let channels = min(2, Int(buffer.format.channelCount))
        let stride = buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1
        var peaks: [Float] = []
        var rms: [Float] = []
        var fullScale = 0
        var invalid = 0
        for channel in 0..<channels {
            let input = buffer.format.isInterleaved ? data[0].advanced(by: channel) : data[channel]
            var peak: Float = 0
            var squares: Double = 0
            for frame in 0..<count {
                let value = input[frame * stride]
                guard value.isFinite else { invalid += 1; continue }
                let magnitude = abs(value)
                peak = max(peak, magnitude)
                squares += Double(value) * Double(value)
                if magnitude >= fullScaleThreshold { fullScale += 1 }
            }
            peaks.append(db(peak))
            rms.append(db(Float(sqrt(squares / Double(count)))))
        }
        return SignalLevels(peaksDB: peaks, rmsDB: rms, fullScaleSamples: fullScale, invalidSamples: invalid)
    }
}

// The display analyzes audio; it never changes the signal being recorded.
final class SpectrumAnalyzer {
    static let frequencies: [Float] = [40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000]
    static let labels = ["40", "63", "100", "160", "250", "400", "630", "1k", "1.6k", "2.5k", "4k", "6.3k", "10k", "16k"]
    private let length = 4096
    private let setup: vDSP_DFT_Setup
    private var inputReal = [Float](repeating: 0, count: 4096)
    private var inputImag = [Float](repeating: 0, count: 4096)
    private var outputReal = [Float](repeating: 0, count: 4096)
    private var outputImag = [Float](repeating: 0, count: 4096)

    init() throws {
        guard let value = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(length), .FORWARD) else {
            throw NSError(domain: "EchoSpectrum", code: 1, userInfo: [NSLocalizedDescriptionKey: "The spectrum analyzer could not initialize."])
        }
        setup = value
    }
    deinit { vDSP_DFT_DestroySetup(setup) }

    func analyze(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else {
            return Array(repeating: -100, count: Self.frequencies.count)
        }
        let count = min(length, Int(buffer.frameLength))
        let offset = Int(buffer.frameLength) - count
        let channels = min(2, Int(buffer.format.channelCount))
        let stride = buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1
        let rate = Float(buffer.format.sampleRate)
        var powers = [Float](repeating: 0, count: Self.frequencies.count)
        for channel in 0..<channels {
            let samples = buffer.format.isInterleaved ? data[0].advanced(by: channel) : data[channel]
            var windowSum: Float = 0
            for frame in 0..<length {
                if frame < count {
                    let window = 0.5 - 0.5 * cos(2 * Float.pi * Float(frame) / Float(count))
                    let value = samples[(frame + offset) * stride]
                    inputReal[frame] = value.isFinite ? value * window : 0
                    windowSum += window
                } else { inputReal[frame] = 0 }
            }
            vDSP_DFT_Execute(setup, inputReal, inputImag, &outputReal, &outputImag)
            let scale: Float = 2 / max(1, windowSum)
            for (band, center) in Self.frequencies.enumerated() {
                guard center < rate / 2 else { continue }
                let lower = band == 0 ? center / 1.26 : sqrt(center * Self.frequencies[band - 1])
                let upper = band == Self.frequencies.count - 1 ? min(rate / 2, center * 1.26)
                    : sqrt(center * Self.frequencies[band + 1])
                let low = max(1, min(length / 2 - 1, Int(ceil(lower * Float(length) / rate))))
                let high = max(low, min(length / 2 - 1, Int(floor(upper * Float(length) / rate))))
                var peakPower: Float = 0
                for bin in low...high {
                    let real = outputReal[bin]
                    let imag = outputImag[bin]
                    peakPower = max(peakPower, (real * real + imag * imag) * scale * scale)
                }
                // Average channel power, avoiding cancellation between stereo channels.
                powers[band] += peakPower / Float(max(1, channels))
            }
        }
        return powers.map { SignalMeter.db(sqrt($0)) }
    }
}
