import SwiftUI

enum TetrisScreenState {
    case intro
    case playing
    case gameOver
}

@MainActor
final class TetrisViewModel: ObservableObject {
    @Published private(set) var screenState: TetrisScreenState = .intro
    @Published private(set) var board: [[TetrominoType?]] = TetrisBoard.emptyGrid()
    @Published private(set) var nextPieceType: TetrominoType = .t
    @Published private(set) var score = 0
    @Published private(set) var stage = 1
    @Published private(set) var clearedLines = 0

    private let gameUseCase: TetrisGameUseCase
    private let audioService: TetrisAudioService

    init(
        gameUseCase: TetrisGameUseCase = TetrisGameUseCase(),
        audioService: TetrisAudioService = SystemTetrisAudioService()
    ) {
        self.gameUseCase = gameUseCase
        self.audioService = audioService
        syncFromUseCase()
    }

    func showIntro() {
        screenState = .intro
    }

    func startGame() {
        gameUseCase.startNewGame()
        screenState = .playing
        audioService.playStart()
        syncFromUseCase()
    }

    func update(deltaTime: TimeInterval) {
        guard screenState == .playing else { return }
        let outcome = gameUseCase.tick(deltaTime: deltaTime)
        apply(outcome)
    }

    func handleControl(_ action: TetrisControlAction) {
        guard screenState == .playing else { return }
        let outcome = gameUseCase.perform(action)
        apply(outcome)
    }

    func displayedType(x: Int, y: Int) -> TetrominoType? {
        gameUseCase.displayedType(atX: x, y: y)
    }

    func nextPreviewContains(x: Int, y: Int) -> Bool {
        gameUseCase.nextPreviewContains(x: x, y: y)
    }

    private func apply(_ outcome: TetrisGameOutcome) {
        if outcome.didHardDrop {
            audioService.playHardDrop()
        }

        if outcome.didLockPiece && outcome.clearedLines == 0 {
            audioService.playLock()
        }

        if outcome.clearedLines > 0 {
            audioService.playLineClear()
        }

        if outcome.didStageUp {
            audioService.playStageUp()
        }

        if outcome.didGameOver {
            screenState = .gameOver
            audioService.playGameOver()
        }

        syncFromUseCase()
    }

    private func syncFromUseCase() {
        board = gameUseCase.board
        nextPieceType = gameUseCase.nextPieceType
        score = gameUseCase.score
        stage = gameUseCase.stage
        clearedLines = gameUseCase.clearedLines
    }
}
