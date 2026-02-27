import AVFoundation
import SwiftUI

struct AudioVisualizerToyView: View {
    let onBackToMainMenu: () -> Void

    @StateObject private var soundEngine = AudioVisualizerSoundEngine()
    @State private var viewSize: CGSize = .zero
    @State private var inputX: CGFloat = 0.5
    @State private var userEnergy: CGFloat = 0.35
    @State private var reactivity: Double = 1.0
    @State private var soundLevel: Double = 0.72
    @State private var lastTick = Date()

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.13),
                    Color(red: 0.03, green: 0.09, blue: 0.22),
                    Color(red: 0.01, green: 0.03, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    drawVisualizer(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }

            hud
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    inputX = max(0, min(1, value.location.x / max(1, viewSize.width)))
                    userEnergy = min(1.35, userEnergy + 0.06)
                }
        )
        .onTapGesture {
            userEnergy = min(1.4, userEnergy + 0.2)
        }
        .onAppear {
            lastTick = Date()
            soundEngine.start()
            soundEngine.update(energy: userEnergy, inputX: inputX, reactivity: reactivity, level: soundLevel)
        }
        .onDisappear {
            soundEngine.stop()
        }
        .onReceive(frameTimer) { now in
            let delta = min(1.0 / 24.0, now.timeIntervalSince(lastTick))
            lastTick = now
            let decay = CGFloat(delta) * CGFloat(0.42 / max(0.35, reactivity))
            userEnergy = max(0.28, userEnergy - decay)
            soundEngine.update(energy: userEnergy, inputX: inputX, reactivity: reactivity, level: soundLevel)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        viewSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        viewSize = newSize
                    }
            }
        )
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(AudioHudButtonStyle())

                Spacer()

                Text("AUDIO VISUALIZER")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.35), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                HStack {
                    Text("반응도")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Spacer()
                    Text(String(format: "%.2fx", reactivity))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.7, green: 0.9, blue: 1.0))
                }

                Slider(value: $reactivity, in: 0.55...2.4)
                    .tint(Color(red: 0.5, green: 0.85, blue: 1.0))

                HStack {
                    Text("사운드")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Spacer()
                    Text(String(format: "%.2f", soundLevel))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.95, green: 0.79, blue: 0.72))
                }

                Slider(value: $soundLevel, in: 0...1.2)
                    .tint(Color(red: 0.95, green: 0.46, blue: 0.4))
            }
            .padding(14)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func drawVisualizer(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let centerY = size.height * 0.52
        let barCount = 72
        let barSpace = size.width / CGFloat(barCount)
        let baseAmp: CGFloat = 26 * CGFloat(reactivity)
        let energy = userEnergy * CGFloat(reactivity)

        for i in 0..<barCount {
            let x = CGFloat(i) * barSpace
            let n = CGFloat(i) / CGFloat(max(1, barCount - 1))

            let wave1 = sin((time * 4.5) + (Double(i) * 0.24))
            let wave2 = sin((time * 7.1) + (Double(i) * 0.09) + Double(inputX) * 5.2)
            let wave3 = cos((time * 2.8) + (Double(i) * 0.37))
            let normalized = max(0.02, CGFloat((wave1 * 0.45) + (wave2 * 0.35) + (wave3 * 0.2) + 1.0) * 0.5)
            let height = (baseAmp + (normalized * 210 * energy))

            let hue = 0.53 + (0.1 * sin(Double(n) * 8.0 + time * 1.8))
            let color = Color(hue: hue, saturation: 0.72, brightness: 0.95)

            let topRect = CGRect(x: x + 1, y: centerY - height, width: barSpace * 0.74, height: height)
            let bottomRect = CGRect(x: x + 1, y: centerY, width: barSpace * 0.74, height: height * 0.88)

            context.fill(Path(roundedRect: topRect, cornerRadius: 2), with: .color(color.opacity(0.78)))
            context.fill(Path(roundedRect: bottomRect, cornerRadius: 2), with: .color(color.opacity(0.52)))

            if i.isMultiple(of: 6) {
                let glowRect = CGRect(x: x - 2, y: centerY - height - 3, width: barSpace + 4, height: 6)
                context.fill(Path(roundedRect: glowRect, cornerRadius: 2), with: .color(Color.white.opacity(0.2)))
            }
        }

        let pulseRadius = CGFloat(56 + (energy * 90) + CGFloat(sin(time * 3.7) * 10))
        let pulseRect = CGRect(
            x: (size.width * inputX) - pulseRadius,
            y: centerY - pulseRadius,
            width: pulseRadius * 2,
            height: pulseRadius * 2
        )

        context.stroke(
            Path(ellipseIn: pulseRect),
            with: .color(Color(red: 0.62, green: 0.9, blue: 1.0).opacity(0.35)),
            lineWidth: 2
        )

        let centerLine = CGRect(x: 0, y: centerY - 1, width: size.width, height: 2)
        context.fill(Path(centerLine), with: .color(Color.white.opacity(0.18)))
    }
}

private struct AudioHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.12, green: 0.2, blue: 0.4)
                    .opacity(configuration.isPressed ? 0.8 : 0.58),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AudioVisualizerToyView_Previews: PreviewProvider {
    static var previews: some View {
        AudioVisualizerToyView(onBackToMainMenu: {})
    }
}

private final class AudioVisualizerSoundEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let lock = NSLock()
    private var control = SynthControl()

    private var sampleRate: Double = 44_100
    private var phaseA: Double = 0
    private var phaseB: Double = 0
    private var currentAmp: Double = 0
    private var currentFreqA: Double = 180
    private var currentFreqB: Double = 360
    private var beatEnergy: Double = 0
    private var noiseState: UInt64 = 0x9E3779B97F4A7C15
    private var lastEnergy: Double = 0.3
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let control = self.consumeControl()
            let frames = Int(frameCount)
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let channelCount = max(1, Int(outputFormat.channelCount))
            let smoothing = 0.0016
            let ampScale = min(0.24, max(0.0, control.level * 0.22))
            let targetAmp = control.energy * ampScale
            let targetFreqA = 90 + (control.x * 420) + (control.reactivity * 35)
            let targetFreqB = targetFreqA * 1.97

            if control.beat > 0 {
                self.beatEnergy = max(self.beatEnergy, min(1.0, control.beat))
            }

            for frame in 0..<frames {
                self.currentAmp += (targetAmp - self.currentAmp) * smoothing
                self.currentFreqA += (targetFreqA - self.currentFreqA) * (smoothing * 0.85)
                self.currentFreqB += (targetFreqB - self.currentFreqB) * (smoothing * 0.78)

                self.phaseA += 2 * .pi * self.currentFreqA / self.sampleRate
                self.phaseB += 2 * .pi * self.currentFreqB / self.sampleRate
                if self.phaseA > .pi * 2 { self.phaseA -= .pi * 2 }
                if self.phaseB > .pi * 2 { self.phaseB -= .pi * 2 }

                self.noiseState = self.noiseState &* 2862933555777941757 &+ 3037000493
                let noise = (Double(self.noiseState & 0xFFFF) / 65535.0) * 2.0 - 1.0
                self.beatEnergy *= 0.9992

                let tone = (sin(self.phaseA) * 0.72) + (sin(self.phaseB) * 0.28)
                let click = noise * self.beatEnergy * 0.2
                let sampleValue = max(-0.95, min(0.95, tone * self.currentAmp + click))
                let floatSample = Float(sampleValue)

                for ch in 0..<channelCount {
                    let ptr = buffers[ch].mData?.assumingMemoryBound(to: Float.self)
                    ptr?[frame] = floatSample
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: outputFormat)
        engine.mainMixerNode.outputVolume = 0.86

        do {
            try engine.start()
        } catch {
            started = false
        }
    }

    func stop() {
        guard started else { return }
        started = false
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
    }

    func update(energy: CGFloat, inputX: CGFloat, reactivity: Double, level: Double) {
        let e = max(0.0, min(1.4, Double(energy)))
        let x = max(0.0, min(1.0, Double(inputX)))
        let r = max(0.55, min(2.4, reactivity))
        let l = max(0.0, min(1.2, level))
        let delta = max(0, e - lastEnergy)
        lastEnergy = e

        lock.lock()
        control.energy = e
        control.x = x
        control.reactivity = r
        control.level = l
        control.beat = max(control.beat, delta * 2.8)
        lock.unlock()
    }

    private func consumeControl() -> SynthControl {
        lock.lock()
        var snapshot = control
        control.beat = 0
        lock.unlock()
        snapshot.energy = max(0.18, snapshot.energy)
        return snapshot
    }

    private struct SynthControl {
        var energy: Double = 0.3
        var x: Double = 0.5
        var reactivity: Double = 1.0
        var level: Double = 0.72
        var beat: Double = 0
    }
}
