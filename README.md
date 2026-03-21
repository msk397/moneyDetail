# moneydetail

Flutter 记账应用，支持自然语言记账、本地持久化、Notion 云同步与 AI 消费建议。

## 功能特性

- **自然语言记账**：用口语描述消费，AI 自动解析金额、分类、备注
- **多维度总览**：今日 / 本月 / 本年花费，近 12 个月趋势折线图
- **预算管理**：手动设置月度总预算，实时进度条 + 超预算提醒
- **AI 消费建议**：DeepSeek 结合月收支与预算数据，生成个性化理财建议
- **Notion 同步**：将账目同步到个人 Notion 数据库
- **收入支持**：识别收入类记录，单独归档（不计入支出统计）

## 密钥安全设计说明

本项目不在源代码中保存任何明文密钥默认值。所有敏感配置（Notion Token、DeepSeek API Key 等）均通过系统安全存储读写，用户在 App 设置页首次输入后即可正常使用。

### 实现方式

| 层级 | 实现 |
|------|------|
| 存储组件 | flutter_secure_storage 9.2.2，统一封装于 lib/src/infrastructure/settings/secure_settings_store.dart |
| Android | encryptedSharedPreferences: true，底层依赖 Android Keystore 硬件保护密钥 |
| iOS | Keychain，accessibility: first_unlock_this_device，synchronizable: false（禁止 iCloud 同步） |
| 设置页 | 仅从安全存储读取并回填输入框，代码中无任何明文常量默认值 |

### 风险边界

- **普通场景**（反编译、数据导出、抓包）：无法从中获取明文密钥
- **高威胁场景**（Root / Jailbreak / 系统层攻破）：不存在 100% 防提取方案，建议配合系统完整性保护使用

## 开发与运行

```bash
flutter pub get
flutter run
```

## 构建

```bash
flutter build apk --release   # Android
flutter build ios --release   # iOS（需 macOS + Xcode）
```

## 技术栈

- Flutter 3.x / Dart 3.x
- drift — 本地 SQLite ORM
- flutter_riverpod — 状态管理
- flutter_secure_storage — 系统级安全存储
- DeepSeek API — 自然语言解析 + 消费建议
- Notion API — 云同步后端
