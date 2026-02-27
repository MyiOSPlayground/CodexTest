import SwiftUI

struct InkWaveToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var ripples: [InkRipple] = []
    @State private var blobs: [InkBlob] = []
    @State private var lastTick = Date()
    @State private var viscosity: Double = 0.86
    @State private var turbulence: Double = 0.8
    @State private var hueShift: Double = 0.55

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.11),
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.03, green: 0.04, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    drawField(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                    drawBlobs(in: &context)
                    drawRings(in: &context)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        inject(at: value.location, energy: 1.0)
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        inject(at: value.location, energy: 1.5)
                    }
            )

            hud
        }
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
            updateSimulation(delta: delta)
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(InkHudButtonStyle())

                Spacer()

                Text("INK WAVE SIM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.35), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                InkControlRow(title: "점도", valueText: String(format: "%.2f", viscosity), value: $viscosity, range: 0.72...0.97)
                InkControlRow(title: "난류", valueText: String(format: "%.2f", turbulence), value: $turbulence, range: 0.3...1.8)
                InkControlRow(title: "색감", valueText: String(format: "%.2f", hueShift), value: $hueShift, range: 0.0...1.0)
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

    private func updateSimulation(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        let dt = CGFloat(delta)

        var nextRipples = ripples
        for index in nextRipples.indices {
            nextRipples[index].age += dt
            nextRipples[index].radius += nextRipples[index].speed * dt
            nextRipples[index].strength *= pow(CGFloat(viscosity), dt * 60)
        }
        nextRipples.removeAll {
            $0.strength < 0.015 || $0.radius > max(sceneSize.width, sceneSize.height) * 1.3
        }

        var nextBlobs = blobs
        for index in nextBlobs.indices {
            var blob = nextBlobs[index]
            var force = CGVector(dx: 0, dy: 0)

            for ripple in nextRipples {
                let dx = blob.position.x - ripple.center.x
                let dy = blob.position.y - ripple.center.y
                let distance = max(1, sqrt(dx * dx + dy * dy))
                let nx = dx / distance
                let ny = dy / distance

                let wave = sin((distance - ripple.radius) * 0.075) * ripple.strength
                let amp = wave * CGFloat(210 * turbulence)
                force.dx += nx * amp
                force.dy += ny * amp
            }

            force.dx += CGFloat.random(in: -28...28) * dt * CGFloat(turbulence)
            force.dy += CGFloat.random(in: -22...22) * dt * CGFloat(turbulence)

            blob.velocity.dx += force.dx * dt
            blob.velocity.dy += force.dy * dt
            blob.velocity.dx *= pow(CGFloat(viscosity), dt * 60)
            blob.velocity.dy *= pow(CGFloat(viscosity), dt * 60)

            blob.position.x += blob.velocity.dx * dt
            blob.position.y += blob.velocity.dy * dt
            blob.age += dt

            if blob.position.x < -180 || blob.position.x > sceneSize.width + 180 || blob.position.y < -180 || blob.position.y > sceneSize.height + 180 {
                blob.age = blob.life + 1
            }

            nextBlobs[index] = blob
        }
        nextBlobs.removeAll { $0.age >= $0.life }

        if nextBlobs.count < 38 && CGFloat.random(in: 0...1) < CGFloat(delta * 4.8) {
            nextBlobs.append(makeAmbientBlob())
        }
        if nextBlobs.count > 90 {
            nextBlobs = Array(nextBlobs.suffix(90))
        }

        ripples = nextRipples
        blobs = nextBlobs
    }

    private func inject(at point: CGPoint, energy: CGFloat) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }

        let clamped = CGPoint(
            x: min(max(point.x, 0), sceneSize.width),
            y: min(max(point.y, 0), sceneSize.height)
        )

        ripples.append(
            InkRipple(
                center: clamped,
                radius: CGFloat.random(in: 4...16),
                speed: CGFloat.random(in: 140...280),
                strength: CGFloat.random(in: 0.45...0.9) * energy,
                age: 0,
                thickness: CGFloat.random(in: 8...22)
            )
        )

        let blobCount = Int.random(in: 2...4)
        for _ in 0..<blobCount {
            blobs.append(
                InkBlob(
                    position: CGPoint(
                        x: clamped.x + CGFloat.random(in: -28...28),
                        y: clamped.y + CGFloat.random(in: -28...28)
                    ),
                    velocity: CGVector(
                        dx: CGFloat.random(in: -130...130) * energy,
                        dy: CGFloat.random(in: -130...130) * energy
                    ),
                    radius: CGFloat.random(in: 22...58),
                    hue: (hueShift + Double.random(in: -0.12...0.12)).truncatingRemainder(dividingBy: 1),
                    life: CGFloat.random(in: 1.3...2.9),
                    age: 0
                )
            )
        }
    }

    private func makeAmbientBlob() -> InkBlob {
        InkBlob(
            position: CGPoint(
                x: CGFloat.random(in: -80...(sceneSize.width + 80)),
                y: CGFloat.random(in: -80...(sceneSize.height + 80))
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -20...20),
                dy: CGFloat.random(in: -20...20)
            ),
            radius: CGFloat.random(in: 26...68),
            hue: (hueShift + Double.random(in: -0.09...0.09)).truncatingRemainder(dividingBy: 1),
            life: CGFloat.random(in: 2.2...4.5),
            age: CGFloat.random(in: 0...0.6)
        )
    }

    private func drawField(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let rowCount = 42
        let stepX: CGFloat = 14

        for row in 0..<rowCount {
            let yBase = (CGFloat(row) / CGFloat(max(1, rowCount - 1))) * size.height
            var path = Path()
            var x: CGFloat = 0
            var isFirst = true

            while x <= size.width + stepX {
                let point = CGPoint(x: x, y: yBase)
                let offset = waveOffset(at: point, time: time)
                let y = yBase + offset

                if isFirst {
                    path.move(to: CGPoint(x: x, y: y))
                    isFirst = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                x += stepX
            }

            let t = Double(row) / Double(max(1, rowCount - 1))
            let hue = (hueShift + 0.22 + t * 0.14).truncatingRemainder(dividingBy: 1)
            let alpha = 0.05 + (0.16 * (1 - t))
            let color = Color(hue: hue, saturation: 0.6 + 0.25 * t, brightness: 0.9)

            context.stroke(path, with: .color(color.opacity(alpha)), lineWidth: 1.0)
        }
    }

    private func waveOffset(at point: CGPoint, time: TimeInterval) -> CGFloat {
        var offset = CGFloat(sin((Double(point.x) * 0.009) + (time * 0.9)) * 2.8)

        for ripple in ripples {
            let dx = point.x - ripple.center.x
            let dy = point.y - ripple.center.y
            let d = sqrt(dx * dx + dy * dy)
            let travel = d - ripple.radius
            let attenuation = exp(-d * 0.0045)
            let wave = sin((travel * 0.08) - (ripple.age * 9.0))
            offset += wave * ripple.strength * ripple.thickness * attenuation
        }

        return offset
    }

    private func drawBlobs(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter
        for blob in blobs {
            let progress = min(1, blob.age / max(0.001, blob.life))
            let alpha = max(0, 1 - progress)

            let rect = CGRect(
                x: blob.position.x - blob.radius,
                y: blob.position.y - blob.radius,
                width: blob.radius * 2,
                height: blob.radius * 2
            )

            let color = Color(hue: blob.hue < 0 ? blob.hue + 1 : blob.hue, saturation: 0.74, brightness: 0.9)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(Double(alpha) * 0.26)))

            let core = rect.insetBy(dx: blob.radius * 0.34, dy: blob.radius * 0.34)
            context.fill(Path(ellipseIn: core), with: .color(color.opacity(Double(alpha) * 0.42)))
        }
        context.blendMode = .normal
    }

    private func drawRings(in context: inout GraphicsContext) {
        for ripple in ripples {
            let rect = CGRect(
                x: ripple.center.x - ripple.radius,
                y: ripple.center.y - ripple.radius,
                width: ripple.radius * 2,
                height: ripple.radius * 2
            )
            let hue = (hueShift + Double(ripple.age * 0.04)).truncatingRemainder(dividingBy: 1)
            let color = Color(hue: hue, saturation: 0.52, brightness: 1.0)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(color.opacity(Double(max(0, ripple.strength * 0.42)))),
                lineWidth: max(1, ripple.thickness * 0.12)
            )
        }
    }
}

private struct InkRipple {
    var center: CGPoint
    var radius: CGFloat
    var speed: CGFloat
    var strength: CGFloat
    var age: CGFloat
    var thickness: CGFloat
}

private struct InkBlob {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var hue: Double
    var life: CGFloat
    var age: CGFloat
}

private struct InkHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.15, green: 0.22, blue: 0.44)
                    .opacity(configuration.isPressed ? 0.82 : 0.58),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct InkControlRow: View {
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
                    .foregroundStyle(Color(red: 0.72, green: 0.9, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.58, green: 0.83, blue: 1.0))
        }
    }
}

struct InkWaveToyView_Previews: PreviewProvider {
    static var previews: some View {
        InkWaveToyView(onBackToMainMenu: {})
    }
}
