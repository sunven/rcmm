import Foundation
import RCMMShared
import Testing
@testable import rcmm

/// MenuConfigStore 保留的领域规则 —— 这些是它没有退化成纯 setter 集合的原因。
@Suite("MenuConfigStore 领域规则", .serialized)
@MainActor
struct MenuConfigStoreTests {
    @Test("具名变更只修改内存，不直接落盘")
    func namedMutationsDoNotPersistDirectly() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let persistedBefore = harness.configService.loadEntries()
        let customID = try #require(store.menuEntries.compactMap { entry -> UUID? in
            guard case .custom(let config) = entry else { return nil }
            return config.id
        }.first)
        let newFileMenuID = try #require(store.primaryNewFileMenu?.id)

        store.updateCustomCommand(
            for: customID,
            command: "echo changed",
            executionMode: .currentDirectory
        )
        let compositeID = store.addEmptyCompositeCommand()
        store.updateCompositeName(for: compositeID, name: "Changed Composite")
        store.addNewFileTemplate(to: newFileMenuID)
        store.moveEntry(from: IndexSet(integer: 0), to: store.menuEntries.endIndex)

        #expect(store.menuEntries != persistedBefore)
        #expect(harness.configService.loadEntries() == persistedBefore)
    }

    @Test("添加应用按非空 bundleId 优先，缺失时按路径去重")
    func deduplicatesApplicationsByBundleThenPath() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        store.menuEntries = [
            .custom(MenuItemConfig(
                appName: "Existing Bundle",
                bundleId: "com.example.editor",
                appPath: "/Applications/OldEditor.app"
            )),
            .custom(MenuItemConfig(
                appName: "Existing No Bundle",
                appPath: "/Applications/NoBundle.app"
            )),
        ]

        let addedIDs = store.addMenuItems(from: [
            AppInfo(
                name: "Same Bundle",
                bundleId: "com.example.editor",
                path: "/Applications/NewEditor.app"
            ),
            AppInfo(
                name: "Same Path No Bundle",
                path: "/Applications/NoBundle.app"
            ),
            AppInfo(
                name: "Different Path No Bundle",
                path: "/Applications/OtherNoBundle.app"
            ),
            AppInfo(
                name: "New Bundle",
                bundleId: "com.example.viewer",
                path: "/Applications/Viewer.app"
            ),
        ])

        #expect(addedIDs.count == 2)
        #expect(store.menuEntries.compactMap { entry -> String? in
            guard case .custom(let item) = entry else { return nil }
            return item.appName
        } == [
            "Existing Bundle",
            "Existing No Bundle",
            "Different Path No Bundle",
            "New Bundle",
        ])
    }

    @Test("删除时跳过 Built-in Entry 和 New File Menu")
    func removeEntrySkipsProtectedKinds() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let protectedIndices = IndexSet(store.menuEntries.indices.filter { index in
            switch store.menuEntries[index] {
            case .builtIn, .newFile: return true
            case .custom, .composite: return false
            }
        })
        #expect(!protectedIndices.isEmpty)
        let idsBefore = store.menuEntries.map(\.id)

        store.removeEntry(at: protectedIndices)

        #expect(store.menuEntries.map(\.id) == idsBefore)
    }

    @Test("删除时移除 Script-Backed Entry")
    func removeEntryRemovesCustomKinds() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let customID = store.menuEntries.first { entry in
            if case .custom = entry { return true }
            return false
        }?.id
        let customIndex = try #require(store.menuEntries.firstIndex { $0.id == customID })

        store.removeEntry(at: IndexSet(integer: customIndex))

        #expect(!store.menuEntries.contains { $0.id == customID })
    }

    @Test("新增模板遇到重名时追加序号")
    func addNewFileTemplateMakesNameUnique() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let menuID = try #require(store.primaryNewFileMenu?.id)

        // 默认模板里已经有 "txt"，新增的同名模板必须让开
        store.addNewFileTemplate(to: menuID)

        let names = try #require(store.primaryNewFileMenu?.templates.map(\.displayName))
        #expect(names.filter { $0 == "txt" }.count == 1)
        #expect(names.contains("txt 2"))
    }

    @Test("重命名 New File Menu 遇到重名时追加序号")
    func renameNewFileMenuMakesNameUnique() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let firstID = try #require(store.primaryNewFileMenu?.id)
        let firstName = try #require(store.primaryNewFileMenu?.name)
        let secondID = UUID()
        store.menuEntries.append(.newFile(NewFileMenuConfig(id: secondID, name: "临时")))

        store.updateNewFileMenuName(for: secondID, name: firstName)

        let renamed = store.menuEntries.compactMap { entry -> NewFileMenuConfig? in
            guard case .newFile(let config) = entry, config.id == secondID else { return nil }
            return config
        }.first
        #expect(renamed?.name == "\(firstName) 2")
        #expect(store.menuEntries.contains { entry in
            guard case .newFile(let config) = entry else { return false }
            return config.id == firstID && config.name == firstName
        })
    }

    @Test("组合命令模板副本遇到重名时追加序号")
    func addCompositeCommandMakesNameUnique() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let firstID = store.addCompositeCommand(
            CompositeMenuItemConfig(name: "编辑器 + Terminal", steps: [])
        )
        let secondID = store.addCompositeCommand(
            CompositeMenuItemConfig(name: "编辑器 + Terminal", steps: [])
        )

        let names = store.menuEntries.compactMap { entry -> String? in
            guard case .composite(let config) = entry,
                  config.id == firstID || config.id == secondID else { return nil }
            return config.name
        }
        #expect(names == ["编辑器 + Terminal", "编辑器 + Terminal 2"])
    }

    @Test("应用步骤保存应用路径、Bundle ID 和首选命令模板")
    func addAppStepStoresApplicationMetadata() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let compositeID = store.addEmptyCompositeCommand()
        let app = AppInfo(
            name: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            path: "/Applications/Visual Studio Code.app",
            category: .editor
        )

        store.addAppStep(to: compositeID, appInfo: app)

        let step = store.menuEntries.compactMap { entry -> CompositeCommandStep? in
            guard case .composite(let config) = entry, config.id == compositeID else { return nil }
            return config.steps.first
        }.first
        #expect(step?.kind == .app)
        #expect(step?.appPath == app.path)
        #expect(step?.bundleId == app.bundleId)
        #expect(step?.commandTemplate == CompositeCommandTemplates.vsCodeCLI)
    }

    @Test("替换应用步骤会更新应用元数据")
    func replaceAppStepUpdatesApplicationMetadata() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let compositeID = store.addEmptyCompositeCommand()
        store.addAppStep(
            to: compositeID,
            appInfo: AppInfo(name: "旧应用", path: "/Applications/Old.app")
        )
        let stepIDs = store.menuEntries.compactMap { entry -> UUID? in
            guard case .composite(let config) = entry, config.id == compositeID else { return nil }
            return config.steps.first?.id
        }
        let stepID = try #require(stepIDs.first)
        let replacement = AppInfo(
            name: "新应用",
            bundleId: "com.example.new",
            path: "/Applications/New.app"
        )

        store.replaceAppStep(compositeId: compositeID, stepId: stepID, appInfo: replacement)

        let step = store.menuEntries.compactMap { entry -> CompositeCommandStep? in
            guard case .composite(let config) = entry, config.id == compositeID else { return nil }
            return config.steps.first
        }.first
        #expect(step?.name == replacement.name)
        #expect(step?.appPath == replacement.path)
        #expect(step?.bundleId == replacement.bundleId)
        #expect(step?.commandTemplate == CompositeCommandTemplates.legacyOpenApp)
    }

    @Test("按 ID 删除组合命令")
    func removeEntryByIDRemovesComposite() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = harness.makeConfigStore()
        let compositeID = store.addEmptyCompositeCommand()

        store.removeEntry(withID: compositeID.uuidString)

        #expect(!store.menuEntries.contains { $0.id == compositeID.uuidString })
    }
}
