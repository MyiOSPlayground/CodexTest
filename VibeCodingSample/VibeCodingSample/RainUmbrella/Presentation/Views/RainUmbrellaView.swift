import AppKit
import SwiftUI

struct RainUmbrellaView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var umbrellaTarget = CGPoint(x: 380, y: 360)
    @State private var umbrellaPosition = CGPoint(x: 380, y: 360)
    @State private var drops: [RainDrop] = []
    @State private var splashes: [SplashParticle] = []
    @State private var lastTick = Date()
    @State private var rainDropTargetCount: Double = 220
    @State private var rainSpeedMultiplier: Double = 1.0
    @State private var umbrellaScale: Double = 1.0

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.18),
                    Color(red: 0.04, green: 0.07, blue: 0.14),
                    Color(red: 0.02, green: 0.03, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Canvas { context, size in
                drawRain(in: &context, size: size)
                drawSplashes(in: &context)
                drawUmbrella(in: &context)
                drawGround(in: &context, size: size)
            }

            VignetteOverlay()

            hud
        }
        .overlay(
            MouseTrackingLayer { point in
                umbrellaTarget = clamp(point, in: sceneSize)
            }
            .allowsHitTesting(false)
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
        .onChange(of: rainDropTargetCount) { _, _ in
            syncDropPopulation()
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(RainHudButtonStyle())

                Spacer()

                Text("RAIN / UMBRELLA PHYSICS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            controlPanel
                .padding(.horizontal, 20)

            Text("마우스로 우산을 움직여 빗방울을 튕겨보세요")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            RainControlRow(
                title: "빗방울 양",
                valueText: "\(desiredDropCount)",
                value: $rainDropTargetCount,
                range: 80...420
            )

            RainControlRow(
                title: "비 속도",
                valueText: String(format: "%.2fx", rainSpeedMultiplier),
                value: $rainSpeedMultiplier,
                range: 0.55...2.2
            )

            RainControlRow(
                title: "우산 크기",
                valueText: String(format: "%.2fx", umbrellaScale),
                value: $umbrellaScale,
                range: 0.7...1.45
            )
        }
        .padding(14)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func resizeScene(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        sceneSize = newSize

        umbrellaTarget = clamp(umbrellaTarget, in: newSize)
        umbrellaPosition = clamp(umbrellaPosition, in: newSize)

        if drops.isEmpty {
            drops = (0..<desiredDropCount).map { _ in makeDrop(in: newSize, spawnAnywhere: true) }
        }
        syncDropPopulation()
    }

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return }

        let follow = min(1.0, delta * 11.0)
        umbrellaPosition.x += (umbrellaTarget.x - umbrellaPosition.x) * follow
        umbrellaPosition.y += (umbrellaTarget.y - umbrellaPosition.y) * follow
        umbrellaPosition = clamp(umbrellaPosition, in: sceneSize)
        syncDropPopulation()

        let floorY = sceneSize.height - 34
        let canopyHalfWidth: CGFloat = 85 * CGFloat(umbrellaScale)
        let canopyHeight: CGFloat = 54 * CGFloat(umbrellaScale)
        let canopyBaseline = umbrellaPosition.y
        let rainDelta = delta * rainSpeedMultiplier

        var nextDrops = drops
        var nextSplashes = splashes

        for index in nextDrops.indices {
            var drop = nextDrops[index]

            drop.velocity.dy += CGFloat(320 * rainDelta)
            drop.position.x += drop.velocity.dx * CGFloat(rainDelta)
            drop.position.y += drop.velocity.dy * CGFloat(rainDelta)

            if drop.position.x < -40 { drop.position.x = sceneSize.width + 40 }
            if drop.position.x > sceneSize.width + 40 { drop.position.x = -40 }

            let dx = drop.position.x - umbrellaPosition.x
            let normalized = dx / canopyHalfWidth
            if abs(normalized) < 1.0, drop.velocity.dy > 0 {
                let arcY = canopyBaseline - sqrt(max(0, 1 - normalized * normalized)) * canopyHeight
                if drop.position.y + drop.radius >= arcY,
                   drop.position.y - drop.radius <= canopyBaseline + 8 {
                    var nx = normalized
                    var ny = -1.0 / canopyHeight
                    let length = sqrt((nx * nx) + (ny * ny))
                    if length > 0 {
                        nx /= length
                        ny /= length
                    }

                    let dot = (drop.velocity.dx * nx) + (drop.velocity.dy * ny)
                    drop.velocity.dx = (drop.velocity.dx - (2 * dot * nx)) * CGFloat.random(in: 0.58...0.72)
                    drop.velocity.dy = (drop.velocity.dy - (2 * dot * ny)) * CGFloat.random(in: 0.58...0.72)

                    if drop.velocity.dy > -120 {
                        drop.velocity.dy = -CGFloat.random(in: 130...220)
                    }
                    drop.velocity.dx += normalized * CGFloat.random(in: 30...90)
                    drop.position.y = arcY - drop.radius - 0.8

                    spawnSplash(
                        into: &nextSplashes,
                        at: CGPoint(x: drop.position.x, y: drop.position.y + 3),
                        baseVelocity: CGVector(dx: drop.velocity.dx * 0.18, dy: drop.velocity.dy * 0.1),
                        count: Int.random(in: 2...4),
                        lifeRange: 0.25...0.5,
                        speedRange: 20...85
                    )
                }
            }

            if drop.position.y + drop.radius >= floorY {
                drop.position.y = floorY - drop.radius

                let impact = abs(drop.velocity.dy)
                if impact > 100 {
                    drop.velocity.dy = -impact * CGFloat.random(in: 0.24...0.38)
                    drop.velocity.dx *= CGFloat.random(in: 0.62...0.82)
                    drop.bounceCount += 1

                    spawnSplash(
                        into: &nextSplashes,
                        at: CGPoint(x: drop.position.x, y: floorY - 2),
                        baseVelocity: CGVector(dx: drop.velocity.dx * 0.3, dy: -impact * 0.08),
                        count: Int.random(in: 4...8),
                        lifeRange: 0.3...0.65,
                        speedRange: 30...130
                    )
                }

                if drop.bounceCount > 1 || abs(drop.velocity.dy) < 65 {
                    drop = makeDrop(in: sceneSize, spawnAnywhere: false)
                }
            }

            if drop.position.y > sceneSize.height + 120 {
                drop = makeDrop(in: sceneSize, spawnAnywhere: false)
            }

            nextDrops[index] = drop
        }

        for index in nextSplashes.indices {
            nextSplashes[index].position.x += nextSplashes[index].velocity.dx * CGFloat(delta)
            nextSplashes[index].position.y += nextSplashes[index].velocity.dy * CGFloat(delta)
            nextSplashes[index].velocity.dy += CGFloat(430 * delta)
            nextSplashes[index].life -= CGFloat(delta) * nextSplashes[index].decayRate
        }
        nextSplashes.removeAll { $0.life <= 0 }

        if nextSplashes.count > 800 {
            nextSplashes = Array(nextSplashes.suffix(800))
        }

        drops = nextDrops
        splashes = nextSplashes
    }

    private func drawRain(in context: inout GraphicsContext, size: CGSize) {
        for drop in drops {
            let tailLength = drop.trail + max(6, drop.velocity.dy * 0.02)
            var streak = Path()
            streak.move(to: drop.position)
            streak.addLine(to: CGPoint(x: drop.position.x - (drop.velocity.dx * 0.03), y: drop.position.y - tailLength))

            let core = Color(red: 0.68, green: 0.85, blue: 1.0).opacity(0.72)
            context.stroke(streak, with: .color(core), lineWidth: max(0.9, drop.radius * 0.95))

            let highlightRect = CGRect(
                x: drop.position.x - drop.radius,
                y: drop.position.y - drop.radius,
                width: drop.radius * 2,
                height: drop.radius * 2
            )
            context.fill(Path(ellipseIn: highlightRect), with: .color(Color.white.opacity(0.52)))
        }

        let mistRect = CGRect(x: 0, y: size.height - 180, width: size.width, height: 180)
        context.fill(
            Path(mistRect),
            with: .linearGradient(
                Gradient(colors: [Color.clear, Color(red: 0.5, green: 0.72, blue: 0.92).opacity(0.12)]),
                startPoint: CGPoint(x: size.width / 2, y: mistRect.minY),
                endPoint: CGPoint(x: size.width / 2, y: mistRect.maxY)
            )
        )
    }

    private func drawUmbrella(in context: inout GraphicsContext) {
        let scale = CGFloat(umbrellaScale)
        let halfWidth: CGFloat = 85 * scale
        let canopyHeight: CGFloat = 54 * scale
        let base = CGPoint(x: umbrellaPosition.x, y: umbrellaPosition.y)

        let left = CGPoint(x: base.x - halfWidth, y: base.y)
        let right = CGPoint(x: base.x + halfWidth, y: base.y)

        var canopy = Path()
        canopy.move(to: left)
        canopy.addQuadCurve(
            to: CGPoint(x: base.x, y: base.y - canopyHeight),
            control: CGPoint(x: base.x - halfWidth * 0.56, y: base.y - canopyHeight * 1.07)
        )
        canopy.addQuadCurve(
            to: right,
            control: CGPoint(x: base.x + halfWidth * 0.56, y: base.y - canopyHeight * 1.07)
        )
        canopy.addQuadCurve(
            to: CGPoint(x: base.x + halfWidth * 0.32, y: base.y + (10 * scale)),
            control: CGPoint(x: base.x + halfWidth * 0.63, y: base.y + (18 * scale))
        )
        canopy.addQuadCurve(
            to: CGPoint(x: base.x, y: base.y + (2 * scale)),
            control: CGPoint(x: base.x + halfWidth * 0.14, y: base.y + (15 * scale))
        )
        canopy.addQuadCurve(
            to: CGPoint(x: base.x - halfWidth * 0.32, y: base.y + (10 * scale)),
            control: CGPoint(x: base.x - halfWidth * 0.14, y: base.y + (15 * scale))
        )
        canopy.addQuadCurve(to: left, control: CGPoint(x: base.x - halfWidth * 0.63, y: base.y + (18 * scale)))

        context.fill(
            canopy,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.93, green: 0.18, blue: 0.42),
                    Color(red: 0.46, green: 0.05, blue: 0.18)
                ]),
                startPoint: CGPoint(x: base.x, y: base.y - canopyHeight),
                endPoint: CGPoint(x: base.x, y: base.y + 16)
            )
        )
        context.stroke(canopy, with: .color(Color.white.opacity(0.5)), lineWidth: 1.2)

        var ribLeft = Path()
        ribLeft.move(to: CGPoint(x: base.x, y: base.y - canopyHeight + (3 * scale)))
        ribLeft.addLine(to: CGPoint(x: base.x - halfWidth * 0.56, y: base.y + (2 * scale)))
        context.stroke(ribLeft, with: .color(Color.white.opacity(0.22)), lineWidth: 1)

        var ribRight = Path()
        ribRight.move(to: CGPoint(x: base.x, y: base.y - canopyHeight + (3 * scale)))
        ribRight.addLine(to: CGPoint(x: base.x + halfWidth * 0.56, y: base.y + (2 * scale)))
        context.stroke(ribRight, with: .color(Color.white.opacity(0.22)), lineWidth: 1)

        var handle = Path()
        handle.move(to: CGPoint(x: base.x, y: base.y + (2 * scale)))
        handle.addLine(to: CGPoint(x: base.x, y: base.y + (90 * scale)))
        handle.addQuadCurve(
            to: CGPoint(x: base.x + (18 * scale), y: base.y + (102 * scale)),
            control: CGPoint(x: base.x + (2 * scale), y: base.y + (105 * scale))
        )

        context.stroke(handle, with: .color(Color(red: 0.94, green: 0.76, blue: 0.31)), lineWidth: max(2.6, 4.2 * scale))
        context.stroke(handle, with: .color(Color.white.opacity(0.2)), lineWidth: 1.3)
    }

    private func drawSplashes(in context: inout GraphicsContext) {
        for splash in splashes {
            let rect = CGRect(
                x: splash.position.x - splash.radius,
                y: splash.position.y - splash.radius,
                width: splash.radius * 2,
                height: splash.radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.75, green: 0.9, blue: 1.0).opacity(Double(splash.life) * 0.8))
            )
        }
    }

    private func drawGround(in context: inout GraphicsContext, size: CGSize) {
        let floorRect = CGRect(x: 0, y: size.height - 40, width: size.width, height: 40)
        context.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.18, green: 0.26, blue: 0.36).opacity(0.65),
                    Color(red: 0.08, green: 0.11, blue: 0.19).opacity(0.9)
                ]),
                startPoint: CGPoint(x: size.width / 2, y: floorRect.minY),
                endPoint: CGPoint(x: size.width / 2, y: floorRect.maxY)
            )
        )
    }

    private func spawnSplash(
        into splashes: inout [SplashParticle],
        at point: CGPoint,
        baseVelocity: CGVector,
        count: Int,
        lifeRange: ClosedRange<CGFloat>,
        speedRange: ClosedRange<CGFloat>
    ) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: -.pi...0)
            let speed = CGFloat.random(in: speedRange)
            let vx = cos(angle) * speed + baseVelocity.dx
            let vy = sin(angle) * speed + baseVelocity.dy
            let particle = SplashParticle(
                position: point,
                velocity: CGVector(dx: vx, dy: vy),
                radius: CGFloat.random(in: 0.7...2.1),
                life: CGFloat.random(in: lifeRange),
                decayRate: CGFloat.random(in: 1.4...2.2)
            )
            splashes.append(particle)
        }
    }

    private func makeDrop(in size: CGSize, spawnAnywhere: Bool) -> RainDrop {
        RainDrop(
            position: CGPoint(
                x: CGFloat.random(in: -20...(size.width + 20)),
                y: spawnAnywhere ? CGFloat.random(in: -size.height...size.height) : CGFloat.random(in: -220 ... -20)
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -30...30),
                dy: CGFloat.random(in: 220...760)
            ),
            radius: CGFloat.random(in: 1.0...2.8),
            trail: CGFloat.random(in: 10...28),
            bounceCount: 0
        )
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let scale = CGFloat(umbrellaScale)
        let horizontalInset = max(70, 96 * scale)
        let topInset = max(90, 120 * scale)
        let bottomInset = max(96, 130 * scale)
        return CGPoint(
            x: min(max(point.x, horizontalInset), max(horizontalInset, size.width - horizontalInset)),
            y: min(max(point.y, topInset), max(topInset, size.height - bottomInset))
        )
    }

    private var desiredDropCount: Int {
        Int(rainDropTargetCount.rounded())
    }

    private func syncDropPopulation() {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return }

        let target = desiredDropCount
        if drops.count < target {
            let needed = target - drops.count
            drops.append(contentsOf: (0..<needed).map { _ in makeDrop(in: sceneSize, spawnAnywhere: true) })
        } else if drops.count > target {
            drops.removeLast(drops.count - target)
        }
    }
}

private struct RainDrop {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var trail: CGFloat
    var bounceCount: Int
}

private struct SplashParticle {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var life: CGFloat
    var decayRate: CGFloat
}

private struct MouseTrackingLayer: NSViewRepresentable {
    let onMove: (CGPoint) -> Void

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.onMove = onMove
    }
}

private final class MouseTrackingNSView: NSView {
    var onMove: ((CGPoint) -> Void)?

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.activeInKeyWindow, .inVisibleRect, .mouseMoved]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func mouseMoved(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        onMove?(localPoint)
    }
}

private struct VignetteOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.58)],
                center: .center,
                startRadius: min(geometry.size.width, geometry.size.height) * 0.22,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.72
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

private struct RainHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.12, green: 0.2, blue: 0.38)
                    .opacity(configuration.isPressed ? 0.78 : 0.58),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct RainControlRow: View {
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
                    .foregroundStyle(Color(red: 0.7, green: 0.9, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.56, green: 0.82, blue: 1.0))
        }
    }
}

struct RainUmbrellaView_Previews: PreviewProvider {
    static var previews: some View {
        RainUmbrellaView(onBackToMainMenu: {})
    }
}
