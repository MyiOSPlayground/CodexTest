import AppKit
import SwiftUI

struct NeonParticleGravityToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var particles: [NeonParticle] = []
    @State private var pulseWells: [GravityWell] = []
    @State private var primaryWell = CGPoint(x: 380, y: 410)
    @State private var lastTick = Date()

    @State private var particleTargetCount: Double = 260
    @State private var gravityPower: Double = 1.0
    @State private var swirlPower: Double = 0.65

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.12),
                    Color(red: 0.08, green: 0.04, blue: 0.2),
                    Color(red: 0.02, green: 0.03, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Canvas { context, size in
                drawBackgroundGrid(in: &context, size: size)
                drawWells(in: &context)
                drawParticles(in: &context)
            }

            hud
        }
        .overlay(
            GravityMouseTrackingLayer { point in
                primaryWell = clamp(point, in: sceneSize)
            }
            .allowsHitTesting(false)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    primaryWell = clamp(value.location, in: sceneSize)
                }
        )
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    spawnPulseWell(at: clamp(value.location, in: sceneSize), strength: 1.4)
                }
        )
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

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(NeonHudButtonStyle())

                Spacer()

                Text("NEON GRAVITY PLAYGROUND")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.36), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                NeonControlRow(
                    title: "파티클 수",
                    valueText: "\(desiredParticleCount)",
                    value: $particleTargetCount,
                    range: 80...540
                )
                NeonControlRow(
                    title: "중력",
                    valueText: String(format: "%.2fx", gravityPower),
                    value: $gravityPower,
                    range: 0.4...2.5
                )
                NeonControlRow(
                    title: "소용돌이",
                    valueText: String(format: "%.2fx", swirlPower),
                    value: $swirlPower,
                    range: 0.0...1.8
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

    private func resizeScene(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        sceneSize = newSize
        primaryWell = clamp(primaryWell, in: newSize)
        syncParticlePopulation()
    }

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return }
        syncParticlePopulation()

        let dt = CGFloat(delta)
        let drag: CGFloat = 0.988

        var wells = pulseWells
        for i in wells.indices {
            wells[i].life -= dt
            wells[i].strength *= 0.992
        }
        wells.removeAll { $0.life <= 0 || abs($0.strength) < 0.06 }
        pulseWells = wells

        var next = particles
        let activeWells = [GravityWell(center: primaryWell, strength: CGFloat(1.6 * gravityPower), life: 999, radius: 210)] + wells

        for i in next.indices {
            var p = next[i]
            p.previous = p.position

            var force = CGVector(dx: 0, dy: 0)
            for well in activeWells {
                let dx = well.center.x - p.position.x
                let dy = well.center.y - p.position.y
                let d2 = max(45, (dx * dx) + (dy * dy))
                let d = sqrt(d2)

                let nx = dx / d
                let ny = dy / d
                let falloff = exp(-d / max(80, well.radius))

                let pull = (well.strength * 9500 * CGFloat(gravityPower) * falloff) / d2
                force.dx += nx * pull
                force.dy += ny * pull

                let swirl = (CGFloat(swirlPower) * 0.22 * well.strength * falloff)
                force.dx += -ny * swirl
                force.dy += nx * swirl
            }

            p.velocity.dx += force.dx * dt
            p.velocity.dy += force.dy * dt
            p.velocity.dx *= drag
            p.velocity.dy *= drag

            p.position.x += p.velocity.dx * dt * 60
            p.position.y += p.velocity.dy * dt * 60

            if p.position.x < 0 {
                p.position.x = 0
                p.velocity.dx *= -0.72
            } else if p.position.x > sceneSize.width {
                p.position.x = sceneSize.width
                p.velocity.dx *= -0.72
            }

            if p.position.y < 0 {
                p.position.y = 0
                p.velocity.dy *= -0.72
            } else if p.position.y > sceneSize.height {
                p.position.y = sceneSize.height
                p.velocity.dy *= -0.72
            }

            next[i] = p
        }

        particles = next

        if CGFloat.random(in: 0...1) < CGFloat(delta * 2.4) {
            spawnPulseWell(at: CGPoint(x: CGFloat.random(in: 0...sceneSize.width), y: CGFloat.random(in: 0...sceneSize.height)), strength: CGFloat.random(in: 0.35...0.8))
        }
    }

    private func drawBackgroundGrid(in context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 34
        var grid = Path()

        var x: CGFloat = 0
        while x <= size.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        context.stroke(grid, with: .color(Color(red: 0.42, green: 0.22, blue: 0.8).opacity(0.08)), lineWidth: 1)
    }

    private func drawWells(in context: inout GraphicsContext) {
        let primaryColor = Color(red: 0.7, green: 0.45, blue: 1.0)
        drawWellGlow(in: &context, at: primaryWell, radius: 66, color: primaryColor.opacity(0.38))

        for well in pulseWells {
            let alpha = min(0.5, Double(max(0.08, well.life * 0.42)))
            drawWellGlow(
                in: &context,
                at: well.center,
                radius: max(20, well.radius * 0.42),
                color: Color(red: 0.45, green: 0.9, blue: 1.0).opacity(alpha)
            )
        }
    }

    private func drawWellGlow(in context: inout GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))

        let core = rect.insetBy(dx: radius * 0.45, dy: radius * 0.45)
        context.fill(Path(ellipseIn: core), with: .color(Color.white.opacity(0.35)))
    }

    private func drawParticles(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter

        for p in particles {
            let speed = sqrt((p.velocity.dx * p.velocity.dx) + (p.velocity.dy * p.velocity.dy))
            let tailAlpha = min(0.75, 0.2 + Double(speed * 0.008))

            var trail = Path()
            trail.move(to: p.previous)
            trail.addLine(to: p.position)

            let hue = (p.hue + Double(speed * 0.0007)).truncatingRemainder(dividingBy: 1)
            let color = Color(hue: hue, saturation: 0.78, brightness: 1.0)
            context.stroke(trail, with: .color(color.opacity(tailAlpha)), lineWidth: 1.3)

            let r = p.radius
            let rect = CGRect(x: p.position.x - r, y: p.position.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.58)))

            let core = rect.insetBy(dx: r * 0.45, dy: r * 0.45)
            context.fill(Path(ellipseIn: core), with: .color(Color.white.opacity(0.9)))
        }

        context.blendMode = .normal
    }

    private var desiredParticleCount: Int {
        Int(particleTargetCount.rounded())
    }

    private func syncParticlePopulation() {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return }
        let target = desiredParticleCount

        if particles.count < target {
            let needed = target - particles.count
            particles.append(contentsOf: (0..<needed).map { _ in makeParticle() })
        } else if particles.count > target {
            particles.removeLast(particles.count - target)
        }
    }

    private func makeParticle() -> NeonParticle {
        let position = CGPoint(x: CGFloat.random(in: 0...sceneSize.width), y: CGFloat.random(in: 0...sceneSize.height))
        return NeonParticle(
            position: position,
            previous: position,
            velocity: CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: -60...60)),
            radius: CGFloat.random(in: 1.6...3.2),
            hue: Double.random(in: 0.48...0.83)
        )
    }

    private func spawnPulseWell(at point: CGPoint, strength: CGFloat) {
        pulseWells.append(
            GravityWell(
                center: point,
                strength: strength,
                life: CGFloat.random(in: 0.55...1.25),
                radius: CGFloat.random(in: 120...260)
            )
        )

        if pulseWells.count > 22 {
            pulseWells = Array(pulseWells.suffix(22))
        }
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}

private struct NeonParticle {
    var position: CGPoint
    var previous: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var hue: Double
}

private struct GravityWell {
    var center: CGPoint
    var strength: CGFloat
    var life: CGFloat
    var radius: CGFloat
}

private struct GravityMouseTrackingLayer: NSViewRepresentable {
    let onMove: (CGPoint) -> Void

    func makeNSView(context: Context) -> GravityMouseTrackingNSView {
        let view = GravityMouseTrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: GravityMouseTrackingNSView, context: Context) {
        nsView.onMove = onMove
    }
}

private final class GravityMouseTrackingNSView: NSView {
    var onMove: ((CGPoint) -> Void)?

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        let options: NSTrackingArea.Options = [.activeInKeyWindow, .inVisibleRect, .mouseMoved]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMove?(point)
    }
}

private struct NeonHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.18, green: 0.16, blue: 0.42)
                    .opacity(configuration.isPressed ? 0.84 : 0.62),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct NeonControlRow: View {
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
                    .foregroundStyle(Color(red: 0.78, green: 0.9, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.62, green: 0.78, blue: 1.0))
        }
    }
}

struct NeonParticleGravityToyView_Previews: PreviewProvider {
    static var previews: some View {
        NeonParticleGravityToyView(onBackToMainMenu: {})
    }
}
