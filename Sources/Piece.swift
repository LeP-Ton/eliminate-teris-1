import Cocoa

struct PieceBlock: Hashable {
    let x: Int
    let y: Int
}

enum PieceKind: CaseIterable {
    case orangeRicky
    case blueRicky
    case clevelandZ
    case rhodeIslandZ

    static func random() -> PieceKind {
        return PieceKind.allCases.randomElement() ?? .orangeRicky
    }

    var color: NSColor {
        switch self {
        case .orangeRicky:
            return NSColor.systemOrange
        case .blueRicky:
            return NSColor.systemBlue
        case .clevelandZ:
            return NSColor.systemGreen
        case .rhodeIslandZ:
            return NSColor.systemRed
        }
    }

    var blocks: [PieceBlock] {
        switch self {
        case .orangeRicky:
            return [
                PieceBlock(x: 0, y: 0),
                PieceBlock(x: 1, y: 0),
                PieceBlock(x: 2, y: 0),
                PieceBlock(x: 2, y: 1)
            ]
        case .blueRicky:
            return [
                PieceBlock(x: 0, y: 0),
                PieceBlock(x: 1, y: 0),
                PieceBlock(x: 2, y: 0),
                PieceBlock(x: 0, y: 1)
            ]
        case .clevelandZ:
            return [
                PieceBlock(x: 1, y: 0),
                PieceBlock(x: 2, y: 0),
                PieceBlock(x: 0, y: 1),
                PieceBlock(x: 1, y: 1)
            ]
        case .rhodeIslandZ:
            return [
                PieceBlock(x: 0, y: 0),
                PieceBlock(x: 1, y: 0),
                PieceBlock(x: 1, y: 1),
                PieceBlock(x: 2, y: 1)
            ]
        }
    }
}
