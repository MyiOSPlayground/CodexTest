import SwiftUI

struct FireworksToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var rockets: [FireworkRocket] = []
    @State private var sparks: [FireworkSpark] = []
    @State private var flashes: [FireworkFlash] = []
    @State private var lastTick = Date()

    @State private var launchRate: Double = 0.9
    @State private var burstScale: Double = 1.0
    @State private var sparklePower: Double = 1.0

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.06, green: 0.03, blue: 0.14),
                    Color(red: 0.12, green: 0.05, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            starField

            Canvas { context, _ in
                drawFlashes(in: &context)
                drawRockets(in: &context)
                drawSparks(in: &context)
            }

            hud
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    spawnBurst(at: value.location, strong: true)
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

    private var starField: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let starCount = 90
                for i in 0..<starCount {
                    let seed = Double(i) * 8.13
                    let x = CGFloat(abs(sin(seed * 0.73))) * size.width
                    let y = CGFloat(abs(cos(seed * 1.11))) * size.height * 0.7
                    let twinkle = 0.2 + (0.8 * abs(sin(t * 0.9 + seed)))
                    let r = CGFloat(0.5 + (twinkle * 1.1))
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.22 + (0.48 * twinkle))))
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
                .buttonStyle(FireworksHudButtonStyle())

                Spacer()

                Text("FIREWORKS SIM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.36), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                FireworksControlRow(
                    title: "발사 빈도",
                    valueText: String(format: "%.2fx", launchRate),
                    value: $launchRate,
                    range: 0.1...2.4
                )
                FireworksControlRow(
                    title: "폭발 규모",
                    valueText: String(format: "%.2fx", burstScale),
                    value: $burstScale,
                    range: 0.5...2.3
                )
                FireworksControlRow(
                    title: "반짝임",
                    valueText: String(format: "%.2fx", sparklePower),
                    value: $sparklePower,
                    range: 0.3...2.5
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

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }

        var nextRockets = rockets
        var nextSparks = sparks
        var nextFlashes = flashes

        for i in nextRockets.indices {
            nextRockets[i].age += CGFloat(delta)
            nextRockets[i].previous = nextRockets[i].position
            nextRockets[i].velocity.dy += CGFloat(240 * delta)
            nextRockets[i].position.x += nextRockets[i].velocity.dx * CGFloat(delta)
            nextRockets[i].position.y += nextRockets[i].velocity.dy * CGFloat(delta)
        }

        var survivors: [FireworkRocket] = []
        survivors.reserveCapacity(nextRockets.count)
        for rocket in nextRockets {
            if rocket.age >= rocket.fuse || rocket.velocity.dy >= -35 {
                let count = Int(CGFloat.random(in: 48...120) * CGFloat(burstScale))
                explode(rocket: rocket, sparkCount: count, sparks: &nextSparks, flashes: &nextFlashes)
            } else if rocket.position.y > -40 {
                survivors.append(rocket)
            }
        }
        nextRockets = survivors

        for i in nextSparks.indices {
            nextSparks[i].age += CGFloat(delta)
            nextSparks[i].previous = nextSparks[i].position
            nextSparks[i].velocity.dy += CGFloat(260 * delta)
            nextSparks[i].velocity.dx *= pow(0.988, CGFloat(delta * 60))
            nextSparks[i].velocity.dy *= pow(0.988, CGFloat(delta * 60))
            nextSparks[i].position.x += nextSparks[i].velocity.dx * CGFloat(delta)
            nextSparks[i].position.y += nextSparks[i].velocity.dy * CGFloat(delta)
        }
        nextSparks.removeAll {
            $0.age >= $0.life || $0.position.y > sceneSize.height + 80 || $0.position.x < -80 || $0.position.x > sceneSize.width + 80
        }

        for i in nextFlashes.indices {
            nextFlashes[i].age += CGFloat(delta)
            nextFlashes[i].radius += CGFloat(260 * delta)
        }
        nextFlashes.removeAll { $0.age >= $0.life }

        let autoChance = delta * (0.5 + launchRate * 2.1)
        if Double.random(in: 0...1) < autoChance {
            spawnRocket(x: CGFloat.random(in: sceneSize.width * 0.12 ... sceneSize.width * 0.88), rockets: &nextRockets)
        }

        if nextSparks.count > 2200 {
            nextSparks = Array(nextSparks.suffix(2200))
        }

        rockets = nextRockets
        sparks = nextSparks
        flashes = nextFlashes
    }

    private func spawnRocket(x: CGFloat, rockets: inout [FireworkRocket]) {
        let start = CGPoint(x: x, y: sceneSize.height + 24)
        let velocity = CGVector(dx: CGFloat.random(in: -42...42), dy: CGFloat.random(in: -680 ... -470))

        rockets.append(
            FireworkRocket(
                position: start,
                previous: start,
                velocity: velocity,
                hue: Double.random(in: 0...1),
                age: 0,
                fuse: CGFloat.random(in: 0.85...1.45)
            )
        )
    }

    private func spawnBurst(at point: CGPoint, strong: Bool) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }

        let clamped = CGPoint(
            x: min(max(point.x, 0), sceneSize.width),
            y: min(max(point.y, 0), sceneSize.height)
        )

        let sourceRocket = FireworkRocket(
            position: clamped,
            previous: clamped,
            velocity: .zero,
            hue: Double.random(in: 0...1),
            age: 0,
            fuse: 0
        )

        var nextSparks = sparks
        var nextFlashes = flashes
        let count = Int((strong ? 150 : 90) * burstScale)
        explode(rocket: sourceRocket, sparkCount: count, sparks: &nextSparks, flashes: &nextFlashes)
        sparks = nextSparks
        flashes = nextFlashes
    }

    private func explode(
        rocket: FireworkRocket,
        sparkCount: Int,
        sparks: inout [FireworkSpark],
        flashes: inout [FireworkFlash]
    ) {
        flashes.append(
            FireworkFlash(
                center: rocket.position,
                radius: CGFloat.random(in: 22...42),
                age: 0,
                life: CGFloat.random(in: 0.16...0.32),
                hue: rocket.hue
            )
        )

        let baseLife = CGFloat.random(in: 1.0...2.2)
        let sparkle = CGFloat(max(0.2, sparklePower))

        for i in 0..<max(12, sparkCount) {
            let t = CGFloat(i) / CGFloat(max(1, sparkCount - 1))
            let angle = (t * .pi * 2) + CGFloat.random(in: -0.2...0.2)
            let speed = CGFloat.random(in: 110...460) * CGFloat(burstScale)
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            let radius = CGFloat.random(in: 1.1...2.8) * (0.8 + 0.6 * sparkle)

            sparks.append(
                FireworkSpark(
                    position: rocket.position,
                    previous: rocket.position,
                    velocity: velocity,
                    hue: (rocket.hue + Double.random(in: -0.08...0.08)).truncatingRemainder(dividingBy: 1),
                    age: 0,
                    life: baseLife * CGFloat.random(in: 0.65...1.2),
                    radius: radius
                )
            )
        }
    }

    private func drawFlashes(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter
        for flash in flashes {
            let progress = min(1, flash.age / max(0.001, flash.life))
            let alpha = max(0, 1 - progress)

            let rect = CGRect(
                x: flash.center.x - flash.radius,
                y: flash.center.y - flash.radius,
                width: flash.radius * 2,
                height: flash.radius * 2
            )
            let color = Color(hue: flash.hue, saturation: 0.5, brightness: 1)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(Double(alpha) * 0.45)))
        }
        context.blendMode = .normal
    }

    private func drawRockets(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter

        for rocket in rockets {
            var trail = Path()
            trail.move(to: rocket.previous)
            trail.addLine(to: rocket.position)

            let color = Color(hue: rocket.hue, saturation: 0.52, brightness: 1)
            context.stroke(trail, with: .color(color.opacity(0.8)), lineWidth: 2.1)

            let r: CGFloat = 2.8
            let rect = CGRect(x: rocket.position.x - r, y: rocket.position.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.96)))
        }

        context.blendMode = .normal
    }

    private func drawSparks(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter

        for spark in sparks {
            let progress = min(1, spark.age / max(0.001, spark.life))
            let alpha = max(0, 1 - progress)

            let hue = spark.hue < 0 ? spark.hue + 1 : spark.hue
            let color = Color(hue: hue, saturation: 0.7, brightness: 1)

            var trail = Path()
            trail.move(to: spark.previous)
            trail.addLine(to: spark.position)
            context.stroke(trail, with: .color(color.opacity(Double(alpha) * 0.66)), lineWidth: max(0.7, spark.radius * 0.7))

            let r = spark.radius
            let rect = CGRect(x: spark.position.x - r, y: spark.position.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(Double(alpha) * 0.58)))
        }

        context.blendMode = .normal
    }
}

private struct FireworkRocket {
    var position: CGPoint
    var previous: CGPoint
    var velocity: CGVector
    var hue: Double
    var age: CGFloat
    var fuse: CGFloat
}

private struct FireworkSpark {
    var position: CGPoint
    var previous: CGPoint
    var velocity: CGVector
    var hue: Double
    var age: CGFloat
    var life: CGFloat
    var radius: CGFloat
}

private struct FireworkFlash {
    var center: CGPoint
    var radius: CGFloat
    var age: CGFloat
    var life: CGFloat
    var hue: Double
}

private struct FireworksHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.24, green: 0.18, blue: 0.44)
                    .opacity(configuration.isPressed ? 0.84 : 0.62),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct FireworksControlRow: View {
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
                    .foregroundStyle(Color(red: 0.86, green: 0.9, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.78, green: 0.75, blue: 1.0))
        }
    }
}

struct FireworksToyView_Previews: PreviewProvider {
    static var previews: some View {
        FireworksToyView(onBackToMainMenu: {})
    }
}
