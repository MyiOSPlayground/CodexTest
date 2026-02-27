import SwiftUI

struct LightningGeneratorToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var bolts: [LightningBolt] = []
    @State private var lastTick = Date()

    @State private var flashRate: Double = 0.9
    @State private var branchDensity: Double = 0.55
    @State private var glowPower: Double = 0.95

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color(red: 0.05, green: 0.06, blue: 0.15),
                    Color(red: 0.08, green: 0.08, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            cloudLayer

            Canvas { context, size in
                drawLightning(in: &context)
            }

            hud
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    spawnStrike(at: value.location, strong: true)
                }
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        sceneSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        sceneSize = newSize
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

    private var cloudLayer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<5 {
                    let phase = Double(i) * 1.2
                    let x = size.width * CGFloat(0.12 + (0.2 * Double(i))) + CGFloat(sin(t * 0.25 + phase) * 30)
                    let y = size.height * CGFloat(0.12 + (0.06 * Double(i))) + CGFloat(cos(t * 0.22 + phase) * 12)
                    let w = size.width * CGFloat(0.34 + (0.03 * Double(i)))
                    let h = size.height * CGFloat(0.16 + (0.015 * Double(i)))
                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.055)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(LightningHudButtonStyle())

                Spacer()

                Text("LIGHTNING GENERATOR")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.87))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.36), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                LightningControlRow(
                    title: "번개 빈도",
                    valueText: String(format: "%.2fx", flashRate),
                    value: $flashRate,
                    range: 0.15...2.2
                )

                LightningControlRow(
                    title: "분기량",
                    valueText: String(format: "%.2f", branchDensity),
                    value: $branchDensity,
                    range: 0.0...1.0
                )

                LightningControlRow(
                    title: "글로우",
                    valueText: String(format: "%.2fx", glowPower),
                    value: $glowPower,
                    range: 0.35...2.0
                )
            }
            .padding(14)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.17), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }

        var next = bolts
        for index in next.indices {
            next[index].age += CGFloat(delta)
        }
        next.removeAll { $0.age >= $0.life }

        let spawnChance = delta * (0.9 + (flashRate * 2.6))
        if Double.random(in: 0...1) < spawnChance {
            let target = CGPoint(
                x: CGFloat.random(in: sceneSize.width * 0.12 ... sceneSize.width * 0.88),
                y: CGFloat.random(in: sceneSize.height * 0.28 ... sceneSize.height * 0.95)
            )
            next.append(makeBolt(to: target, strong: false))
        }

        if next.count > 24 {
            next = Array(next.suffix(24))
        }

        bolts = next
    }

    private func spawnStrike(at point: CGPoint, strong: Bool) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        let clamped = CGPoint(
            x: min(max(point.x, 0), sceneSize.width),
            y: min(max(point.y, 0), sceneSize.height)
        )
        bolts.append(makeBolt(to: clamped, strong: strong))
    }

    private func makeBolt(to target: CGPoint, strong: Bool) -> LightningBolt {
        let start = CGPoint(
            x: target.x + CGFloat.random(in: -140...140),
            y: -20
        )

        let mainPath = jitteredPath(
            from: start,
            to: target,
            segments: strong ? Int.random(in: 11...18) : Int.random(in: 8...14),
            jaggedness: strong ? 54 : 40
        )

        let branchCount = Int(CGFloat(mainPath.count) * CGFloat(branchDensity) * (strong ? 0.7 : 0.45))
        let branches: [[CGPoint]] = (0..<branchCount).compactMap { _ in
            guard mainPath.count > 5 else { return nil }
            let originIndex = Int.random(in: 2...(mainPath.count - 3))
            let origin = mainPath[originIndex]

            let dx = CGFloat.random(in: -120...120)
            let dy = CGFloat.random(in: 60...190)
            let endpoint = CGPoint(x: origin.x + dx, y: origin.y + dy)
            return jitteredPath(from: origin, to: endpoint, segments: Int.random(in: 4...8), jaggedness: 24)
        }

        return LightningBolt(
            mainPath: mainPath,
            branches: branches,
            age: 0,
            life: strong ? CGFloat.random(in: 0.24...0.44) : CGFloat.random(in: 0.16...0.34),
            hue: Double.random(in: 0.52...0.66)
        )
    }

    private func jitteredPath(from start: CGPoint, to end: CGPoint, segments: Int, jaggedness: CGFloat) -> [CGPoint] {
        guard segments > 0 else { return [start, end] }

        var points: [CGPoint] = []
        points.reserveCapacity(segments + 1)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, sqrt((dx * dx) + (dy * dy)))
        let nx = -dy / length
        let ny = dx / length

        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let base = CGPoint(x: start.x + (dx * t), y: start.y + (dy * t))
            let edgeFade = 1 - abs((t * 2) - 1)
            let jitter = CGFloat.random(in: -jaggedness...jaggedness) * max(0.12, edgeFade)

            let p = CGPoint(
                x: base.x + (nx * jitter),
                y: base.y + (ny * jitter)
            )
            points.append(p)
        }

        return points
    }

    private func drawLightning(in context: inout GraphicsContext) {
        for bolt in bolts {
            let lifeProgress = min(1, bolt.age / max(0.001, bolt.life))
            let alpha = max(0, 1 - lifeProgress)
            let coreColor = Color(hue: bolt.hue, saturation: 0.24, brightness: 1.0)
            let glowColor = Color(hue: bolt.hue, saturation: 0.9, brightness: 1.0)

            drawPath(
                bolt.mainPath,
                in: &context,
                core: coreColor.opacity(Double(alpha)),
                glow: glowColor.opacity(Double(alpha) * 0.45),
                width: CGFloat(2.2 + glowPower)
            )

            for branch in bolt.branches {
                drawPath(
                    branch,
                    in: &context,
                    core: coreColor.opacity(Double(alpha) * 0.68),
                    glow: glowColor.opacity(Double(alpha) * 0.3),
                    width: CGFloat(1.2 + (0.6 * glowPower))
                )
            }
        }
    }

    private func drawPath(
        _ points: [CGPoint],
        in context: inout GraphicsContext,
        core: Color,
        glow: Color,
        width: CGFloat
    ) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(path, with: .color(glow.opacity(0.18)), lineWidth: width * 4.2)
        context.stroke(path, with: .color(glow.opacity(0.3)), lineWidth: width * 2.3)
        context.stroke(path, with: .color(core), lineWidth: width)
    }
}

private struct LightningBolt {
    var mainPath: [CGPoint]
    var branches: [[CGPoint]]
    var age: CGFloat
    var life: CGFloat
    var hue: Double
}

private struct LightningHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.2, green: 0.2, blue: 0.44)
                    .opacity(configuration.isPressed ? 0.84 : 0.6),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct LightningControlRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.84, green: 0.9, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.72, green: 0.78, blue: 1.0))
        }
    }
}

struct LightningGeneratorToyView_Previews: PreviewProvider {
    static var previews: some View {
        LightningGeneratorToyView(onBackToMainMenu: {})
    }
}
