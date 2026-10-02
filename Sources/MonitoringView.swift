import SwiftUI

struct MonitoringView: View {
    @Bindable var model: Recorder
    private let accent = Color(red: 0.72, green: 0.85, blue: 0.38)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Live input spectrum", systemImage: "waveform.path")
                    .font(.headline)
                Spacer()
                Text(model.recording && model.spectrum.live ? "LIVE" : (model.recording ? "WAITING" : "IDLE"))
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(model.recording && model.spectrum.live ? accent : Color.secondary)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(SpectrumAnalyzer.frequencies.indices, id: \.self) { index in
                    VStack(spacing: 5) {
                        GeometryReader { proxy in
                            let value = model.spectrum.bandsDB[index]
                            let height = max(2, proxy.size.height * max(0, min(1, CGFloat(value + 80) / 80)))
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.045))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(model.recording && model.spectrum.live ? accent : accent.opacity(0.28))
                                    .frame(height: height)
                            }
                        }.frame(height: 84)
                        Text(SpectrumAnalyzer.labels[index]).font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Int(SpectrumAnalyzer.frequencies[index])) hertz")
                    .accessibilityValue("\(Int(model.spectrum.bandsDB[index])) decibels full scale")
                }
            }
            HStack {
                Text("Frequency in Hz")
                Spacer()
                Text("Display range −80 to 0 dBFS")
            }.font(.caption2).foregroundStyle(.secondary)
            Divider()
            ForEach(model.spectrum.peaksDB.indices, id: \.self) { channel in
                PeakMeter(label: model.spectrum.peaksDB.count == 1 ? "Mono" : (channel == 0 ? "L" : "R"),
                    peak: model.spectrum.peaksDB[channel],
                    hold: channel < model.spectrum.heldPeaksDB.count ? model.spectrum.heldPeaksDB[channel] : -100)
            }
            if model.spectrum.peaksDB.isEmpty {
                PeakMeter(label: "L", peak: -100, hold: -100)
                PeakMeter(label: "R", peak: -100, hold: -100)
            }
            HStack {
                Label(statusText, systemImage: statusSymbol)
                    .foregroundStyle(statusColor).font(.caption)
                Spacer()
                Button("Reset peaks") { model.resetPeaks() }.font(.caption)
            }
            if let issue = model.monitorIssue {
                Text(issue).font(.caption).foregroundStyle(.orange)
            }
            Text("0 dBFS is full scale. Leave headroom; lower source or interface gain if peaks approach 0. Levels cannot prove source quality or detect every kind of distortion.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
    }

    private var highestPeak: Float { model.spectrum.heldPeaksDB.max() ?? -100 }
    private var statusText: String {
        if model.spectrum.invalidSamples > 0 { return "Invalid input samples detected" }
        if model.spectrum.possibleClipping { return "Possible clipping · full-scale peaks detected" }
        if highestPeak > -1 { return "Very little headroom · peak above −1 dBFS" }
        if model.recording && model.spectrum.live { return "No full-scale peaks detected" }
        return model.recording ? "Waiting for spectrum · check the input" : "Record to see live levels and frequencies"
    }
    private var statusSymbol: String {
        if model.spectrum.possibleClipping || highestPeak > -1 { return "exclamationmark.triangle.fill" }
        return model.recording && model.spectrum.live ? "checkmark.circle" : "waveform"
    }
    private var statusColor: Color {
        if model.spectrum.possibleClipping { return .red }
        return highestPeak > -1 ? .orange : .secondary
    }
}

private struct PeakMeter: View {
    let label: String
    let peak: Float
    let hold: Float
    private var color: Color { peak >= -0.01 ? .red : (peak > -3 ? .orange : .green) }

    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.caption.monospaced().bold()).frame(width: 32, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: proxy.size.width * max(0, min(1, CGFloat(peak + 60) / 60)))
                    Rectangle().fill(Color.primary.opacity(0.7)).frame(width: 2, height: 14)
                        .offset(x: max(0, min(proxy.size.width - 2, proxy.size.width * CGFloat(hold + 60) / 60)))
                    Rectangle().fill(.orange.opacity(0.8)).frame(width: 1, height: 14)
                        .offset(x: proxy.size.width * 0.95)
                }
            }.frame(height: 14)
            Text(peak <= -99 ? "−∞" : String(format: "%.1f", peak))
                .font(.caption.monospaced()).frame(width: 44, alignment: .trailing)
            Text("dBFS").font(.caption2).foregroundStyle(.secondary)
            Text("Hold " + (hold <= -99 ? "—" : String(format: "%.1f", hold)))
                .font(.caption2.monospaced()).foregroundStyle(.secondary).frame(width: 74, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) peak meter")
        .accessibilityValue("\(peak) decibels full scale; held peak \(hold)")
    }
}
