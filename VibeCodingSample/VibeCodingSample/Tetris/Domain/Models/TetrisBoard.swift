import Foundation

enum TetrisBoard {
    static let width = 10
    static let height = 20

    static func emptyGrid() -> [[TetrominoType?]] {
        Array(repeating: Array(repeating: nil, count: width), count: height)
    }
}

struct GridPoint: Equatable {
    let x: Int
    let y: Int
}
