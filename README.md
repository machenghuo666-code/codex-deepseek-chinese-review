# Codex DeepSeek 中文审稿 Skill

让 Codex 保持使用 OpenAI 模型处理主要工作，并在用户明确说“DeepSeek”时，通过本机 OpenCode 调用 DeepSeek V4 Flash 或 V4 Pro 进行只读中文审稿，结果返回原 Codex 对话。

它不会把 DeepSeek 添加到 Codex 桌面版的模型下拉菜单，也不会修改 `~/.codex/config.toml`。

## 工作方式

```text
Codex 对话
  └─ deepseek-chinese-review Skill
       └─ 本机 OpenCode CLI
            ├─ DeepSeek V4 Flash（默认）
            └─ DeepSeek V4 Pro（明确要求时）
```

安全边界：

- 只发送用户明确指定的文本或文件，不扫描整个项目。
- OpenCode 审稿代理禁止 Shell、编辑、联网工具和子代理。
- 临时输入目录权限为 `700`，调用结束后删除。
- 不读取、打印或保存 API Key；认证由 OpenCode 自己管理。
- 多篇文案逐篇串行处理，失败时停止，不自动重试。
- 只有收到完整结束标记和非空正文，才把结果标记为 DeepSeek 审阅意见。

## 当前模型

- 默认：`deepseek/deepseek-v4-flash`
- 深度复核：`deepseek/deepseek-v4-pro`

OpenCode 使用 `provider/model` 写法；DeepSeek 官方 API 模型名分别是 `deepseek-v4-flash` 和 `deepseek-v4-pro`。发布时已按 [DeepSeek 官方更新日志](https://api-docs.deepseek.com/updates/) 核对。

## 前置条件

- macOS
- Codex 桌面版、CLI 或 IDE 扩展
- 已安装并配置 OpenCode
- 已在 OpenCode 中完成 DeepSeek 登录或 API Key 配置
- 系统提供 `zsh`、`jq` 和 `perl`（macOS 默认可用）

API Key 请始终在本机 OpenCode 登录流程中亲自输入，不要写入仓库、命令参数或聊天。

## 安装

```zsh
git clone https://github.com/machenghuo666-code/codex-deepseek-chinese-review.git
cd codex-deepseek-chinese-review
./install.sh
```

安装脚本只会复制：

- Skill → `$HOME/.agents/skills/deepseek-chinese-review`
- OpenCode agents → `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents/`

如果目标已存在，安装脚本会停止，不会覆盖。Codex 通常会自动发现 Skill；若未出现，重启 Codex。

## 使用

在 Codex 对话中直接说：

```text
DeepSeek：审阅上面的中文文案，只给修改建议，不修改文件。
```

深度复核：

```text
DeepSeek Pro：深度复核上面的中文文案，只给修改建议。
```

也可以显式调用：

```text
$deepseek-chinese-review
```

## 自定义

如果 OpenCode 不在 `PATH`，可以设置：

```zsh
export OPENCODE_BIN="/absolute/path/to/opencode"
```

模型映射也可以覆盖：

```zsh
export DEEPSEEK_FLASH_MODEL="deepseek/deepseek-v4-flash"
export DEEPSEEK_PRO_MODEL="deepseek/deepseek-v4-pro"
```

## 说明

这是一个本机桥接型 Skill。Codex 仍是总控模型；DeepSeek 只承担用户明确点名的中文内容复核。

Codex Skill 的目录结构、自动触发和用户级安装位置参考 [OpenAI 官方 Skill 文档](https://learn.chatgpt.com/docs/build-skills)。
