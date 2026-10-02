import Foundation
import AVFoundation

@main
struct SpectrumChecks {
    static func main() throws {
        let count = 4096
        let rate: Double = 48000
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        for frame in 0..<count {
            let value = Float(0.5 * sin(2 * Double.pi * 86 * Double(frame) / Double(count)))
            buffer.floatChannelData![0][frame] = value
            buffer.floatChannelData![1][frame] = -value
        }
        precondition(SignalMeter.db(.infinity).isFinite && SignalMeter.db(.nan).isFinite,
            "Invalid amplitude must not crash the display")
        let levels = SignalMeter.measure(buffer)
        precondition(abs(levels.peaksDB[0] - (-6.0206)) < 0.01, "Peak dBFS is miscalibrated")
        precondition(abs(levels.rmsDB[0] - (-9.0309)) < 0.01, "RMS dBFS is miscalibrated")
        precondition(levels.fullScaleSamples == 0, "Safe tone wrongly marked full scale")
        let analyzer = try SpectrumAnalyzer()
        let bands = analyzer.analyze(buffer)
        let dominant = bands.indices.max { bands[$0] < bands[$1] }!
        precondition(dominant == 7, "1 kHz tone appeared in the wrong band")
        precondition(abs(bands[7] - (-6.0206)) < 0.08, "FFT amplitude is miscalibrated")
        precondition(bands[7] > -10, "Opposite stereo phase cancelled the display")
        buffer.floatChannelData![0][12] = -1
        buffer.floatChannelData![1][10] = 1.001
        buffer.floatChannelData![1][11] = .nan
        let overloaded = SignalMeter.measure(buffer)
        precondition(overloaded.fullScaleSamples == 2, "Full-scale samples were missed")
        precondition(overloaded.invalidSamples == 1, "Invalid sample was missed")
        _ = analyzer.analyze(buffer)
        let interleaved = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: true)!
        let packed = AVAudioPCMBuffer(pcmFormat: interleaved, frameCapacity: AVAudioFrameCount(count))!
        packed.frameLength = AVAudioFrameCount(count)
        for frame in 0..<count {
            packed.floatChannelData![0][frame * 2] = 0.1
            packed.floatChannelData![0][frame * 2 + 1] = 0.3
        }
        let packedLevels = SignalMeter.measure(packed)
        precondition(abs(packedLevels.peaksDB[0] - (-20)) < 0.01, "Interleaved left channel is incorrect")
        precondition(abs(packedLevels.peaksDB[1] - (-10.4576)) < 0.01, "Interleaved right channel is incorrect")
        for channel in 0..<2 { buffer.floatChannelData![channel].update(repeating: 0, count: count) }
        let silence = SignalMeter.measure(buffer)
        precondition(silence.peaksDB.allSatisfy { $0 == -100 })
        precondition(analyzer.analyze(buffer).allSatisfy { $0 == -100 }, "Silence produced fake frequency activity")
        print("PASS: FFT frequency and amplitude, stereo phase, peak/RMS calibration, full-scale detection, invalid samples, interleaved channels and silence.")
    }
}
