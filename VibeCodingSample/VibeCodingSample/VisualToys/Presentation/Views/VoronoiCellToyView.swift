import SwiftUI

struct VoronoiCellToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var sceneSize: CGSize = .zero
    @State private var sites: [VoronoiSite] = []
    @State private var lastTick = Date()

    @State private var siteTargetCount: Double = 24
    @State private var motionSpeed: Double = 1.0

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.14),
                    Color(red: 0.07, green: 0.08, blue: 0.2),
                    Color(red: 0.04, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas(rendersAsynchronously: true) { context, size in
                    drawVoronoi(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                    drawSites(in: &context)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        kick(at: value.location)
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
        .onChange(of: siteTargetCount) { _, _ in
            syncSitePopulation()
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(VoronoiHudButtonStyle())

                Spacer()

                Text("VORONOI CELLS")
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
                VoronoiControlRow(
                    title: "세포 수",
                    valueText: "\(desiredSiteCount)",
                    value: $siteTargetCount,
                    range: 8...48
                )

                VoronoiControlRow(
                    title: "이동 속도",
                    valueText: String(format: "%.2fx", motionSpeed),
                    value: $motionSpeed,
                    range: 0.25...2.2
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
        guard newSize.width > 0 && newSize.height > 0 else { return }
        sceneSize = newSize
        syncSitePopulation()
    }

    private func step(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        syncSitePopulation()

        let dt = CGFloat(delta * motionSpeed)
        var next = sites
        for index in next.indices {
            next[index].position.x += next[index].velocity.dx * dt
            next[index].position.y += next[index].velocity.dy * dt
            next[index].phase += dt

            if next[index].position.x < 0 {
                next[index].position.x = 0
                next[index].velocity.dx *= -1
            } else if next[index].position.x > sceneSize.width {
                next[index].position.x = sceneSize.width
                next[index].velocity.dx *= -1
            }

            if next[index].position.y < 0 {
                next[index].position.y = 0
                next[index].velocity.dy *= -1
            } else if next[index].position.y > sceneSize.height {
                next[index].position.y = sceneSize.height
                next[index].velocity.dy *= -1
            }
        }
        sites = next
    }

    private func drawVoronoi(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard !sites.isEmpty else { return }

        let step: CGFloat = 15
        var y: CGFloat = 0

        while y < size.height {
            var x: CGFloat = 0
            while x < size.width {
                let p = CGPoint(x: x + step * 0.5, y: y + step * 0.5)

                var nearestDistance = CGFloat.greatestFiniteMagnitude
                var secondDistance = CGFloat.greatestFiniteMagnitude
                var nearestSite = sites[0]

                for site in sites {
                    let dx = p.x - site.position.x
                    let dy = p.y - site.position.y
                    let d2 = (dx * dx) + (dy * dy)

                    if d2 < nearestDistance {
                        secondDistance = nearestDistance
                        nearestDistance = d2
                        nearestSite = site
                    } else if d2 < secondDistance {
                        secondDistance = d2
                    }
                }

                let edgeDelta = max(0, min(1, (sqrt(secondDistance) - sqrt(nearestDistance)) / 18))
                let edgeGlow = 1 - edgeDelta

                let pulse = 0.88 + (0.12 * sin(Double(nearestSite.phase) + (time * 1.2)))
                let hue = (nearestSite.hue + (0.03 * sin(time + Double(nearestSite.phase)))).truncatingRemainder(dividingBy: 1)

                var color = Color(hue: hue, saturation: 0.62, brightness: 0.88 * pulse)
                color = color.opacity(0.28 + (0.22 * Double(edgeDelta)))

                let cellRect = CGRect(x: x, y: y, width: step + 1, height: step + 1)
                context.fill(Path(cellRect), with: .color(color))

                if edgeGlow > 0.45 {
                    let edgeColor = Color.white.opacity(Double((edgeGlow - 0.45) * 0.24))
                    context.fill(Path(cellRect.insetBy(dx: 5.8, dy: 5.8)), with: .color(edgeColor))
                }

                x += step
            }
            y += step
        }
    }

    private func drawSites(in context: inout GraphicsContext) {
        context.blendMode = .plusLighter

        for site in sites {
            let pulse = 0.9 + (0.1 * sin(Double(site.phase) * 1.6))
            let r = 7 * pulse
            let rect = CGRect(x: site.position.x - r, y: site.position.y - r, width: r * 2, height: r * 2)
            let color = Color(hue: site.hue, saturation: 0.65, brightness: 1)

            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.55)))
            context.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.48, dy: r * 0.48)), with: .color(Color.white.opacity(0.9)))
        }

        context.blendMode = .normal
    }

    private func kick(at point: CGPoint) {
        guard !sites.isEmpty else { return }

        var next = sites
        for index in next.indices {
            let dx = next[index].position.x - point.x
            let dy = next[index].position.y - point.y
            let distance = max(12, sqrt(dx * dx + dy * dy))
            let nx = dx / distance
            let ny = dy / distance
            let kick = max(0, 140 - distance) * 1.8

            next[index].velocity.dx += nx * kick
            next[index].velocity.dy += ny * kick
        }
        sites = next
    }

    private var desiredSiteCount: Int {
        Int(siteTargetCount.rounded())
    }

    private func syncSitePopulation() {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        let target = desiredSiteCount

        if sites.count < target {
            let needed = target - sites.count
            sites.append(contentsOf: (0..<needed).map { _ in makeSite() })
        } else if sites.count > target {
            sites.removeLast(sites.count - target)
        }
    }

    private func makeSite() -> VoronoiSite {
        VoronoiSite(
            position: CGPoint(
                x: CGFloat.random(in: 0...sceneSize.width),
                y: CGFloat.random(in: 0...sceneSize.height)
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -120...120),
                dy: CGFloat.random(in: -120...120)
            ),
            hue: Double.random(in: 0.5...0.96),
            phase: CGFloat.random(in: 0...(2 * .pi))
        )
    }
}

private struct VoronoiSite {
    var position: CGPoint
    var velocity: CGVector
    var hue: Double
    var phase: CGFloat
}

private struct VoronoiHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.17, green: 0.2, blue: 0.44)
                    .opacity(configuration.isPressed ? 0.82 : 0.6),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct VoronoiControlRow: View {
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
                    .foregroundStyle(Color(red: 0.82, green: 0.9, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.64, green: 0.78, blue: 1.0))
        }
    }
}

struct VoronoiCellToyView_Previews: PreviewProvider {
    static var previews: some View {
        VoronoiCellToyView(onBackToMainMenu: {})
    }
}
