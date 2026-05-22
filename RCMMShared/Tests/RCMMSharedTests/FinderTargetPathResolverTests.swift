import Foundation
import Testing
@testable import RCMMShared

@Suite("FinderTargetPathResolver 测试")
struct FinderTargetPathResolverTests {
    @Test("selectedPath 保持原路径")
    func selectedPathKeepsTargetPath() {
        let path = "/Users/example/project/file.swift"

        let result = FinderTargetPathResolver.executionPath(
            for: path,
            executionMode: .selectedPath,
            isDirectory: { _ in false }
        )

        #expect(result == path)
    }

    @Test("currentDirectory 对文件使用父目录")
    func currentDirectoryUsesParentForFile() {
        let result = FinderTargetPathResolver.executionPath(
            for: "/Users/example/project/file.swift",
            executionMode: .currentDirectory,
            isDirectory: { _ in false }
        )

        #expect(result == "/Users/example/project")
    }

    @Test("currentDirectory 对目录使用自身")
    func currentDirectoryUsesDirectoryItself() {
        let result = FinderTargetPathResolver.executionPath(
            for: "/Users/example/project",
            executionMode: .currentDirectory,
            isDirectory: { $0 == "/Users/example/project" }
        )

        #expect(result == "/Users/example/project")
    }

    @Test("targetPolicy containingDirectory 对文件使用父目录")
    func targetPolicyContainingDirectoryUsesParentForFile() {
        let result = FinderTargetPathResolver.executionPath(
            for: "/Users/example/project/file.swift",
            targetPolicy: .containingDirectory,
            isDirectory: { _ in false }
        )

        #expect(result == "/Users/example/project")
    }

    @Test("targetPolicy selectedPath 保持原路径")
    func targetPolicySelectedPathKeepsTargetPath() {
        let path = "/Users/example/project/file.swift"

        let result = FinderTargetPathResolver.executionPath(
            for: path,
            targetPolicy: .selectedPath,
            isDirectory: { _ in false }
        )

        #expect(result == path)
    }
}
