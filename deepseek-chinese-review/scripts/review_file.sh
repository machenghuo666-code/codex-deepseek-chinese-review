#!/bin/zsh
set -euo pipefail

review_mode="${1:-}"
input_path="${2:-}"
cleanup_mode="${3:-}"

case "$review_mode" in
  flash|pro) ;;
  *)
    print -u2 "用法：review_file.sh [flash|pro] /absolute/path/to/input.txt [--cleanup]"
    exit 2
    ;;
esac

if [[ -z "$input_path" || "$input_path" != /* || ! -f "$input_path" ]]; then
  print -u2 "待审文件必须是存在的绝对路径。"
  exit 2
fi

resolved_input="${input_path:A}"
input_name="${resolved_input:t}"
case "$input_name" in
  .env|.env.*|auth.json|*credential*|*secret*|*token*|*api-key*|*apikey*)
    print -u2 "拒绝提交可能包含凭据的文件：$input_name"
    exit 3
    ;;
esac

input_bytes="$(stat -f '%z' "$resolved_input")"
if (( input_bytes > 200000 )); then
  print -u2 "待审文件超过 200 KB；请缩小到明确需要审阅的内容。"
  exit 3
fi

if [[ "$cleanup_mode" == "--cleanup" ]]; then
  cleanup_dir="${resolved_input:h}"
  case "$cleanup_dir" in
    /private/tmp/codex-deepseek-skill.*|/tmp/codex-deepseek-skill.*|/private/var/folders/*/T/codex-deepseek-skill.*|/var/folders/*/T/codex-deepseek-skill.*)
      trap '/bin/rm -rf -- "$cleanup_dir"' EXIT INT TERM
      ;;
    *)
      print -u2 "安全拒绝：只允许清理专用的 DeepSeek 临时目录。"
      exit 3
      ;;
  esac
elif [[ -n "$cleanup_mode" ]]; then
  print -u2 "未知参数：$cleanup_mode"
  exit 2
fi

script_dir="${0:A:h}"
bridge="$script_dir/deepseek-review"
if [[ ! -x "$bridge" ]]; then
  print -u2 "本机 DeepSeek 审稿桥接不可用：$bridge"
  exit 127
fi

"$bridge" "$review_mode" < "$resolved_input"
