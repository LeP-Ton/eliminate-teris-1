import Cocoa

struct PieceBlock: Hashable {
    let x: Int
    let y: Int
}

enum PieceKind: String, CaseIterable, Hashable {
    // 稳定标识用于累计统计存档，不依赖枚举顺序或界面语言。
    case orangeRicky = "orange_ricky"
    case blueRicky = "blue_ricky"
    case clevelandZ = "cleveland_z"
    case rhodeIslandZ = "rhode_island_z"

    var titleKey: String { "piece.\(rawValue).name" }

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
