import Foundation
import AVFoundation

@main
struct ExportChecks {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EchoExportChecks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (rate, channels) in [(48000.0, 2), (44100.0, 1), (96000.0, 2)] {
            let source = root.appendingPathComponent("source-\(Int(rate))-\(channels).caf")
            try makeTone(at: source, rate: rate, channels: channels, seconds: 6)
            let original = try Data(contentsOf: source)
            let destination = root.appendingPathComponent("compressed-\(Int(rate))-\(channels).m4a")
            let job = AudioExportJob(source: source, destination: destination, format: .aac)
            try await job.run()
            let audio = try AVAudioFile(forReading: destination)
            precondition(audio.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatMPEG4AAC)
            precondition(Int(audio.fileFormat.channelCount) == channels, "Channels changed")
            let duration = Double(audio.length) / audio.processingFormat.sampleRate
            precondition(abs(duration - 6) < 0.1, "Export lost duration")
            let encoded = try Data(contentsOf: destination)
            precondition(encoded.count < original.count / 3, "AAC did not reduce size")
            let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 8192)!
            try audio.read(into: buffer)
            precondition(buffer.frameLength > 4096, "Export cannot be decoded")
            for channel in 0..<channels {
                let samples = buffer.floatChannelData![channel]
                let power = (0..<Int(buffer.frameLength)).reduce(0.0) { $0 + Double(samples[$1] * samples[$1]) }
                precondition(sqrt(power / Double(buffer.frameLength)) > 0.05, "Exported audio is silent")
            }
            precondition((try? Data(contentsOf: source)) == original, "Original recording changed")
            precondition(job.progress == 1)
            print("PASS: AAC \(Int(rate)) Hz / \(channels) ch; playable, duration retained, smaller, original unchanged.")
        }

        let source = root.appendingPathComponent("source-48000-2.caf")
        let original = try Data(contentsOf: source)
        let copied = root.appendingPathComponent("copied.caf")
        try await AudioExportJob(source: source, destination: copied, format: .original).run()
        precondition((try? Data(contentsOf: copied)) == original, "Original export changed bytes")
        try Data("previous destination".utf8).write(to: copied)
        try await AudioExportJob(source: source, destination: copied, format: .original).run()
        precondition((try? Data(contentsOf: copied)) == original, "Replacement failed")

        let protected = root.appendingPathComponent("protected.m4a")
        let sentinel = Data("existing export".utf8)
        try sentinel.write(to: protected)
        let cancelled = AudioExportJob(source: source, destination: protected, format: .aac)
        cancelled.cancel()
        do { try await cancelled.run(); preconditionFailure("Cancelled export succeeded") }
        catch is CancellationError {}
        precondition((try? Data(contentsOf: protected)) == sentinel)

        let invalid = root.appendingPathComponent("invalid.caf")
        try Data("invalid audio".utf8).write(to: invalid)
        do {
            try await AudioExportJob(source: invalid, destination: protected, format: .aac).run()
            preconditionFailure("Invalid audio export succeeded")
        } catch {}
        precondition((try? Data(contentsOf: protected)) == sentinel, "Failed export replaced destination")

        do {
            try await AudioExportJob(source: source, destination: source, format: .aac).run()
            preconditionFailure("Compressed export replaced its original")
        } catch {}
        precondition((try? Data(contentsOf: source)) == original)
        try await AudioExportJob(source: source, destination: protected, format: .aac).run()
        let replaced = try AVAudioFile(forReading: protected)
        precondition(replaced.length > 0, "Compressed replacement cannot be played")

        let longSource = root.appendingPathComponent("long.caf")
        try makeTone(at: longSource, rate: 48000, channels: 2, seconds: 120)
        for format in AudioExportFormat.allCases {
            try sentinel.write(to: protected)
            let active = AudioExportJob(source: longSource, destination: protected, format: format)
            let work = Task { try await active.run() }
            var started = false
            for _ in 0..<5000 {
                if try FileManager.default.contentsOfDirectory(atPath: root.path).contains(where: { $0.hasPrefix(".echo-") }) {
                    started = true
                    break
                }
                try await Task.sleep(for: .milliseconds(1))
            }
            precondition(started && active.progress < 1, "Could not observe an active export")
            active.cancel()
            do { try await work.value; preconditionFailure("Active cancellation was ignored") }
            catch is CancellationError {}
            precondition((try? Data(contentsOf: protected)) == sentinel, "Cancellation damaged destination")
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".echo-") }
        precondition(leftovers.isEmpty, "Temporary export files leaked")
        print("PASS: byte-exact original/replacement, cancellation, failure cleanup, and original protection.")
    }

    static func makeTone(at url: URL, rate: Double, channels: Int, seconds: Int) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channels))!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384)!
        let writer = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate,
            AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false
        ], commonFormat: .pcmFormatFloat32, interleaved: false)
        var offset = 0
        while offset < Int(rate) * seconds {
            let count = min(16384, Int(rate) * seconds - offset)
            buffer.frameLength = AVAudioFrameCount(count)
            for channel in 0..<channels {
                for frame in 0..<count {
                    buffer.floatChannelData![channel][frame] = Float(0.25 * sin(2 * Double.pi * Double(440 * (channel + 1)) * Double(offset + frame) / rate))
                }
            }
            try writer.write(from: buffer)
            offset += count
        }
    }
}
