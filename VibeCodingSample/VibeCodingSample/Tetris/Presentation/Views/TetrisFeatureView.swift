import SwiftUI

struct TetrisFeatureView: View {
    let onBackToMainMenu: () -> Void
    let onQuitApp: () -> Void

    @StateObject private var viewModel = TetrisViewModel()
    @State private var lastTick = Date()

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.22), Color(red: 0.18, green: 0.08, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.screenState {
            case .intro:
                introView
            case .playing:
                gameView
            case .gameOver:
                gameOverView
            }
        }
        .background(
            TetrisKeyCaptureView { action in
                viewModel.handleControl(action)
            }
            .frame(width: 1, height: 1)
        )
        .onAppear {
            lastTick = Date()
        }
        .onReceive(frameTimer) { now in
            let delta = now.timeIntervalSince(lastTick)
            lastTick = now
            viewModel.update(deltaTime: delta)
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var introView: some View {
        VStack(spacing: 16) {
            Text("TETRIS")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("Enter: 회전  |  Space: 즉시 낙하  |  ← → 이동")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            VStack(spacing: 10) {
                Button("게임 시작") {
                    viewModel.startGame()
                }
                .buttonStyle(MainActionButtonStyle())

                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(SubActionButtonStyle())

                Button("종료") {
                    onQuitApp()
                }
                .buttonStyle(SubActionButtonStyle())
            }
        }
    }

    private var gameView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StatCard(title: "점수", value: "\(viewModel.score)")
                StatCard(title: "스테이지", value: "\(viewModel.stage)")
                StatCard(title: "줄", value: "\(viewModel.clearedLines)")
            }

            HStack(alignment: .top, spacing: 20) {
                TetrisBoardView(viewModel: viewModel)
                    .frame(width: 420, height: 780)

                VStack(spacing: 12) {
                    Text("다음 블록")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    NextPiecePreview(viewModel: viewModel)
                        .frame(width: 140, height: 140)

                    Text("조작")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("← → 이동\nEnter 회전\n↓ 한 칸 내리기\nSpace 즉시 낙하")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                    Button("메인 메뉴") {
                        viewModel.showIntro()
                        onBackToMainMenu()
                    }
                    .buttonStyle(SubActionButtonStyle())
                }
                .frame(width: 180)
            }
        }
        .padding(20)
    }

    private var gameOverView: some View {
        VStack(spacing: 14) {
            Text("GAME OVER")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("최종 점수: \(viewModel.score)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 10) {
                Button("다시 시작") {
                    viewModel.startGame()
                }
                .buttonStyle(MainActionButtonStyle())

                Button("인트로") {
                    viewModel.showIntro()
                }
                .buttonStyle(SubActionButtonStyle())

                Button("메인 메뉴") {
                    viewModel.showIntro()
                    onBackToMainMenu()
                }
                .buttonStyle(SubActionButtonStyle())

                Button("종료") {
                    onQuitApp()
                }
                .buttonStyle(SubActionButtonStyle())
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct TetrisBoardView: View {
    @ObservedObject var viewModel: TetrisViewModel

    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(
                geometry.size.width / CGFloat(TetrisBoard.width),
                geometry.size.height / CGFloat(TetrisBoard.height)
            )
            let boardPixelWidth = cellSize * CGFloat(TetrisBoard.width)
            let boardPixelHeight = cellSize * CGFloat(TetrisBoard.height)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.65))
                    .frame(width: boardPixelWidth, height: boardPixelHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    )

                ForEach(0..<TetrisBoard.height, id: \.self) { row in
                    ForEach(0..<TetrisBoard.width, id: \.self) { col in
                        let block = viewModel.displayedType(x: col, y: row)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(block?.color ?? Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(block == nil ? 0.08 : 0.3), lineWidth: 1)
                            )
                            .frame(width: cellSize - 1, height: cellSize - 1)
                            .position(
                                x: CGFloat(col) * cellSize + (cellSize / 2),
                                y: CGFloat(row) * cellSize + (cellSize / 2)
                            )
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }
}

private struct NextPiecePreview: View {
    @ObservedObject var viewModel: TetrisViewModel

    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width, geometry.size.height) / 4.0

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))

                ForEach(0..<4, id: \.self) { row in
                    ForEach(0..<4, id: \.self) { col in
                        let isFilled = viewModel.nextPreviewContains(x: col, y: row)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isFilled ? viewModel.nextPieceType.color : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(isFilled ? 0.3 : 0.12), lineWidth: 1)
                            )
                            .frame(width: cellSize - 2, height: cellSize - 2)
                            .position(
                                x: CGFloat(col) * cellSize + (cellSize / 2),
                                y: CGFloat(row) * cellSize + (cellSize / 2)
                            )
                    }
                }
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MainActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Color(red: 0.15, green: 0.62, blue: 0.88)
                    .opacity(configuration.isPressed ? 0.75 : 1.0),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct SubActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.16 : 0.24),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private extension TetrominoType {
    var color: Color {
        switch self {
        case .i: return .cyan
        case .o: return .yellow
        case .t: return .purple
        case .s: return .green
        case .z: return .red
        case .j: return .blue
        case .l: return .orange
        }
    }
}
