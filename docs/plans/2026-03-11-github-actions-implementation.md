# GitHub Actions 自动打包实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建 GitHub Actions workflow，在推送 Git tag 时自动构建未签名的 macOS .dmg 并发布到 GitHub Release

**Architecture:** 使用 xcodebuild 构建 Release archive，从 archive 中提取 .app，使用 create-dmg action 生成 DMG，最后通过 gh CLI 创建 GitHub Release 并上传产物

**Tech Stack:** GitHub Actions, xcodebuild, create-dmg, gh CLI

---

## Task 1: 创建 GitHub Actions 工作流目录结构

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: 创建目录结构**

```bash
mkdir -p .github/workflows
```

**Step 2: 验证目录创建成功**

Run: `ls -la .github/workflows`
Expected: 显示空目录

**Step 3: 提交目录结构**

```bash
git add .github/workflows/.gitkeep
touch .github/workflows/.gitkeep
git add .github/workflows/.gitkeep
git commit -m "chore: create GitHub Actions workflows directory"
```

---

## Task 2: 创建 Release Workflow 基础结构

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: 创建 workflow 文件头部**

```yaml
name: Release Build

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build:
    name: Build and Release
    runs-on: macos-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
```

**Step 2: 验证 YAML 语法**

Run: `cat .github/workflows/release.yml`
Expected: 显示完整的 YAML 内容，无语法错误

**Step 3: 提交基础结构**

```bash
git add .github/workflows/release.yml
git commit -m "chore: add release workflow skeleton"
```

---

## Task 3: 添加 Xcode 版本选择步骤

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 在 checkout 后添加 Xcode 选择步骤**

在 `- name: Checkout code` 后添加：

```yaml
      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_15.4.app/Contents/Developer
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 2 "Select Xcode"`
Expected: 显示 Xcode 选择步骤

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add Xcode version selection step"
```

---

## Task 4: 添加版本号提取步骤

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 添加版本号提取步骤**

在 Xcode 选择步骤后添加：

```yaml
      - name: Extract version from tag
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Version: $VERSION"
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 5 "Extract version"`
Expected: 显示版本提取步骤

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add version extraction from git tag"
```

---

## Task 5: 添加 Archive 构建步骤

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 添加 archive 构建步骤**

在版本提取步骤后添加：

```yaml
      - name: Build archive
        run: |
          xcodebuild archive \
            -project rcmm.xcodeproj \
            -scheme rcmm \
            -configuration Release \
            -archivePath build/rcmm.xcarchive \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 10 "Build archive"`
Expected: 显示完整的 xcodebuild 命令

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add xcodebuild archive step"
```

---

## Task 6: 添加 .app 提取和验证步骤

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 添加 .app 提取步骤**

在 archive 构建步骤后添加：

```yaml
      - name: Extract .app from archive
        run: |
          cp -R build/rcmm.xcarchive/Products/Applications/rcmm.app build/rcmm.app

      - name: Verify .app structure
        run: |
          test -d build/rcmm.app || exit 1
          test -d build/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex || exit 1
          test -f build/rcmm.app/Contents/Info.plist || exit 1
          echo "✓ App structure verified"
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 8 "Extract .app"`
Expected: 显示提取和验证步骤

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add app extraction and verification steps"
```

---

## Task 7: 添加 DMG 生成步骤

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 添加 create-dmg action**

在验证步骤后添加：

```yaml
      - name: Create DMG
        uses: create-dmg/create-dmg@v1
        with:
          name: rcmm-${{ steps.version.outputs.version }}.dmg
          src: build/rcmm.app
          dmg_name: rcmm-${{ steps.version.outputs.version }}
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 5 "Create DMG"`
Expected: 显示 create-dmg action 配置

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add DMG creation step"
```

---

## Task 8: 添加 GitHub Release 发布步骤

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 添加 release 创建步骤**

在 DMG 创建步骤后添加：

```yaml
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create ${{ github.ref_name }} \
            rcmm-${{ steps.version.outputs.version }}.dmg \
            --title "rcmm ${{ steps.version.outputs.version }}" \
            --generate-notes
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 7 "Create GitHub Release"`
Expected: 显示 gh release 命令

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Release creation step"
```

---

## Task 9: 添加构建日志上传（调试用）

**Files:**
- Modify: `.github/workflows/release.yml`

**Step 1: 在文件末尾添加失败时的日志上传**

在最后一个步骤后添加：

```yaml
      - name: Upload build logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: build-logs
          path: |
            build/
            DerivedData/
          retention-days: 7
```

**Step 2: 验证修改**

Run: `cat .github/workflows/release.yml | grep -A 8 "Upload build logs"`
Expected: 显示 artifact 上传配置

**Step 3: 提交修改**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add build logs upload on failure"
```

---

## Task 10: 验证完整 Workflow 文件

**Files:**
- Verify: `.github/workflows/release.yml`

**Step 1: 检查完整文件内容**

Run: `cat .github/workflows/release.yml`
Expected: 显示包含所有步骤的完整 workflow

**Step 2: 验证 YAML 语法**

Run: `yamllint .github/workflows/release.yml 2>/dev/null || python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
Expected: 无语法错误

**Step 3: 推送到远程仓库**

```bash
git push origin main
```

---

## Task 11: 创建测试 Tag 验证流程

**Files:**
- None (Git operations only)

**Step 1: 创建测试 tag**

```bash
git tag v0.0.1-test
```

**Step 2: 推送 tag 触发 workflow**

```bash
git push origin v0.0.1-test
```

**Step 3: 监控 workflow 执行**

Run: `gh run list --workflow=release.yml --limit 1`
Expected: 显示正在运行或已完成的 workflow

**Step 4: 检查 workflow 状态**

Run: `gh run watch`
Expected: 实时显示 workflow 执行进度

**Step 5: 验证 Release 创建成功**

Run: `gh release view v0.0.1-test`
Expected: 显示 release 信息和 DMG 下载链接

---

## Task 12: 更新 README 添加发布说明

**Files:**
- Modify: `README.md` (如果存在) 或 Create: `README.md`

**Step 1: 检查 README 是否存在**

Run: `test -f README.md && echo "exists" || echo "not found"`

**Step 2: 添加发布说明章节**

在 README.md 中添加（如果文件不存在则创建）：

```markdown
## 发布流程

本项目使用 GitHub Actions 自动构建和发布。

### 创建新版本

1. 确保所有更改已提交到 main 分支
2. 创建并推送版本 tag：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions 将自动：
   - 构建 Release 版本
   - 生成 .dmg 安装包
   - 创建 GitHub Release
   - 上传 DMG 作为 release asset

### 下载

访问 [Releases 页面](https://github.com/sunven/rcmm/releases) 下载最新版本的 DMG 文件。

### 安装

1. 下载 `rcmm-x.x.x.dmg`
2. 打开 DMG 文件
3. 将 rcmm.app 拖拽到 Applications 文件夹
4. 首次运行时右键点击应用选择"打开"（因为应用未签名）
```

**Step 3: 验证修改**

Run: `cat README.md | grep -A 5 "发布流程"`
Expected: 显示发布说明章节

**Step 4: 提交修改**

```bash
git add README.md
git commit -m "docs: add release process documentation"
```

---

## 验证清单

完成所有任务后，验证以下内容：

- [ ] `.github/workflows/release.yml` 文件存在且语法正确
- [ ] Workflow 包含所有必需步骤（checkout、xcodebuild、create-dmg、gh release）
- [ ] 权限配置正确（`contents: write`）
- [ ] 测试 tag 触发成功构建
- [ ] GitHub Release 页面显示 DMG 下载链接
- [ ] DMG 文件可以正常下载和打开
- [ ] README 包含发布说明

---

## 故障排查

### 如果 workflow 失败：

1. **查看 Actions 日志**
   ```bash
   gh run view --log
   ```

2. **常见问题：**
   - SPM 依赖解析失败 → 检查网络连接和依赖版本
   - Archive 失败 → 检查 Xcode 版本和项目配置
   - DMG 创建失败 → 检查 .app 结构是否完整
   - Release 创建失败 → 检查 `GITHUB_TOKEN` 权限

3. **下载构建日志**
   ```bash
   gh run download <run-id> -n build-logs
   ```

### 如果需要删除测试 tag：

```bash
git tag -d v0.0.1-test
git push origin :refs/tags/v0.0.1-test
gh release delete v0.0.1-test --yes
```

---

## 未来改进

完成基础流程后，可以考虑：

1. **添加代码签名** — 需要 Apple Developer 账号和证书
2. **添加公证** — 使用 `xcrun notarytool`
3. **自定义 DMG 外观** — 添加背景图片和图标布局
4. **添加 changelog 自动生成** — 使用 conventional commits
5. **添加版本号自动递增** — 基于 commit 类型
