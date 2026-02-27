import SwiftUI

struct SmokeFogVolumetricToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var fogParticles: [FogParticle] = []
    @State private var fogWisps: [FogWisp] = []
    @State private var lastTick = Date()
    @State private var elapsed: TimeInterval = 0

    @State private var density: Double = 0.72
    @State private var flowSpeed: Double = 0.95
    @State private var scattering: Double = 0.9

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color(red: 0.05, green: 0.07, blue: 0.13),
                    Color(red: 0.06, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Canvas(rendersAsynchronously: true) { context, size in
                drawVolumeLayers(in: &context, size: size)
                drawWisps(in: &context)
                drawParticles(in: &context)
                drawLightHaze(in: &context, size: size)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        injectPlume(at: value.location, energy: 0.85)
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        injectPlume(at: value.location, energy: 1.35)
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
        .onChange(of: density) { _, _ in
            syncPopulation()
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(SmokeHudButtonStyle())

                Spacer()

                Text("VOLUMETRIC SMOKE / FOG")
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
                SmokeControlRow(
                    title: "밀도",
                    valueText: String(format: "%.2f", density),
                    value: $density,
                    range: 0.25...1.45
                )
                SmokeControlRow(
                    title: "흐름",
                    valueText: String(format: "%.2fx", flowSpeed),
                    value: $flowSpeed,
                    range: 0.2...2.3
                )
                SmokeControlRow(
                    title: "산란광",
                    valueText: String(format: "%.2fx", scattering),
                    value: $scattering,
                    range: 0.2...2.2
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
        syncPopulation()
    }

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        elapsed += delta
        syncPopulation()

        let dt = CGFloat(delta)
        let windX = CGFloat(sin(elapsed * 0.31) * 22 * flowSpeed)
        let windY = CGFloat(cos(elapsed * 0.22) * 6 * flowSpeed)

        var nextParticles = fogParticles
        for i in nextParticles.indices {
            var p = nextParticles[i]
            p.age += dt

            let noiseX = CGFloat(sin((elapsed * 1.9) + Double(p.seed) * 0.13)) * 11
            let noiseY = CGFloat(cos((elapsed * 1.5) + Double(p.seed) * 0.09)) * 8

            p.velocity.dx += (noiseX * dt)
            p.velocity.dy += (noiseY * dt)
            p.velocity.dx *= pow(0.985, dt * 60)
            p.velocity.dy *= pow(0.985, dt * 60)

            p.position.x += (p.velocity.dx + windX) * dt
            p.position.y += (p.velocity.dy + windY - 18) * dt
            p.radius += dt * 4.5

            let out = p.position.x < -220 || p.position.x > sceneSize.width + 220 || p.position.y < -260 || p.position.y > sceneSize.height + 120
            if p.age >= p.life || out {
                p = makeParticle(spawnBottom: true)
            }
            nextParticles[i] = p
        }

        var nextWisps = fogWisps
        for i in nextWisps.indices {
            var w = nextWisps[i]
            w.age += dt

            let curve = CGFloat(sin((elapsed * 0.9) + Double(w.seed) * 0.22)) * 14
            w.position.x += (w.velocity.dx + curve + windX * 0.4) * dt
            w.position.y += (w.velocity.dy + windY * 0.2 - 9) * dt
            w.radius += dt * 9

            if w.age >= w.life || w.position.y < -180 {
                w = makeWisp(spawnBottom: true)
            }
            nextWisps[i] = w
        }

        fogParticles = nextParticles
        fogWisps = nextWisps
    }

    private func injectPlume(at point: CGPoint, energy: CGFloat) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }

        let origin = CGPoint(
            x: min(max(point.x, 0), sceneSize.width),
            y: min(max(point.y, 0), sceneSize.height)
        )

        let addParticles = Int(8 * energy)
        for _ in 0..<addParticles {
            fogParticles.append(
                FogParticle(
                    position: CGPoint(
                        x: origin.x + CGFloat.random(in: -28...28),
                        y: origin.y + CGFloat.random(in: -24...24)
                    ),
                    velocity: CGVector(
                        dx: CGFloat.random(in: -90...90),
                        dy: CGFloat.random(in: -130...90)
                    ),
                    radius: CGFloat.random(in: 16...34),
                    age: 0,
                    life: CGFloat.random(in: 1.3...2.8),
                    opacity: CGFloat.random(in: 0.1...0.24),
                    seed: Int.random(in: 0...10_000)
                )
            )
        }

        fogWisps.append(
            FogWisp(
                position: origin,
                velocity: CGVector(dx: CGFloat.random(in: -20...20), dy: CGFloat.random(in: -50 ... -10)),
                radius: CGFloat.random(in: 55...120),
                age: 0,
                life: CGFloat.random(in: 1.2...2.4),
                opacity: CGFloat.random(in: 0.08...0.16),
                seed: Int.random(in: 0...10_000)
            )
        )

        if fogParticles.count > 1200 {
            fogParticles = Array(fogParticles.suffix(1200))
        }
        if fogWisps.count > 220 {
            fogWisps = Array(fogWisps.suffix(220))
        }
    }

    private func drawVolumeLayers(in context: inout GraphicsContext, size: CGSize) {
        let bands = 16
        let stepX: CGFloat = 18

        for i in 0..<bands {
            let depth = CGFloat(i) / CGFloat(max(1, bands - 1))
            let baseY = size.height * (0.08 + depth * 0.84)
            var path = Path()
            var x: CGFloat = -20
            var first = true

            while x <= size.width + 20 {
                let waveA = sin((Double(x) * 0.008) + (elapsed * (0.45 + Double(depth) * 1.2)))
                let waveB = cos((Double(x) * 0.014) - (elapsed * (0.33 + Double(depth) * 0.9)))
                let y = baseY + CGFloat((waveA * 7) + (waveB * 4)) * (0.4 + depth)

                if first {
                    path.move(to: CGPoint(x: x, y: y))
                    first = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                x += stepX
            }

            let hue = (0.56 + (0.08 * Double(depth))).truncatingRemainder(dividingBy: 1)
            let alpha = (0.03 + 0.08 * (1 - depth)) * density
            context.stroke(
                path,
                with: .color(Color(hue: hue, saturation: 0.28, brightness: 0.92).opacity(alpha)),
                lineWidth: 3.6
            )
        }
    }

    private func drawWisps(in context: inout GraphicsContext) {
        context.blendMode = .screen
        for w in fogWisps {
            let lifeProgress = min(1, w.age / max(0.001, w.life))
            let fade = max(0, 1 - lifeProgress)

            let rect = CGRect(x: w.position.x - w.radius, y: w.position.y - w.radius, width: w.radius * 2, height: w.radius * 2)
            let color = Color(hue: 0.57, saturation: 0.24, brightness: 0.96)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(Double(w.opacity * fade * CGFloat(scattering) * 0.9))))
        }
        context.blendMode = .normal
    }

    private func drawParticles(in context: inout GraphicsContext) {
        context.blendMode = .screen
        for p in fogParticles {
            let lifeProgress = min(1, p.age / max(0.001, p.life))
            let fade = max(0, 1 - lifeProgress)

            let rect = CGRect(x: p.position.x - p.radius, y: p.position.y - p.radius, width: p.radius * 2, height: p.radius * 2)
            let color = Color(hue: 0.56, saturation: 0.22, brightness: 0.94)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(Double(p.opacity * fade * CGFloat(scattering)))))
        }
        context.blendMode = .normal
    }

    private func drawLightHaze(in context: inout GraphicsContext, size: CGSize) {
        let lightCenter = CGPoint(
            x: size.width * (0.2 + CGFloat(sin(elapsed * 0.19) * 0.06)),
            y: size.height * 0.2
        )
        let radius: CGFloat = size.width * 0.35

        let rect = CGRect(x: lightCenter.x - radius, y: lightCenter.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .color(Color(red: 0.75, green: 0.86, blue: 1.0).opacity(0.07 * scattering))
        )
    }

    private func syncPopulation() {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }

        let particleTarget = Int((180 + density * 460).rounded())
        let wispTarget = Int((18 + density * 52).rounded())

        if fogParticles.count < particleTarget {
            let need = particleTarget - fogParticles.count
            fogParticles.append(contentsOf: (0..<need).map { _ in makeParticle(spawnBottom: false) })
        } else if fogParticles.count > particleTarget {
            fogParticles.removeLast(fogParticles.count - particleTarget)
        }

        if fogWisps.count < wispTarget {
            let need = wispTarget - fogWisps.count
            fogWisps.append(contentsOf: (0..<need).map { _ in makeWisp(spawnBottom: false) })
        } else if fogWisps.count > wispTarget {
            fogWisps.removeLast(fogWisps.count - wispTarget)
        }
    }

    private func makeParticle(spawnBottom: Bool) -> FogParticle {
        let y: CGFloat
        if spawnBottom {
            y = CGFloat.random(in: sceneSize.height * 0.72 ... sceneSize.height + 40)
        } else {
            y = CGFloat.random(in: -40 ... sceneSize.height + 30)
        }

        return FogParticle(
            position: CGPoint(x: CGFloat.random(in: -50 ... sceneSize.width + 50), y: y),
            velocity: CGVector(dx: CGFloat.random(in: -28...28), dy: CGFloat.random(in: -16...22)),
            radius: CGFloat.random(in: 14...34),
            age: CGFloat.random(in: 0...1.8),
            life: CGFloat.random(in: 2.0...5.6),
            opacity: CGFloat.random(in: 0.06...0.2),
            seed: Int.random(in: 0...10_000)
        )
    }

    private func makeWisp(spawnBottom: Bool) -> FogWisp {
        let y: CGFloat
        if spawnBottom {
            y = CGFloat.random(in: sceneSize.height * 0.74 ... sceneSize.height + 80)
        } else {
            y = CGFloat.random(in: -100 ... sceneSize.height + 80)
        }

        return FogWisp(
            position: CGPoint(x: CGFloat.random(in: -100 ... sceneSize.width + 100), y: y),
            velocity: CGVector(dx: CGFloat.random(in: -12...12), dy: CGFloat.random(in: -20...10)),
            radius: CGFloat.random(in: 56...140),
            age: CGFloat.random(in: 0...1.8),
            life: CGFloat.random(in: 3.5...7.8),
            opacity: CGFloat.random(in: 0.04...0.13),
            seed: Int.random(in: 0...10_000)
        )
    }
}

private struct FogParticle {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var age: CGFloat
    var life: CGFloat
    var opacity: CGFloat
    var seed: Int
}

private struct FogWisp {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var age: CGFloat
    var life: CGFloat
    var opacity: CGFloat
    var seed: Int
}

private struct SmokeHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.2, green: 0.23, blue: 0.38)
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

private struct SmokeControlRow: View {
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
                .tint(Color(red: 0.8, green: 0.84, blue: 1.0))
        }
    }
}

struct SmokeFogVolumetricToyView_Previews: PreviewProvider {
    static var previews: some View {
        SmokeFogVolumetricToyView(onBackToMainMenu: {})
    }
}
