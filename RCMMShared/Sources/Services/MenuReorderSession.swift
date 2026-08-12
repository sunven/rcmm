import Foundation

/// 列表中一行在纵向上的范围，**按位置从上到下**排列。
///
/// 命中测试只用得到 y —— 因此这里不引入 CoreGraphics 的二维类型，
/// 视图侧把 `CGRect` 压成这个结构再交进来。
///
/// 刻意不带 id：命中按**位置**而非行身份判定，见 `targetIndex(atY:rows:)`。
/// 调用方必须按 `minY` 排序后再交进来，而不是按当前顺序 —— 顺序会在拖拽中变，位置不会。
public struct MenuRowBounds: Equatable, Sendable {
    public let minY: Double
    public let maxY: Double

    public init(minY: Double, maxY: Double) {
        self.minY = minY
        self.maxY = maxY
    }
}

/// 拖拽重排的过程态。
///
/// 只管顺序：输入行边界与光标纵坐标，输出目标顺序。刻意**不**认识 `MenuEntry`、
/// 不管选中项、不算 overlay 几何、也没有时钟 —— 这些要么是视图状态，要么是渲染细节。
///
/// 取消时只恢复顺序而不覆盖内容：拖拽期间若别处改动了菜单项，
/// 「取消这次拖拽」不该等于「把配置整体倒回拖拽开始前」。
public struct MenuReorderSession: Equatable, Sendable {
    public let draggedID: String
    public let originalOrder: [String]
    public private(set) var currentOrder: [String]

    /// 被拖拽项不在列表中时返回 nil。
    public init?(draggedID: String, order: [String]) {
        guard order.contains(draggedID) else { return nil }
        self.draggedID = draggedID
        self.originalOrder = order
        self.currentOrder = order
    }

    /// 顺序相对拖拽开始时是否已改变。松手时据此决定要不要提交。
    public var hasReordered: Bool {
        currentOrder != originalOrder
    }

    /// 光标移动到 `y`。顺序发生变化时返回新顺序，否则返回 nil。
    public mutating func drag(toY y: Double, rows: [MenuRowBounds]) -> [String]? {
        guard let targetIndex = Self.targetIndex(atY: y, rows: rows),
              targetIndex < currentOrder.count,
              let sourceIndex = currentOrder.firstIndex(of: draggedID),
              targetIndex != sourceIndex else {
            return nil
        }

        var next = currentOrder
        next.remove(at: sourceIndex)
        next.insert(draggedID, at: targetIndex)

        guard next != currentOrder else { return nil }
        currentOrder = next
        return next
    }

    /// 取消拖拽应当恢复到的顺序。
    public func cancelled() -> [String] {
        originalOrder
    }

    /// 光标落在第几行上。光标在列表范围之外时夹到最近的首行或末行。
    ///
    /// 按位置而非行身份判定：拖拽期间行的几何位置是稳定的，变的只是谁占据哪个位置。
    /// 因此即便 `rows` 相对当前顺序滞后一帧，也不会来回抖动。不假设各行等高。
    public static func targetIndex(atY y: Double, rows: [MenuRowBounds]) -> Int? {
        guard let first = rows.first, let last = rows.last else {
            return nil
        }

        if y < first.minY {
            return 0
        }
        if y > last.maxY {
            return rows.count - 1
        }

        return rows.firstIndex { y >= $0.minY && y <= $0.maxY }
    }
}
