import SwiftUI

struct OpenSettingsButton<Label: View>: View {
    @Environment(\.openSettings) private var openSettings

    private let preAction: () -> Void
    private let postAction: () -> Void
    private let label: Label

    init(
        preAction: @escaping () -> Void = {},
        postAction: @escaping () -> Void = {},
        @ViewBuilder label: () -> Label
    ) {
        self.preAction = preAction
        self.postAction = postAction
        self.label = label()
    }

    var body: some View {
        Button {
            preAction()
            openSettings()
            postAction()
        } label: {
            label
        }
    }
}
