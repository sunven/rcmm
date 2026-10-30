import Testing
@testable import RCMMShared

@Suite("PopoverState 布局测试")
struct PopoverStateTests {
    @Test("异常恢复面板使用更宽的弹层宽度")
    func healthWarningUsesWiderPopover() {
        #expect(PopoverState.normal.preferredPopoverWidth == 260)
        #expect(PopoverState.onboarding.preferredPopoverWidth == 260)
        #expect(PopoverState.healthWarning.preferredPopoverWidth == 360)
    }
}
