#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h}"
skill_source="$repo_root/deepseek-chinese-review"
agents_source="$repo_root/opencode-agents"
install_home="${CODEX_DEEPSEEK_INSTALL_HOME:-$HOME}"
skill_target="$install_home/.agents/skills/deepseek-chinese-review"
opencode_config_root="${XDG_CONFIG_HOME:-$install_home/.config}/opencode"
agents_target="$opencode_config_root/agents"

for target in \
  "$skill_target" \
  "$agents_target/deepseek-zh-flash.md" \
  "$agents_target/deepseek-zh-pro.md"
do
  if [[ -e "$target" ]]; then
    print -u2 "目标已存在，未覆盖：$target"
    print -u2 "请先自行备份或移走旧版本，再重新运行安装脚本。"
    exit 3
  fi
done

umask 077
mkdir -p "${skill_target:h}" "$agents_target"
cp -R "$skill_source" "$skill_target"
cp "$agents_source/deepseek-zh-flash.md" "$agents_target/deepseek-zh-flash.md"
cp "$agents_source/deepseek-zh-pro.md" "$agents_target/deepseek-zh-pro.md"
chmod 700 "$skill_target/scripts/deepseek-review" "$skill_target/scripts/review_file.sh"

print "安装完成：$skill_target"
print "未修改 ~/.codex/config.toml，也未读取或写入 API Key。"
print "若 Codex 没有自动发现新 Skill，请重启 Codex。"
