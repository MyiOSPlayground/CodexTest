import SwiftUI

struct LaserMirrorPuzzleToyView: View {
    let onBackToMainMenu: () -> Void

    @State private var puzzle = LaserPuzzle.makeRandom(width: 10, height: 10)
    @State private var trace = BeamTrace(path: [], hitTargets: [], loopDetected: false)
    @State private var moveCount = 0
    @State private var glowBoost: Double = 1.0
    @State private var elapsed: TimeInterval = 0
    @State private var lastTick = Date()

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private var isSolved: Bool {
        trace.hitTargets.count == puzzle.targets.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.05, green: 0.04, blue: 0.13),
                    Color(red: 0.02, green: 0.07, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                GeometryReader { geometry in
                    let layout = BoardLayout.make(in: geometry.size, columns: puzzle.width)
                    ZStack {
                        Canvas(rendersAsynchronously: true) { context, _ in
                            drawBoard(in: &context, layout: layout)
                        }
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    handleTap(value.location, in: layout)
                                }
                        )

                        if isSolved {
                            Text("PUZZLE CLEAR")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.13, green: 0.67, blue: 0.38).opacity(0.86), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1.4)
                                )
                                .shadow(color: Color.white.opacity(0.25), radius: 18)
                                .position(x: layout.rect.midX, y: layout.rect.maxY + 42)
                        }
                    }
                }

                controlPanel
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .onAppear {
            recalculateTrace()
            lastTick = Date()
        }
        .onReceive(frameTimer) { now in
            let delta = min(1.0 / 24.0, now.timeIntervalSince(lastTick))
            lastTick = now
            elapsed += delta
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var topBar: some View {
        HStack {
            Button("메인 메뉴") {
                onBackToMainMenu()
            }
            .buttonStyle(LaserHudButtonStyle())

            Spacer()

            Text("LASER MIRROR PUZZLE")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.32), in: Capsule())
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("타겟 \(trace.hitTargets.count)/\(puzzle.targets.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.95))

                Text("회전 \(moveCount)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))

                if trace.loopDetected {
                    Text("루프 감지")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.68))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.22), in: Capsule())
                }

                Spacer()

                Button("새 퍼즐") {
                    newPuzzle()
                }
                .buttonStyle(LaserHudButtonStyle())
            }

            HStack(spacing: 10) {
                Text("레이저 광량")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                Slider(value: $glowBoost, in: 0.35...2.2)
                    .tint(Color(red: 0.98, green: 0.38, blue: 0.37))
                Text(String(format: "%.2fx", glowBoost))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.72))
            }

            Text("거울 타일을 클릭해 회전시키고 레이저로 모든 타겟을 맞추세요.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func newPuzzle() {
        puzzle = LaserPuzzle.makeRandom(width: 10, height: 10)
        moveCount = 0
        recalculateTrace()
    }

    private func handleTap(_ location: CGPoint, in layout: BoardLayout) {
        guard layout.rect.contains(location) else { return }

        let x = Int((location.x - layout.rect.minX) / layout.cellSize)
        let y = Int((location.y - layout.rect.minY) / layout.cellSize)
        let point = LaserGridPoint(x: x, y: y)

        guard let mirror = puzzle.mirrors[point] else { return }

        puzzle.mirrors[point] = mirror.toggled
        moveCount += 1
        recalculateTrace()
    }

    private func recalculateTrace() {
        trace = BeamTrace.trace(for: puzzle)
    }

    private func drawBoard(in context: inout GraphicsContext, layout: BoardLayout) {
        let boardRect = layout.rect
        let cell = layout.cellSize

        context.fill(
            Path(roundedRect: boardRect, cornerSize: CGSize(width: 16, height: 16)),
            with: .color(Color.black.opacity(0.38))
        )
        context.stroke(
            Path(roundedRect: boardRect, cornerSize: CGSize(width: 16, height: 16)),
            with: .color(Color.white.opacity(0.15)),
            lineWidth: 1.2
        )

        for x in 0...puzzle.width {
            let lineX = boardRect.minX + (CGFloat(x) * cell)
            var path = Path()
            path.move(to: CGPoint(x: lineX, y: boardRect.minY))
            path.addLine(to: CGPoint(x: lineX, y: boardRect.maxY))
            context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
        }

        for y in 0...puzzle.height {
            let lineY = boardRect.minY + (CGFloat(y) * cell)
            var path = Path()
            path.move(to: CGPoint(x: boardRect.minX, y: lineY))
            path.addLine(to: CGPoint(x: boardRect.maxX, y: lineY))
            context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
        }

        drawTargets(in: &context, layout: layout)
        drawMirrors(in: &context, layout: layout)
        drawSourceEmitter(in: &context, layout: layout)
        drawBeam(in: &context, layout: layout)
    }

    private func drawTargets(in context: inout GraphicsContext, layout: BoardLayout) {
        for target in puzzle.targets {
            let center = cellCenter(for: target, layout: layout)
            let hit = trace.hitTargets.contains(target)
            let radius = layout.cellSize * (hit ? 0.24 : 0.2)
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

            if hit {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 8))
                    layer.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(Color(red: 1.0, green: 0.89, blue: 0.36).opacity(0.58)))
                }
            }

            context.fill(
                Path(ellipseIn: rect),
                with: .color(hit ? Color(red: 1.0, green: 0.92, blue: 0.52) : Color(red: 0.76, green: 0.89, blue: 1.0))
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.62)),
                lineWidth: 1
            )
        }
    }

    private func drawMirrors(in context: inout GraphicsContext, layout: BoardLayout) {
        let sortedKeys = puzzle.mirrors.keys.sorted { lhs, rhs in
            if lhs.y == rhs.y { return lhs.x < rhs.x }
            return lhs.y < rhs.y
        }

        for point in sortedKeys {
            guard let mirror = puzzle.mirrors[point] else { continue }

            let rect = cellRect(for: point, layout: layout).insetBy(dx: layout.cellSize * 0.16, dy: layout.cellSize * 0.16)
            context.fill(
                Path(roundedRect: rect, cornerSize: CGSize(width: 6, height: 6)),
                with: .color(Color(red: 0.18, green: 0.2, blue: 0.28).opacity(0.9))
            )
            context.stroke(
                Path(roundedRect: rect, cornerSize: CGSize(width: 6, height: 6)),
                with: .color(Color.white.opacity(0.22)),
                lineWidth: 1
            )

            var line = Path()
            switch mirror {
            case .slash:
                line.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 4))
                line.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + 4))
            case .backslash:
                line.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 4))
                line.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 4))
            }

            context.stroke(line, with: .color(Color(red: 0.86, green: 0.95, blue: 1.0)), lineWidth: max(2.4, layout.cellSize * 0.09))
        }
    }

    private func drawSourceEmitter(in context: inout GraphicsContext, layout: BoardLayout) {
        let y = layout.rect.minY + (CGFloat(puzzle.sourceRow) + 0.5) * layout.cellSize
        let x = layout.rect.minX - layout.cellSize * 0.35

        let emitterRect = CGRect(x: x - layout.cellSize * 0.22, y: y - layout.cellSize * 0.22, width: layout.cellSize * 0.44, height: layout.cellSize * 0.44)
        context.fill(Path(ellipseIn: emitterRect), with: .color(Color(red: 1.0, green: 0.32, blue: 0.32)))

        var arrow = Path()
        arrow.move(to: CGPoint(x: x + layout.cellSize * 0.38, y: y))
        arrow.addLine(to: CGPoint(x: x + layout.cellSize * 0.14, y: y - layout.cellSize * 0.12))
        arrow.addLine(to: CGPoint(x: x + layout.cellSize * 0.14, y: y + layout.cellSize * 0.12))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(Color(red: 1.0, green: 0.72, blue: 0.65)))
    }

    private func drawBeam(in context: inout GraphicsContext, layout: BoardLayout) {
        guard trace.path.count > 1 else { return }

        let pulse = 0.58 + 0.42 * abs(sin(elapsed * 5.4))
        let beamColor = isSolved
            ? Color(red: 0.98, green: 0.97, blue: 0.62)
            : Color(red: 1.0, green: 0.42, blue: 0.34)

        var path = Path()
        for (index, point) in trace.path.enumerated() {
            let pixel = beamPointToPixel(point, layout: layout)
            if index == 0 {
                path.move(to: pixel)
            } else {
                path.addLine(to: pixel)
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 9))
            layer.stroke(path, with: .color(beamColor.opacity((0.44 + pulse * 0.35) * glowBoost)), lineWidth: layout.cellSize * 0.2)
        }
        context.stroke(path, with: .color(beamColor.opacity((0.88 + pulse * 0.2) * glowBoost)), lineWidth: layout.cellSize * 0.095)
        context.stroke(path, with: .color(Color.white.opacity(0.86)), lineWidth: layout.cellSize * 0.03)
    }

    private func cellCenter(for point: LaserGridPoint, layout: BoardLayout) -> CGPoint {
        CGPoint(
            x: layout.rect.minX + (CGFloat(point.x) + 0.5) * layout.cellSize,
            y: layout.rect.minY + (CGFloat(point.y) + 0.5) * layout.cellSize
        )
    }

    private func cellRect(for point: LaserGridPoint, layout: BoardLayout) -> CGRect {
        CGRect(
            x: layout.rect.minX + CGFloat(point.x) * layout.cellSize,
            y: layout.rect.minY + CGFloat(point.y) * layout.cellSize,
            width: layout.cellSize,
            height: layout.cellSize
        )
    }

    private func beamPointToPixel(_ point: CGPoint, layout: BoardLayout) -> CGPoint {
        CGPoint(
            x: layout.rect.minX + point.x * layout.cellSize,
            y: layout.rect.minY + point.y * layout.cellSize
        )
    }
}

private struct BoardLayout {
    let rect: CGRect
    let cellSize: CGFloat

    static func make(in availableSize: CGSize, columns: Int) -> BoardLayout {
        let side = min(availableSize.width - 30, availableSize.height - 20)
        let clampedSide = max(260, side)
        let origin = CGPoint(
            x: (availableSize.width - clampedSide) / 2,
            y: max(8, (availableSize.height - clampedSide) / 2)
        )
        let rect = CGRect(origin: origin, size: CGSize(width: clampedSide, height: clampedSide))
        return BoardLayout(rect: rect, cellSize: clampedSide / CGFloat(columns))
    }
}

private struct LaserGridPoint: Hashable {
    let x: Int
    let y: Int

    func moved(_ direction: BeamDirection) -> LaserGridPoint {
        LaserGridPoint(x: x + direction.dx, y: y + direction.dy)
    }
}

private enum BeamDirection: Hashable {
    case up
    case down
    case left
    case right

    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }
}

private enum MirrorType: CaseIterable, Hashable {
    case slash
    case backslash

    var toggled: MirrorType {
        switch self {
        case .slash: return .backslash
        case .backslash: return .slash
        }
    }
}

private struct LaserPuzzle: Equatable {
    let width: Int
    let height: Int
    let sourceRow: Int
    var mirrors: [LaserGridPoint: MirrorType]
    let solution: [LaserGridPoint: MirrorType]
    let targets: [LaserGridPoint]

    static func makeRandom(width: Int, height: Int) -> LaserPuzzle {
        for _ in 0..<240 {
            if let generated = generate(width: width, height: height) {
                return generated
            }
        }
        return fallback(width: width, height: height)
    }

    private static func generate(width: Int, height: Int) -> LaserPuzzle? {
        guard width >= 8, height >= 8 else { return nil }

        let sourceRow = Int.random(in: 1..<(height - 1))
        var direction: BeamDirection = .right
        var current = LaserGridPoint(x: -1, y: sourceRow)
        var visited: Set<LaserGridPoint> = []
        var path: [LaserGridPoint] = []
        var solution: [LaserGridPoint: MirrorType] = [:]

        let desiredTurns = Int.random(in: 3...6)
        let maxSteps = width * height

        for step in 0..<maxSteps {
            let next = current.moved(direction)
            if !isInside(next, width: width, height: height) {
                if path.count >= 14 && solution.count >= 3 {
                    break
                }
                return nil
            }
            if visited.contains(next) {
                return nil
            }

            visited.insert(next)
            path.append(next)

            let options = turnOptions(from: direction, at: next, width: width, height: height, visited: visited)
            let shouldTurn = !options.isEmpty
                && solution.count < desiredTurns
                && (Double.random(in: 0...1) < 0.33 || step > (width + height) / 2)

            if shouldTurn, let choice = options.randomElement() {
                solution[next] = choice.mirror
                direction = choice.direction
            }

            current = next
        }

        guard path.count >= 14, solution.count >= 3 else { return nil }

        let targetCandidates = Array(path.dropFirst(2))
        guard targetCandidates.count >= 3 else { return nil }

        let targetCount = min(4, max(3, targetCandidates.count / 6))
        let targets = Array(targetCandidates.shuffled().prefix(targetCount))

        var mirrors = solution.mapValues { _ in Bool.random() ? MirrorType.slash : MirrorType.backslash }
        if mirrors == solution, let firstKey = mirrors.keys.first {
            mirrors[firstKey] = mirrors[firstKey]?.toggled
        }

        return LaserPuzzle(
            width: width,
            height: height,
            sourceRow: sourceRow,
            mirrors: mirrors,
            solution: solution,
            targets: targets
        )
    }

    private static func turnOptions(
        from direction: BeamDirection,
        at point: LaserGridPoint,
        width: Int,
        height: Int,
        visited: Set<LaserGridPoint>
    ) -> [(direction: BeamDirection, mirror: MirrorType)] {
        var options: [(BeamDirection, MirrorType)] = []

        switch direction {
        case .right:
            let up = LaserGridPoint(x: point.x, y: point.y - 1)
            if isInside(up, width: width, height: height), !visited.contains(up) {
                options.append((.up, .slash))
            }
            let down = LaserGridPoint(x: point.x, y: point.y + 1)
            if isInside(down, width: width, height: height), !visited.contains(down) {
                options.append((.down, .backslash))
            }
        case .left:
            let up = LaserGridPoint(x: point.x, y: point.y - 1)
            if isInside(up, width: width, height: height), !visited.contains(up) {
                options.append((.up, .backslash))
            }
            let down = LaserGridPoint(x: point.x, y: point.y + 1)
            if isInside(down, width: width, height: height), !visited.contains(down) {
                options.append((.down, .slash))
            }
        case .up:
            let left = LaserGridPoint(x: point.x - 1, y: point.y)
            if isInside(left, width: width, height: height), !visited.contains(left) {
                options.append((.left, .slash))
            }
            let right = LaserGridPoint(x: point.x + 1, y: point.y)
            if isInside(right, width: width, height: height), !visited.contains(right) {
                options.append((.right, .backslash))
            }
        case .down:
            let left = LaserGridPoint(x: point.x - 1, y: point.y)
            if isInside(left, width: width, height: height), !visited.contains(left) {
                options.append((.left, .backslash))
            }
            let right = LaserGridPoint(x: point.x + 1, y: point.y)
            if isInside(right, width: width, height: height), !visited.contains(right) {
                options.append((.right, .slash))
            }
        }

        return options
    }

    private static func isInside(_ point: LaserGridPoint, width: Int, height: Int) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }

    private static func fallback(width: Int, height: Int) -> LaserPuzzle {
        let sourceRow = min(max(height / 2, 1), height - 2)
        let solution: [LaserGridPoint: MirrorType] = [
            LaserGridPoint(x: 2, y: sourceRow): .slash,
            LaserGridPoint(x: 2, y: sourceRow - 2): .backslash,
            LaserGridPoint(x: 6, y: sourceRow - 2): .slash,
            LaserGridPoint(x: 6, y: sourceRow + 1): .backslash
        ]
        var mirrors = solution
        mirrors[LaserGridPoint(x: 2, y: sourceRow)] = .backslash
        mirrors[LaserGridPoint(x: 6, y: sourceRow + 1)] = .slash

        let targets = [
            LaserGridPoint(x: 1, y: sourceRow),
            LaserGridPoint(x: 5, y: sourceRow - 2),
            LaserGridPoint(x: 7, y: sourceRow)
        ]

        return LaserPuzzle(
            width: width,
            height: height,
            sourceRow: sourceRow,
            mirrors: mirrors,
            solution: solution,
            targets: targets
        )
    }
}

private struct BeamTrace {
    let path: [CGPoint]
    let hitTargets: Set<LaserGridPoint>
    let loopDetected: Bool

    static func trace(for puzzle: LaserPuzzle) -> BeamTrace {
        let targetSet = Set(puzzle.targets)
        var hits: Set<LaserGridPoint> = []
        var points: [CGPoint] = [CGPoint(x: -0.2, y: CGFloat(puzzle.sourceRow) + 0.5)]
        var current = LaserGridPoint(x: -1, y: puzzle.sourceRow)
        var direction: BeamDirection = .right
        var visitedState: Set<BeamState> = []

        for _ in 0..<500 {
            let next = current.moved(direction)
            if next.x < 0 || next.x >= puzzle.width || next.y < 0 || next.y >= puzzle.height {
                points.append(exitPoint(from: current, direction: direction, width: puzzle.width, height: puzzle.height))
                return BeamTrace(path: points, hitTargets: hits, loopDetected: false)
            }

            points.append(CGPoint(x: CGFloat(next.x) + 0.5, y: CGFloat(next.y) + 0.5))

            if targetSet.contains(next) {
                hits.insert(next)
            }

            if let mirror = puzzle.mirrors[next] {
                direction = reflected(direction, by: mirror)
            }

            let state = BeamState(cell: next, direction: direction)
            if visitedState.contains(state) {
                return BeamTrace(path: points, hitTargets: hits, loopDetected: true)
            }
            visitedState.insert(state)
            current = next
        }

        return BeamTrace(path: points, hitTargets: hits, loopDetected: true)
    }

    private static func reflected(_ direction: BeamDirection, by mirror: MirrorType) -> BeamDirection {
        switch mirror {
        case .slash:
            switch direction {
            case .right: return .up
            case .left: return .down
            case .up: return .right
            case .down: return .left
            }
        case .backslash:
            switch direction {
            case .right: return .down
            case .left: return .up
            case .up: return .left
            case .down: return .right
            }
        }
    }

    private static func exitPoint(from cell: LaserGridPoint, direction: BeamDirection, width: Int, height: Int) -> CGPoint {
        switch direction {
        case .right:
            return CGPoint(x: CGFloat(width) + 0.2, y: CGFloat(cell.y) + 0.5)
        case .left:
            return CGPoint(x: -0.2, y: CGFloat(cell.y) + 0.5)
        case .up:
            return CGPoint(x: CGFloat(cell.x) + 0.5, y: -0.2)
        case .down:
            return CGPoint(x: CGFloat(cell.x) + 0.5, y: CGFloat(height) + 0.2)
        }
    }
}

private struct BeamState: Hashable {
    let cell: LaserGridPoint
    let direction: BeamDirection
}

private struct LaserHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.24, green: 0.22, blue: 0.38)
                    .opacity(configuration.isPressed ? 0.84 : 0.64),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LaserMirrorPuzzleToyView_Previews: PreviewProvider {
    static var previews: some View {
        LaserMirrorPuzzleToyView(onBackToMainMenu: {})
    }
}
