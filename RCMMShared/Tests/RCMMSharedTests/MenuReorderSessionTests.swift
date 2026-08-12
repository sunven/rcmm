import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuReorderSession 测试")
struct MenuReorderSessionTests {
    /// 三行等高列表：A[0,10) B[10,20) C[20,30)
    private let rows = [
        MenuRowBounds(minY: 0, maxY: 10),
        MenuRowBounds(minY: 10, maxY: 20),
        MenuRowBounds(minY: 20, maxY: 30),
    ]
    private let order = ["A", "B", "C"]

    private func session(dragging id: String) -> MenuReorderSession {
        MenuReorderSession(draggedID: id, order: order)!
    }

    // MARK: - 构造

    @Test("被拖拽项不在列表中时构造失败")
    func initFailsWhenDraggedItemMissing() {
        #expect(MenuReorderSession(draggedID: "Z", order: order) == nil)
    }

    @Test("刚开始拖拽时顺序未变")
    func startsUnchanged() {
        let session = session(dragging: "A")
        #expect(session.currentOrder == order)
        #expect(session.hasReordered == false)
    }

    // MARK: - 命中测试

    @Test("光标落在列表上边界之外时命中首行")
    func aboveListHitsFirstRow() {
        #expect(MenuReorderSession.targetIndex(atY: -50, rows: rows) == 0)
    }

    @Test("光标落在列表下边界之外时命中末行")
    func belowListHitsLastRow() {
        #expect(MenuReorderSession.targetIndex(atY: 999, rows: rows) == 2)
    }

    @Test("行高不等时按各自范围命中")
    func hitTestDoesNotAssumeUniformRowHeight() {
        let unevenRows = [
            MenuRowBounds(minY: 0, maxY: 8),
            MenuRowBounds(minY: 8, maxY: 60),
            MenuRowBounds(minY: 60, maxY: 68),
        ]

        #expect(MenuReorderSession.targetIndex(atY: 4, rows: unevenRows) == 0)
        #expect(MenuReorderSession.targetIndex(atY: 40, rows: unevenRows) == 1)
        #expect(MenuReorderSession.targetIndex(atY: 64, rows: unevenRows) == 2)
    }

    @Test("没有任何行时命中为空")
    func hitTestWithoutRows() {
        #expect(MenuReorderSession.targetIndex(atY: 5, rows: []) == nil)
    }

    @Test("rows 相对当前顺序滞后一帧时不来回抖动")
    func staleRowBoundsDoNotCauseJitter() {
        var session = session(dragging: "A")

        // 第一次拖到第二行：A 与 B 交换
        #expect(session.drag(toY: 15, rows: rows) == ["B", "A", "C"])
        // rows 尚未随新顺序更新，光标仍停在第二行 —— A 已经在那儿了，不该再动
        #expect(session.drag(toY: 15, rows: rows) == nil)
        #expect(session.currentOrder == ["B", "A", "C"])
    }

    // MARK: - 拖拽推演

    @Test("向下拖到相邻行，两者交换")
    func dragDownSwapsWithNeighbour() {
        var session = session(dragging: "A")

        #expect(session.drag(toY: 15, rows: rows) == ["B", "A", "C"])
        #expect(session.hasReordered)
    }

    @Test("向上拖到相邻行，两者交换")
    func dragUpSwapsWithNeighbour() {
        var session = session(dragging: "C")

        #expect(session.drag(toY: 15, rows: rows) == ["A", "C", "B"])
    }

    @Test("拖到自己身上不产生变化")
    func draggingOntoSelfIsNoop() {
        var session = session(dragging: "A")

        #expect(session.drag(toY: 5, rows: rows) == nil)
        #expect(session.hasReordered == false)
    }

    @Test("连续跨越多行后顺序正确")
    func dragAcrossMultipleRows() {
        var session = session(dragging: "A")

        _ = session.drag(toY: 15, rows: rows)
        #expect(session.drag(toY: 25, rows: rows) == ["B", "C", "A"])
        #expect(session.currentOrder == ["B", "C", "A"])
    }

    @Test("拖到列表外后夹到端点")
    func dragOutsideListClampsToEnds() {
        var session = session(dragging: "C")

        #expect(session.drag(toY: -100, rows: rows) == ["C", "A", "B"])
        #expect(session.drag(toY: 100, rows: rows) == ["A", "B", "C"])
    }

    @Test("拖走再拖回原位视为未改变")
    func draggingBackToOriginIsNotAChange() {
        var session = session(dragging: "A")

        _ = session.drag(toY: 15, rows: rows)
        #expect(session.hasReordered)

        _ = session.drag(toY: 5, rows: rows)
        #expect(session.currentOrder == order)
        #expect(session.hasReordered == false)
    }

    @Test("只有一个菜单项时拖拽不产生意图")
    func singleItemProducesNoIntent() {
        var session = MenuReorderSession(draggedID: "A", order: ["A"])!
        let singleRow = [MenuRowBounds(minY: 0, maxY: 10)]

        #expect(session.drag(toY: -100, rows: singleRow) == nil)
        #expect(session.drag(toY: 100, rows: singleRow) == nil)
        #expect(session.hasReordered == false)
    }

    @Test("行边界比列表短时不越界且不改变顺序")
    func partialRowBoundsAreTolerated() {
        var session = session(dragging: "A")
        // 只有首行的边界回传了
        let partialRows = [MenuRowBounds(minY: 0, maxY: 10)]

        #expect(session.drag(toY: 100, rows: partialRows) == nil)
        #expect(session.hasReordered == false)
    }

    // MARK: - 取消

    @Test("取消恢复到原始顺序")
    func cancelRestoresOriginalOrder() {
        var session = session(dragging: "A")
        _ = session.drag(toY: 25, rows: rows)

        #expect(session.currentOrder == ["B", "C", "A"])
        #expect(session.cancelled() == order)
    }
}
