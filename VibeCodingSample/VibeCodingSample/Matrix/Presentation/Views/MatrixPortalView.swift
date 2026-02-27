import SwiftUI

struct MatrixPortalView: View {
    let onBackToMainMenu: () -> Void

    @State private var entrance = 0.0
    @State private var showHud = false

    var body: some View {
        ZStack {
            MatrixRainFieldView()
                .scaleEffect(1.12 - (0.12 * entrance))
                .opacity(entrance)

            ScanlineOverlay()
                .opacity(0.25)
                .blendMode(.screen)

            glitchOverlay

            hud
                .opacity(showHud ? 1.0 : 0.0)
                .offset(y: showHud ? 0 : 12)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.75)) {
                entrance = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showHud = true
            }
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(MatrixHudButtonStyle())

                Spacer()

                Text("MATRIX LINK // ACTIVE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.7, green: 1.0, blue: 0.75).opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.45), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            Text("ENTER THE MATRIX")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.72, green: 1.0, blue: 0.74).opacity(0.85))
                .shadow(color: Color.green.opacity(0.6), radius: 12)

            Text("신호 수신중... 디지털 레인 스트림 가동")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.62, green: 0.93, blue: 0.66).opacity(0.8))
                .padding(.top, 4)
                .padding(.bottom, 24)
        }
    }

    private var glitchOverlay: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let stripes = 10
                for index in 0..<stripes {
                    let seed = Double(index) * 13.7
                    let pulse = sin((t * 3.2) + seed)
                    guard pulse > 0.82 else { continue }

                    let y = CGFloat(abs(sin((t * 0.73) + seed))) * size.height
                    let widthFactor = CGFloat(0.3 + (0.7 * abs(cos((t * 1.9) + seed))))
                    let rect = CGRect(
                        x: CGFloat(abs(sin((t * 1.1) + seed))) * size.width * 0.25,
                        y: y,
                        width: size.width * widthFactor,
                        height: 2 + CGFloat(index % 3)
                    )
                    let alpha = 0.05 + (0.08 * CGFloat(pulse))
                    context.fill(
                        Path(rect),
                        with: .color(Color(red: 0.65, green: 1.0, blue: 0.7).opacity(alpha))
                    )
                }
            }
        }
    }
}

private struct MatrixRainFieldView: View {
    @State private var lanes: [MatrixLane] = []
    @State private var sceneSize: CGSize = .zero
    @State private var elapsed: TimeInterval = 0
    @State private var lastTick = Date()

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, canvasSize in
                drawBackground(in: &context, size: canvasSize)
                drawLanes(in: &context, size: canvasSize)
            }
            .onAppear {
                resetScene(for: geometry.size)
                lastTick = Date()
            }
            .onChange(of: geometry.size) { _, newSize in
                resetScene(for: newSize)
            }
            .onReceive(frameTimer) { now in
                let delta = min(1.0 / 24.0, now.timeIntervalSince(lastTick))
                lastTick = now
                updateLanes(delta: delta)
            }
        }
    }

    private func resetScene(for newSize: CGSize) {
        guard newSize.width > 0 && newSize.height > 0 else { return }
        sceneSize = newSize
        elapsed = 0

        let laneCount = max(28, Int(newSize.width / 15.0))
        let laneWidth = newSize.width / CGFloat(laneCount)
        lanes = (0..<laneCount).map { index in
            let x = (CGFloat(index) * laneWidth) + CGFloat.random(in: -2...2)
            return MatrixLane(
                index: index,
                x: x,
                state: .idle(cooldown: CGFloat.random(in: 0...1.5))
            )
        }
    }

    private func updateLanes(delta: TimeInterval) {
        guard sceneSize.width > 0 && sceneSize.height > 0 else { return }
        elapsed += delta

        var next = lanes
        for index in next.indices {
            switch next[index].state {
            case .idle(let cooldown):
                let nextCooldown = max(0, cooldown - CGFloat(delta))
                if nextCooldown <= 0 && CGFloat.random(in: 0...1) < CGFloat(delta * 1.28) {
                    next[index].state = .active(makeRun(for: next[index]))
                } else {
                    next[index].state = .idle(cooldown: nextCooldown)
                }

            case .active(var run):
                run.headY += run.speed * CGFloat(delta)
                let tailHeight = CGFloat(run.length) * run.glyphSpacing
                if run.headY - tailHeight > run.endY + (run.glyphSize * 3) {
                    next[index].state = .idle(cooldown: CGFloat.random(in: 0.12...1.8))
                } else {
                    next[index].state = .active(run)
                }
            }
        }
        lanes = next
    }

    private func makeRun(for lane: MatrixLane) -> MatrixRun {
        let script = MatrixScript.allCases.randomElement() ?? .latin
        let startY = CGFloat.random(in: -sceneSize.height * 0.28 ... sceneSize.height * 0.72)
        let minEndY = max(startY + sceneSize.height * 0.2, sceneSize.height * 0.45)
        let maxEndY = max(minEndY + 25, sceneSize.height * 1.2)

        return MatrixRun(
            script: script,
            startY: startY,
            endY: CGFloat.random(in: minEndY...maxEndY),
            headY: startY,
            speed: CGFloat.random(in: 100...340),
            length: Int.random(in: 9...30),
            glyphSize: CGFloat.random(in: 13...20),
            seed: Int.random(in: 0...1_000_000),
            gapSeed: Double.random(in: 0...(Double.pi * 2))
        )
    }

    private func drawBackground(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(Color.black))

        let glow = 0.08 + (0.08 * (sin(elapsed * 0.72) + 1.0) * 0.5)

        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.1, blue: 0.04).opacity(0.3 + glow),
                    Color.black.opacity(0.92)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )
    }

    private func drawLanes(in context: inout GraphicsContext, size: CGSize) {
        for lane in lanes {
            guard case .active(let run) = lane.state else { continue }
            let glyphs = run.script.characters
            guard !glyphs.isEmpty else { continue }

            for i in 0..<run.length {
                let y = run.headY - (CGFloat(i) * run.glyphSpacing)
                if y < -40 || y > size.height + 64 { continue }

                if i > 0 {
                    let gapSignal = sin((elapsed * 3.5) + run.gapSeed + (Double(i) * 0.78) + (Double(lane.index) * 0.16))
                    if gapSignal > 0.9 {
                        continue
                    }
                }

                let progress = CGFloat(i) / CGFloat(max(run.length - 1, 1))
                let baseAlpha = max(0.05, 1.0 - progress * 1.15)
                let shimmer = 0.68 + (0.32 * CGFloat(abs(sin((elapsed * 8.0) + Double(run.seed % 29) + (Double(i) * 0.6))))
                )

                let color: Color
                if i == 0 {
                    color = Color(red: 0.92, green: 1.0, blue: 0.94).opacity(0.95)
                } else {
                    color = Color(red: 0.24, green: 1.0, blue: 0.42).opacity(baseAlpha * shimmer)
                }

                let symbol = symbolFor(run: run, laneIndex: lane.index, elementIndex: i, y: y, glyphs: glyphs)
                let text = Text(symbol)
                    .font(.system(size: run.glyphSize, weight: .medium, design: .monospaced))
                    .foregroundColor(color)

                context.draw(text, at: CGPoint(x: lane.x, y: y), anchor: .topLeading)

                if i == 0 {
                    let bloomRect = CGRect(x: lane.x - 2, y: y - 1, width: run.glyphSize + 6, height: run.glyphSize + 4)
                    context.fill(
                        Path(roundedRect: bloomRect, cornerRadius: 3),
                        with: .color(Color(red: 0.72, green: 1.0, blue: 0.78).opacity(0.2))
                    )
                }
            }
        }
    }

    private func symbolFor(
        run: MatrixRun,
        laneIndex: Int,
        elementIndex: Int,
        y: CGFloat,
        glyphs: [Character]
    ) -> String {
        let frameSeed = Int(elapsed * 36.0)
        let ySeed = Int(y * 0.16)
        let glyphIndex = abs(
            run.seed
            + (laneIndex * 17)
            + (elementIndex * 13)
            + frameSeed
            + ySeed
        ) % glyphs.count
        return String(glyphs[glyphIndex])
    }
}

private struct MatrixLane {
    let index: Int
    let x: CGFloat
    var state: MatrixLaneState
}

private enum MatrixLaneState {
    case idle(cooldown: CGFloat)
    case active(MatrixRun)
}

private struct MatrixRun {
    let script: MatrixScript
    let startY: CGFloat
    let endY: CGFloat
    var headY: CGFloat
    let speed: CGFloat
    let length: Int
    let glyphSize: CGFloat
    let seed: Int
    let gapSeed: Double

    var glyphSpacing: CGFloat {
        glyphSize * 1.05
    }
}

private enum MatrixScript: CaseIterable {
    case latin
    case korean
    case traditionalChinese
    case japanese
    case cyrillic
    case arabic
    case devanagari
    case greek

    var characters: [Character] {
        switch self {
        case .latin:
            return Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@%&*+-=<>[]{}()")
        case .korean:
            return Array("가나다라마바사아자차카타파하한민국서울컴퓨터네온디지털흐름빛파도신호연결")
        case .traditionalChinese:
            return Array("繁體中文資料系統網路程式碼連接虛擬世界矩陣電腦輸入輸出運算核心")
        case .japanese:
            return Array("アイウエオカキクケコサシスセソタチツテトナニヌネノマミムメモヤユヨラリルレロ")
        case .cyrillic:
            return Array("АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
        case .arabic:
            return Array("ابتثجحخدذرزسشصضطظعغفقكلمنهوي")
        case .devanagari:
            return Array("अआइईउऊएऐओऔकखगघचछजझटठडढतथदधनपफबभमयरलवशषसह")
        case .greek:
            return Array("ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ")
        }
    }
}

private struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let lineSpacing: CGFloat = 3
                let count = Int(size.height / lineSpacing)
                for i in 0..<count {
                    let y = CGFloat(i) * lineSpacing
                    let alpha = i.isMultiple(of: 2) ? 0.045 : 0.01
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(Color.green.opacity(alpha)))
                }

                let vignette = CGRect(origin: .zero, size: size)
                context.stroke(
                    Path(roundedRect: vignette.insetBy(dx: 8, dy: 8), cornerRadius: 14),
                    with: .color(Color.green.opacity(0.16)),
                    lineWidth: 2
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MatrixHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(red: 0.8, green: 1.0, blue: 0.84))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Color(red: 0.04, green: 0.2, blue: 0.08)
                    .opacity(configuration.isPressed ? 0.88 : 0.7),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MatrixPortalView_Previews: PreviewProvider {
    static var previews: some View {
        MatrixPortalView(onBackToMainMenu: {})
    }
}
