# GitHub Actions 自动打包设计方案

**日期：** 2026-03-11
**项目：** rcmm (Right Click Menu Manager)
**目标：** 在 Git tag 推送时自动构建未签名的 macOS .dmg 并发布到 GitHub Release

---

## 需求概述

- **触发时机：** 仅在创建 Git tag（格式 `v*`）时触发
- **签名策略：** 暂不签名，先搭建构建流程
- **产物格式：** .dmg 磁盘镜像
- **发布方式：** 自动创建 GitHub Release 并上传 DMG

---

## 方案选择

### 对比的方案

1. **纯 xcodebuild + create-dmg（已选择）**
   - 最简单直接，无额外依赖
   - `create-dmg` 是社区标准工具
   - 完全控制构建参数

2. **fastlane 自动化**
   - 一站式解决方案，但对简单项目过度工程化
   - 需要学习 fastlane DSL

3. **xcodebuild + appdmg**
   - 需要 Node.js 环境
   - `appdmg` 维护不如 `create-dmg` 活跃

### 选择理由

选择方案 1 的原因：
- 项目结构清晰，不需要复杂工具链
- `create-dmg` 是 macOS 开源项目的事实标准
- 纯 shell 脚本 + GitHub Actions，易于维护
- 未来需要签名时，只需添加 `-CODE_SIGN_IDENTITY` 参数

---

## 整体架构

### 触发机制
- **触发条件：** 推送 Git tag（格式：`v*`，如 `v1.0.0`）
- **运行环境：** `macos-latest`（GitHub-hosted runner，当前为 macOS 14）

### 构建流程
```
1. Checkout 代码
2. 选择 Xcode 版本（15.4+，支持 Swift 6）
3. 解析 SPM 依赖（RCMMShared + SettingsAccess）
4. Archive 构建（Release 配置）
5. 导出 .app（不签名）
6. 生成 .dmg
7. 创建 GitHub Release 并上传
```

### 关键决策
- **不使用 `xcodebuild -exportArchive`** — 未签名构建可直接从 archive 中提取 .app
- **SPM 依赖自动解析** — `xcodebuild` 会自动处理本地包和远程依赖
- **版本号提取** — 从 Git tag 中提取（去掉 `v` 前缀）用于命名产物

---

## 构建步骤详解

### 1. Archive 构建
```bash
xcodebuild archive \
  -project rcmm.xcodeproj \
  -scheme rcmm \
  -configuration Release \
  -archivePath build/rcmm.xcarchive \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

**关键点：**
- 使用 `rcmm` scheme（会自动包含 `RCMMFinderExtension` 依赖）
- 禁用代码签名的三个参数缺一不可
- Archive 会包含 .app 和 .appex（扩展）

### 2. 提取 .app
```bash
cp -R build/rcmm.xcarchive/Products/Applications/rcmm.app build/rcmm.app
```

### 3. 生成 DMG
使用 `create-dmg` GitHub Action：
```yaml
- uses: create-dmg/create-dmg@v1
  with:
    name: rcmm-${{ version }}.dmg
    src: build/rcmm.app
    dmg_name: rcmm-${{ version }}
```

**DMG 默认行为：**
- 自动创建 `/Applications` 快捷方式
- 窗口大小自适应
- 无自定义背景（可后续添加）

### 4. 发布 Release
```bash
gh release create ${{ github.ref_name }} \
  rcmm-${{ version }}.dmg \
  --title "rcmm ${{ version }}" \
  --generate-notes
```

**自动生成内容：**
- Release notes（基于 commits）
- 上传 DMG 作为 asset

---

## 错误处理与验证

### 构建验证
在生成 DMG 前验证 .app 结构：
```bash
# 检查主应用
test -d build/rcmm.app || exit 1

# 检查扩展是否正确嵌入
test -d build/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex || exit 1

# 检查 Info.plist 存在
test -f build/rcmm.app/Contents/Info.plist || exit 1
```

### 失败场景处理
| 场景 | 处理方式 |
|------|---------|
| SPM 依赖解析失败 | 构建失败，GitHub Actions 自动标记为 failed |
| Archive 失败 | 构建失败，检查 Xcode 版本兼容性 |
| DMG 生成失败 | 构建失败，检查 .app 结构 |
| Release 创建失败 | 构建失败，检查 `GITHUB_TOKEN` 权限 |

### 权限配置
Workflow 需要写权限：
```yaml
permissions:
  contents: write  # 创建 Release 和上传 assets
```

### 测试策略
- **首次运行：** 创建测试 tag（如 `v0.0.1-test`）验证流程
- **失败调试：** 上传 build log 作为 artifact
- **成功标志：** GitHub Release 页面出现 DMG 下载链接

---

## 未来扩展

### 添加代码签名（未来）
在 Archive 步骤添加：
```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
CODE_SIGNING_REQUIRED=YES \
CODE_SIGNING_ALLOWED=YES
```

需要在 GitHub Secrets 中配置：
- `APPLE_CERTIFICATE_BASE64`（证书 p12 文件）
- `APPLE_CERTIFICATE_PASSWORD`（证书密码）
- `KEYCHAIN_PASSWORD`（临时 keychain 密码）

### 添加公证（未来）
使用 `xcrun notarytool`：
```bash
xcrun notarytool submit rcmm.dmg \
  --apple-id "$APPLE_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait
```

### 自定义 DMG 外观（可选）
`create-dmg` 支持：
- 自定义背景图片
- 自定义窗口大小和图标位置
- 自定义卷标图标

---

## 实施清单

- [ ] 创建 `.github/workflows/release.yml`
- [ ] 配置 workflow 权限（`contents: write`）
- [ ] 实现构建步骤（archive、提取、验证）
- [ ] 集成 `create-dmg` action
- [ ] 配置 GitHub Release 自动发布
- [ ] 创建测试 tag 验证流程
- [ ] 更新 README 添加发布说明

---

## 参考资料

- [create-dmg GitHub Action](https://github.com/create-dmg/create-dmg)
- [xcodebuild man page](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
- [GitHub Actions - Publishing releases](https://docs.github.com/en/actions/publishing-packages-and-containers/publishing-releases)
