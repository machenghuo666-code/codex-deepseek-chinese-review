# Codex DeepSeek 中文审稿 Skill

[![test](https://github.com/machenghuo666-code/codex-deepseek-chinese-review/actions/workflows/test.yml/badge.svg)](https://github.com/machenghuo666-code/codex-deepseek-chinese-review/actions/workflows/test.yml)

让 OpenAI Codex 继续承担项目总控，只在用户明确点名 `DeepSeek` 时，通过本机 OpenCode 调用 DeepSeek V4 Flash 或 V4 Pro，对指定中文内容进行只读审稿，并把结果带回原 Codex 对话。

这不是 Codex 模型下拉菜单扩展，不会把 DeepSeek 注入 OpenAI 模型列表，也不会修改 `~/.codex/config.toml`。

## 特性

- `DeepSeek` 默认路由到 V4 Flash；`DeepSeek Pro` 明确路由到 V4 Pro。
- 只提交用户指定的文本或文件，不扫描整个项目或对话历史。
- OpenCode agent 禁止 Shell、编辑、子代理和额外工具调用。
- API Key 继续由 OpenCode 管理；脚本不读取、不打印、不写入仓库。
- 只接受“完整停止事件 + 非空正文”为成功结果。
- 能区分模型失败、超时、不完整返回和 Codex 工作区沙箱拦截。
- 多篇内容串行处理，首次失败即停止，不自动重复消耗额度。
- 提供安全升级、备份、只读 doctor 和确定性测试。

## 模型

| 用法 | OpenCode 模型 | 适合场景 |
| --- | --- | --- |
| `DeepSeek` | `deepseek/deepseek-v4-flash` | 日常快速审稿 |
| `DeepSeek Pro` | `deepseek/deepseek-v4-pro` | 最终稿、逻辑与风险复核 |

模型名已于 2026-08-21 对照 [DeepSeek 官方更新日志](https://api-docs.deepseek.com/updates/) 和 [OpenCode 集成说明](https://api-docs.deepseek.com/quick_start/agent_integrations/opencode) 核对。官方建议 OpenCode 版本不低于 `1.14.24`。

## 工作方式

```text
Codex 项目对话
  └─ deepseek-chinese-review Skill
       └─ 本机 OpenCode CLI
            ├─ DeepSeek V4 Flash（默认）
            └─ DeepSeek V4 Pro（明确要求时）
```

DeepSeek 只提供独立审稿意见；是否采纳、如何修改以及项目文件变更仍由 Codex 和用户决定。

## 前置条件

- macOS
- Codex 桌面版、CLI 或 IDE 扩展
- 建议 OpenCode `>= 1.14.24`
- 已在 OpenCode 中完成 DeepSeek `/connect` 和 API Key 配置
- 可用的 `zsh`、`perl` 与 `jq`

`jq` 不是所有 macOS 环境都预装。安装前可先运行 `command -v jq` 检查。

API Key 必须在本机 OpenCode 登录流程中亲自输入，不要放入聊天、项目文件、Git、命令参数或截图。

## 安装与升级

首次安装：

```zsh
git clone https://github.com/machenghuo666-code/codex-deepseek-chinese-review.git
cd codex-deepseek-chinese-review
./install.sh
```

升级已有版本：

```zsh
git pull --ff-only
./install.sh --update
```

默认安装遇到已有文件会停止，不会覆盖。`--update` 会先把现有 Skill 和两个 OpenCode agent 备份到：

```text
~/.local/share/codex-deepseek-review/backups/<timestamp>/
```

安装脚本只写入：

- `$HOME/.agents/skills/deepseek-chinese-review/`
- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents/`

它不会修改 `~/.codex/config.toml`，也不会读取或迁移 API Key。

## 使用

在任何本机 Codex 项目对话中直接说：

```text
DeepSeek：看看上面这段文案，给修改建议，不修改原文。
```

需要深度复核时：

```text
DeepSeek Pro：深度复核紧邻上面的简介，给建议，不修改原文。
```

Flash 通常更快，适合日常使用；Pro 推理更深、耗时也更长。

### Codex 权限提示

OpenCode 需要写入自己的本机状态目录并访问 DeepSeek API。在 Codex `workspace-write` 模式下，每次调用应通过 `on-request` 授权在工作区沙箱外执行。

如果没有授权，桥接会返回明确的“工作区沙箱阻止”提示，并说明尚未进入模型请求；这不应被报告成 DeepSeek 模型失败。

## 健康检查

doctor 不调用模型、不产生 API 费用，也不会读取 API Key 内容：

```zsh
~/.agents/skills/deepseek-chinese-review/scripts/doctor.sh
```

它检查：OpenCode、`jq`、脚本语法与权限、Flash/Pro 路由、agent 文件以及凭据文件权限。

## 错误语义

| 退出码 | 含义 | 建议 |
| --- | --- | --- |
| `0` | 已验证完整结果 | 正常返回审稿意见 |
| `2` | 用法、空输入或参数错误 | 修正输入，不重试模型 |
| `3` | 文件边界或大小被安全拒绝 | 缩小或重新指定目标 |
| `70` | 没有完整停止标记或正文 | 停止，不冒充结果 |
| `77` | Codex 工作区沙箱阻止 OpenCode 启动 | 按 `on-request` 授权后执行一次 |
| `124` | 超时 | 停止，由用户决定是否重试 |
| `127` | 缺少 OpenCode 或 `jq` | 修复本机依赖 |

OpenCode 偶尔会在已经输出完整正文后以非零状态收尾。桥接会优先验证结构化完成事件：完整结果仍返回成功，不完整结果仍失败。

## 本地测试

测试使用假的 OpenCode 可执行文件，不访问网络、不调用 DeepSeek、不读取 API Key：

```zsh
./tests/run.sh
```

覆盖完整结果、非零收尾、不完整输出、沙箱拦截、Pro 路由、空输入、超大文件和凭据文件名拒绝。GitHub Actions 在 macOS runner 上执行同一组测试。

## 自定义

OpenCode 不在 `PATH` 时：

```zsh
export OPENCODE_BIN="/absolute/path/to/opencode"
```

可调整等待上限与最大输入字节数：

```zsh
export DEEPSEEK_FLASH_TIMEOUT=240
export DEEPSEEK_PRO_TIMEOUT=420
export DEEPSEEK_MAX_INPUT_BYTES=200000
```

如需覆盖模型映射：

```zsh
export DEEPSEEK_FLASH_MODEL="deepseek/deepseek-v4-flash"
export DEEPSEEK_PRO_MODEL="deepseek/deepseek-v4-pro"
```

只应使用 DeepSeek 当前官方支持的模型名。

## 参考

- [OpenAI：Build skills](https://learn.chatgpt.com/docs/build-skills)
- [DeepSeek：Change Log](https://api-docs.deepseek.com/updates/)
- [DeepSeek：Integrate with OpenCode](https://api-docs.deepseek.com/quick_start/agent_integrations/opencode)
- [OpenCode：Permissions](https://opencode.ai/docs/permissions/)
