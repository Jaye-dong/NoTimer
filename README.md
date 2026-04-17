# NoTimer

一个和 Notion 双向同步的 iOS 时间追踪 app：从"下一步行动"一键开始计时，停止后自动在"时间记录"数据库生成条目。支持 Live Activity / 灵动岛 / 主屏小组件 / 后台同步。

- **平台**：iOS 17+
- **UI**：SwiftUI
- **存储**：GRDB.swift（本地 SQLite，local-first）
- **同步**：自建 Notion REST 客户端，Internal Integration Token
- **仓库**：`jaye-dong/notimer`
- **开发分支**：`claude/ios-time-tracker-notion-LDtkG`

## 目录

```
NoTimer/
├── App/              # @main 入口、依赖容器
├── Core/
│   ├── Database/     # GRDB 数据库、Model、Repository
│   ├── Notion/       # Notion REST 客户端、JSON Mapper
│   ├── Keychain/     # Token 安全存储
│   ├── Sync/         # 同步引擎（后续里程碑）
│   └── Timer/        # 计时控制器（后续里程碑）
├── Features/
│   ├── Home/         # 当前计时 + 快速启动
│   ├── NextActions/  # 下一步行动列表
│   ├── TimeRecords/  # 时间记录列表与编辑
│   ├── Stats/        # 统计图表
│   └── Settings/     # Notion 连接配置
└── Resources/        # Info.plist、Entitlements、Assets
```

## 开发环境

- macOS + Xcode 15.3+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

## 首次生成 Xcode 工程

```bash
cd NoTimer
xcodegen generate
open NoTimer.xcodeproj
```

XcodeGen 会读取仓库根目录的 `project.yml` 并生成 `.xcodeproj`。工程文件不进版本库。

Xcode 首次打开会自动解析 Swift Package Manager 依赖（GRDB.swift）。

## 配置 Notion Integration

1. 浏览器打开 <https://www.notion.so/profile/integrations>，点击 **New integration**
2. 类型选 **Internal**，取名 `NoTimer`，工作区选你自己的
3. 创建后复制 **Internal Integration Secret**（以 `secret_` 或 `ntn_` 开头）
4. 回到你的 **时间记录数据库** 页面，右上角 `···` → **Connections** → 搜 `NoTimer` → 连接；对 **下一步行动数据库** 做同样操作
5. 打开 app，进入 **Settings** Tab → 粘贴 Token → 粘贴两个数据库 URL → 点 **验证连接**

## 当前进度（M1）

- [x] 仓库骨架 + XcodeGen 配置 + GRDB 依赖
- [x] 本地数据库 schema + Model + Repository
- [x] Notion REST 客户端（`GET /v1/databases/{id}` 验证连接）
- [x] Keychain 安全存储 Integration Token
- [x] Settings 页（粘贴 token、填数据库 URL、验证）
- [x] Home / NextActions / TimeRecords / Stats 页面占位

后续里程碑见 `/root/.claude/plans/notion-ios-app-notion-timer-notion-frolicking-seahorse.md`：

- M2 拉取展示（全量拉 Notion → 本地只读展示）
- M3 计时核心（启停、Live Activity）
- M4 推送同步（双向、冲突）
- M5 小组件 + 后台任务
- M6 统计图表
- M7 打磨
