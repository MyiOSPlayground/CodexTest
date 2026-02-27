import SwiftUI

struct AuroraSkyToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var ribbons: [AuroraRibbon] = []
    @State private var flares: [AuroraFlare] = []
    @State private var elapsed: TimeInterval = 0
    @State private var lastTick = Date()

    @State private var intensity: Double = 0.95
    @State private var flowSpeed: Double = 1.0
    @State private var colorShift: Double = 0.8

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            skyBackground
                .ignoresSafeArea()

            Canvas(rendersAsynchronously: true) { context, size in
                drawStars(in: &context, size: size)
                drawMoonGlow(in: &context, size: size)
                drawAuroraRibbons(in: &context, size: size)
                drawFlares(in: &context)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        spawnFlare(at: value.location, boost: true)
                    }
            )

            hud
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        resizeScene(to: geometry.size)
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        resizeScene(to: newSize)
                    }
            }
        )
        .onAppear {
            lastTick = Date()
        }
        .onReceive(frameTimer) { now in
            let delta = min(1.0 / 24.0, now.timeIntervalSince(lastTick))
            lastTick = now
            step(delta: delta)
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var skyBackground: some View {
        let t = elapsed * 0.07
        let hueA = (0.61 + sin(t * 0.7) * 0.02 + colorShift * 0.02).truncatingRemainder(dividingBy: 1)
        let hueB = (0.54 + cos(t * 0.5) * 0.02 + colorShift * 0.03).truncatingRemainder(dividingBy: 1)
        let hueC = (0.66 + sin(t * 0.9) * 0.015).truncatingRemainder(dividingBy: 1)

        return LinearGradient(
            colors: [
                Color(hue: hueA, saturation: 0.62, brightness: 0.14),
                Color(hue: hueB, saturation: 0.55, brightness: 0.08),
                Color(hue: hueC, saturation: 0.45, brightness: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(AuroraHudButtonStyle())

                Spacer()

                Text("AURORA SKY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.35), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                AuroraControlRow(
                    title: "강도",
                    valueText: String(format: "%.2fx", intensity),
                    value: $intensity,
                    range: 0.35...2.4
                )
                AuroraControlRow(
                    title: "흐름",
                    valueText: String(format: "%.2fx", flowSpeed),
                    value: $flowSpeed,
                    range: 0.25...2.6
                )
                AuroraControlRow(
                    title: "컬러 시프트",
                    valueText: String(format: "%.2fx", colorShift),
                    value: $colorShift,
                    range: 0.2...2.0
                )
            }
            .padding(14)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func resizeScene(to newSize: CGSize) {
        guard newSize.width > 0 && newSize.height > 0 else { return }
        sceneSize = newSize
        if ribbons.isEmpty {
            ribbons = makeRibbons(count: 6)
        }
    }

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        elapsed += delta

        var nextFlares = flares
        for i in nextFlares.indices {
            nextFlares[i].age += CGFloat(delta)
            nextFlares[i].radius += CGFloat(70 * delta)
        }
        nextFlares.removeAll { $0.age >= $0.life }

        let autoChance = delta * 0.35 * flowSpeed
        if Double.random(in: 0...1) < autoChance {
            let x = CGFloat.random(in: sceneSize.width * 0.1 ... sceneSize.width * 0.9)
            let y = CGFloat.random(in: sceneSize.height * 0.08 ... sceneSize.height * 0.38)
            spawnFlare(at: CGPoint(x: x, y: y), boost: false, container: &nextFlares)
        }

        flares = nextFlares
    }

    private func makeRibbons(count: Int) -> [AuroraRibbon] {
        (0..<count).map { i in
            AuroraRibbon(
                baseY: CGFloat(0.12 + Double(i) * 0.055 + Double.random(in: -0.015...0.015)),
                amplitude: CGFloat.random(in: 18...42),
                frequency: Double.random(in: 0.006...0.014),
                speed: Double.random(in: 0.4...1.15),
                phase: Double.random(in: 0...(Double.pi * 2)),
                thickness: CGFloat.random(in: 10...26),
                hue: Double.random(in: 0.34...0.53)
            )
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize) {
        let count = 170
        for i in 0..<count {
            let seed = Double(i) * 7.37
            let x = CGFloat(abs(sin(seed * 0.47))) * size.width
            let y = CGFloat(abs(cos(seed * 1.21))) * size.height * 0.84
            let twinkle = 0.24 + 0.76 * abs(sin(elapsed * 0.8 + seed * 0.19))
            let radius = CGFloat(0.4 + twinkle * 1.25)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.14 + twinkle * 0.48))
            )
        }
    }

    private func drawMoonGlow(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.8, y: size.height * 0.15)
        let outer = CGRect(
            x: center.x - size.width * 0.16,
            y: center.y - size.width * 0.16,
            width: size.width * 0.32,
            height: size.width * 0.32
        )
        context.fill(
            Path(ellipseIn: outer),
            with: .color(Color(red: 0.86, green: 0.93, blue: 1.0).opacity(0.08))
        )

        let moonRect = CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)
        context.fill(
            Path(ellipseIn: moonRect),
            with: .color(Color(red: 0.93, green: 0.97, blue: 1.0).opacity(0.82))
        )
    }

    private func drawAuroraRibbons(in context: inout GraphicsContext, size: CGSize) {
        context.blendMode = .screen
        for ribbon in ribbons {
            let baseY = size.height * ribbon.baseY
            var path = Path()
            let stepX: CGFloat = 12
            var x: CGFloat = -20
            var first = true
            while x <= size.width + 20 {
                let waveA = sin(Double(x) * ribbon.frequency + elapsed * ribbon.speed * flowSpeed + ribbon.phase)
                let waveB = cos(Double(x) * (ribbon.frequency * 0.63) - elapsed * ribbon.speed * 0.6 + ribbon.phase * 1.7)
                let y = baseY + CGFloat((waveA * Double(ribbon.amplitude)) + (waveB * Double(ribbon.amplitude) * 0.55))
                if first {
                    path.move(to: CGPoint(x: x, y: y))
                    first = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                x += stepX
            }

            let hue = (ribbon.hue + colorShift * 0.08).truncatingRemainder(dividingBy: 1)
            let color = Color(hue: hue, saturation: 0.72, brightness: 0.98)
            let alpha = 0.08 + intensity * 0.2

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 18))
                layer.stroke(path, with: .color(color.opacity(alpha * 0.42)), lineWidth: ribbon.thickness * 2.2)
            }

            context.stroke(path, with: .color(color.opacity(alpha * 0.85)), lineWidth: ribbon.thickness)
            context.stroke(path, with: .color(Color.white.opacity(alpha * 0.35)), lineWidth: ribbon.thickness * 0.28)
        }
        context.blendMode = .normal
    }

    private func drawFlares(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter
        for flare in flares {
            let progress = min(1, flare.age / max(0.001, flare.life))
            let fade = max(0, 1 - progress)
            let rect = CGRect(
                x: flare.center.x - flare.radius,
                y: flare.center.y - flare.radius,
                width: flare.radius * 2,
                height: flare.radius * 2
            )
            let color = Color(hue: flare.hue, saturation: 0.74, brightness: 1.0)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(Double(0.28 * fade * intensity))))
        }
        context.blendMode = .normal
    }

    private func spawnFlare(at point: CGPoint, boost: Bool, container: inout [AuroraFlare]) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        let clamped = CGPoint(
            x: min(max(point.x, 0), sceneSize.width),
            y: min(max(point.y, 0), sceneSize.height)
        )

        container.append(
            AuroraFlare(
                center: clamped,
                radius: CGFloat.random(in: boost ? 36...62 : 24...46),
                age: 0,
                life: CGFloat.random(in: boost ? 0.7...1.4 : 0.6...1.1),
                hue: Double.random(in: 0.34...0.53)
            )
        )

        if container.count > 80 {
            container = Array(container.suffix(80))
        }
    }

    private func spawnFlare(at point: CGPoint, boost: Bool) {
        var next = flares
        spawnFlare(at: point, boost: boost, container: &next)
        flares = next
    }
}

private struct AuroraRibbon {
    let baseY: CGFloat
    let amplitude: CGFloat
    let frequency: Double
    let speed: Double
    let phase: Double
    let thickness: CGFloat
    let hue: Double
}

private struct AuroraFlare {
    var center: CGPoint
    var radius: CGFloat
    var age: CGFloat
    var life: CGFloat
    var hue: Double
}

private struct AuroraHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.16, green: 0.26, blue: 0.42)
                    .opacity(configuration.isPressed ? 0.85 : 0.62),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct AuroraControlRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.84, green: 0.95, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.58, green: 0.93, blue: 0.87))
        }
    }
}

struct AuroraSkyToyView_Previews: PreviewProvider {
    static var previews: some View {
        AuroraSkyToyView(onBackToMainMenu: {})
    }
}
