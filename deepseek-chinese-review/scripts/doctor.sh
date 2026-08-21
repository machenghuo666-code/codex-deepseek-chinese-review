#!/bin/zsh
set -u

pass_count=0
warn_count=0
fail_count=0

pass() {
  print "PASS  $1"
  pass_count=$((pass_count + 1))
}

warn() {
  print "WARN  $1"
  warn_count=$((warn_count + 1))
}

fail() {
  print "FAIL  $1"
  fail_count=$((fail_count + 1))
}

script_dir="${0:A:h}"
install_home="${CODEX_DEEPSEEK_INSTALL_HOME:-$HOME}"
opencode_cli="${OPENCODE_BIN:-}"

if [[ -z "$opencode_cli" ]]; then
  opencode_cli="$(command -v opencode 2>/dev/null || true)"
fi
if [[ -z "$opencode_cli" && -x "$install_home/.opencode/bin/opencode" ]]; then
  opencode_cli="$install_home/.opencode/bin/opencode"
fi

if [[ -n "$opencode_cli" && -x "$opencode_cli" ]]; then
  opencode_version="$("$opencode_cli" --version 2>/dev/null || true)"
  pass "OpenCode CLI 可执行${opencode_version:+（$opencode_version）}"
else
  fail "未找到可执行的 OpenCode CLI"
fi

if command -v jq >/dev/null 2>&1; then
  pass "jq 可用"
else
  fail "未找到 jq"
fi

for helper in deepseek-review review_file.sh doctor.sh; do
  helper_path="$script_dir/$helper"
  if [[ -x "$helper_path" ]] && /bin/zsh -n "$helper_path" 2>/dev/null; then
    pass "$helper 语法与执行权限正常"
  else
    fail "$helper 缺失、不可执行或语法错误"
  fi
done

opencode_config_root="${XDG_CONFIG_HOME:-$install_home/.config}/opencode"
flash_agent="$opencode_config_root/agents/deepseek-zh-flash.md"
pro_agent="$opencode_config_root/agents/deepseek-zh-pro.md"

if [[ -f "$flash_agent" ]] && /usr/bin/grep -Fq 'deepseek/deepseek-v4-flash' "$flash_agent"; then
  pass "Flash agent 模型路由正确"
else
  fail "Flash agent 缺失或模型路由不正确"
fi

if [[ -f "$pro_agent" ]] && /usr/bin/grep -Fq 'deepseek/deepseek-v4-pro' "$pro_agent"; then
  pass "Pro agent 模型路由正确"
else
  fail "Pro agent 缺失或模型路由不正确"
fi

auth_path="${XDG_DATA_HOME:-$install_home/.local/share}/opencode/auth.json"
if [[ -f "$auth_path" ]]; then
  auth_permissions="$(stat -f '%Sp' "$auth_path" 2>/dev/null || true)"
  case "$auth_permissions" in
    -rw-------) pass "OpenCode 凭据文件权限为 600（未读取内容）" ;;
    *) warn "OpenCode 凭据文件存在，但建议权限为 600（未读取内容）" ;;
  esac
else
  warn "未发现 OpenCode auth.json；若使用其他认证方式可忽略"
fi

print ""
print "结果：${pass_count} PASS，${warn_count} WARN，${fail_count} FAIL"
print "提示：Codex workspace-write 下调用 DeepSeek 需要按 on-request 批准本次 OpenCode/API 访问。"
print "doctor 不会调用模型，也不会读取或输出 API Key。"

if (( fail_count > 0 )); then
  exit 1
fi
