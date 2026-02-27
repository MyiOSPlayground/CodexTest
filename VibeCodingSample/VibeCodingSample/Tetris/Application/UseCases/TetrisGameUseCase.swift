import Foundation

struct TetrisGameOutcome {
    var didLockPiece = false
    var didHardDrop = false
    var clearedLines = 0
    var didStageUp = false
    var didGameOver = false

    static let none = TetrisGameOutcome()

    mutating func merge(with other: TetrisGameOutcome) {
        didLockPiece = didLockPiece || other.didLockPiece
        didHardDrop = didHardDrop || other.didHardDrop
        clearedLines += other.clearedLines
        didStageUp = didStageUp || other.didStageUp
        didGameOver = didGameOver || other.didGameOver
    }
}

final class TetrisGameUseCase {
    private(set) var board: [[TetrominoType?]] = TetrisBoard.emptyGrid()
    private(set) var activePiece: ActivePiece?
    private(set) var nextPieceType: TetrominoType = .t
    private(set) var score = 0
    private(set) var stage = 1
    private(set) var clearedLines = 0

    private var pieceBag: [TetrominoType] = []
    private var dropAccumulator = 0.0
    private var dropInterval = 0.75

    func startNewGame() {
        board = TetrisBoard.emptyGrid()
        score = 0
        stage = 1
        clearedLines = 0
        dropAccumulator = 0
        dropInterval = 0.75
        pieceBag.removeAll()

        let first = drawFromBag()
        nextPieceType = drawFromBag()
        activePiece = ActivePiece(type: first, rotation: 0, position: GridPoint(x: 3, y: 0))
    }

    func tick(deltaTime: TimeInterval) -> TetrisGameOutcome {
        dropAccumulator += deltaTime

        var result = TetrisGameOutcome.none
        while dropAccumulator >= dropInterval {
            dropAccumulator -= dropInterval
            let step = moveDownAndLockIfNeeded()
            result.merge(with: step)
            if step.didLockPiece {
                break
            }
        }
        return result
    }

    func perform(_ action: TetrisControlAction) -> TetrisGameOutcome {
        switch action {
        case .left:
            moveHorizontal(-1)
            return .none
        case .right:
            moveHorizontal(1)
            return .none
        case .down:
            return moveDownAndLockIfNeeded()
        case .rotate:
            rotate()
            return .none
        case .hardDrop:
            return hardDrop()
        }
    }

    func displayedType(atX x: Int, y: Int) -> TetrominoType? {
        if let piece = activePiece {
            for point in occupiedCells(of: piece) where point.x == x && point.y == y {
                return piece.type
            }
        }
        return board[y][x]
    }

    func nextPreviewContains(x: Int, y: Int) -> Bool {
        nextPieceType.cells(rotation: 0).contains(where: { $0.x == x && $0.y == y })
    }

    private func moveHorizontal(_ deltaX: Int) {
        guard var piece = activePiece else { return }
        piece.position = GridPoint(x: piece.position.x + deltaX, y: piece.position.y)
        if isValid(piece) {
            activePiece = piece
        }
    }

    private func rotate() {
        guard var piece = activePiece else { return }
        piece.rotation = (piece.rotation + 1) % 4
        for kickX in [0, -1, 1, -2, 2] {
            var kicked = piece
            kicked.position = GridPoint(x: piece.position.x + kickX, y: piece.position.y)
            if isValid(kicked) {
                activePiece = kicked
                return
            }
        }
    }

    private func moveDownAndLockIfNeeded() -> TetrisGameOutcome {
        guard var piece = activePiece else { return .none }
        piece.position = GridPoint(x: piece.position.x, y: piece.position.y + 1)
        if isValid(piece) {
            activePiece = piece
            return .none
        }
        return lockCurrentPiece(fromHardDrop: false)
    }

    private func hardDrop() -> TetrisGameOutcome {
        guard var piece = activePiece else { return .none }
        while true {
            var next = piece
            next.position = GridPoint(x: next.position.x, y: next.position.y + 1)
            if isValid(next) {
                piece = next
            } else {
                break
            }
        }
        activePiece = piece
        return lockCurrentPiece(fromHardDrop: true)
    }

    private func lockCurrentPiece(fromHardDrop: Bool) -> TetrisGameOutcome {
        guard let piece = activePiece else { return .none }

        for point in occupiedCells(of: piece) {
            guard point.y >= 0 && point.y < TetrisBoard.height && point.x >= 0 && point.x < TetrisBoard.width else { continue }
            board[point.y][point.x] = piece.type
        }
        activePiece = nil

        var outcome = TetrisGameOutcome.none
        outcome.didLockPiece = true
        outcome.didHardDrop = fromHardDrop

        let removed = clearCompletedLines()
        if removed > 0 {
            score += removed * 100
            clearedLines += removed
            outcome.clearedLines = removed
            outcome.didStageUp = updateStageIfNeeded()
        }

        let spawned = spawnNextPiece()
        outcome.didGameOver = !spawned

        return outcome
    }

    private func spawnNextPiece() -> Bool {
        let newPiece = ActivePiece(type: nextPieceType, rotation: 0, position: GridPoint(x: 3, y: 0))
        nextPieceType = drawFromBag()

        if isValid(newPiece) {
            activePiece = newPiece
            return true
        }

        activePiece = nil
        return false
    }

    private func clearCompletedLines() -> Int {
        let remainingRows = board.filter { row in
            row.contains(where: { $0 == nil })
        }
        let removedCount = TetrisBoard.height - remainingRows.count
        guard removedCount > 0 else { return 0 }

        let emptyRows = Array(
            repeating: Array<TetrominoType?>(repeating: nil, count: TetrisBoard.width),
            count: removedCount
        )
        board = emptyRows + remainingRows

        return removedCount
    }

    private func updateStageIfNeeded() -> Bool {
        var raised = false
        while score >= stage * 5000 {
            stage += 1
            dropInterval = max(0.12, dropInterval * 0.9)
            raised = true
        }
        return raised
    }

    private func occupiedCells(of piece: ActivePiece) -> [GridPoint] {
        piece.type.cells(rotation: piece.rotation).map {
            GridPoint(x: piece.position.x + $0.x, y: piece.position.y + $0.y)
        }
    }

    private func isValid(_ piece: ActivePiece) -> Bool {
        for point in occupiedCells(of: piece) {
            if point.x < 0 || point.x >= TetrisBoard.width || point.y < 0 || point.y >= TetrisBoard.height {
                return false
            }
            if board[point.y][point.x] != nil {
                return false
            }
        }
        return true
    }

    private func drawFromBag() -> TetrominoType {
        if pieceBag.isEmpty {
            pieceBag = TetrominoType.allCases.shuffled()
        }
        return pieceBag.removeFirst()
    }
}
