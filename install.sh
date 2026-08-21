#!/bin/zsh
set -euo pipefail

install_mode="install"
case "${1:-}" in
  '') ;;
  --update) install_mode="update" ;;
  -h|--help)
    print "用法：./install.sh [--update]"
    print "  默认：仅在目标不存在时安装，不覆盖任何文件。"
    print "  --update：先备份现有 Skill/agents，再安装当前版本。"
    exit 0
    ;;
  *)
    print -u2 "未知参数：${1}"
    exit 2
    ;;
esac

if (( $# > 1 )); then
  print -u2 "参数过多。用法：./install.sh [--update]"
  exit 2
fi

repo_root="${0:A:h}"
skill_source="$repo_root/deepseek-chinese-review"
agents_source="$repo_root/opencode-agents"
install_home="${CODEX_DEEPSEEK_INSTALL_HOME:-$HOME}"
skill_target="$install_home/.agents/skills/deepseek-chinese-review"
opencode_config_root="${XDG_CONFIG_HOME:-$install_home/.config}/opencode"
agents_target="$opencode_config_root/agents"
flash_target="$agents_target/deepseek-zh-flash.md"
pro_target="$agents_target/deepseek-zh-pro.md"

for required_source in \
  "$skill_source/SKILL.md" \
  "$skill_source/scripts/deepseek-review" \
  "$skill_source/scripts/review_file.sh" \
  "$skill_source/scripts/doctor.sh" \
  "$agents_source/deepseek-zh-flash.md" \
  "$agents_source/deepseek-zh-pro.md"
do
  if [[ ! -f "$required_source" ]]; then
    print -u2 "安装包不完整，缺少：$required_source"
    exit 4
  fi
done

/bin/zsh -n "$skill_source/scripts/deepseek-review"
/bin/zsh -n "$skill_source/scripts/review_file.sh"
/bin/zsh -n "$skill_source/scripts/doctor.sh"

for target in "$skill_target" "$flash_target" "$pro_target"; do
  if [[ -L "$target" ]]; then
    print -u2 "安全拒绝：目标是符号链接，不会覆盖：$target"
    exit 3
  fi
done

if [[ "$install_mode" == "install" ]]; then
  for target in "$skill_target" "$flash_target" "$pro_target"; do
    if [[ -e "$target" ]]; then
      print -u2 "目标已存在，未覆盖：$target"
      print -u2 "需要升级时请运行：./install.sh --update"
      exit 3
    fi
  done
fi

umask 077
mkdir -p "${skill_target:h}" "$agents_target"

skill_stage="${skill_target}.installing.$$"
flash_stage="${flash_target}.installing.$$"
pro_stage="${pro_target}.installing.$$"
trap '/bin/rm -rf -- "$skill_stage"; /bin/rm -f -- "$flash_stage" "$pro_stage"' EXIT INT TERM

cp -R "$skill_source" "$skill_stage"
cp "$agents_source/deepseek-zh-flash.md" "$flash_stage"
cp "$agents_source/deepseek-zh-pro.md" "$pro_stage"
chmod 700 \
  "$skill_stage/scripts/deepseek-review" \
  "$skill_stage/scripts/review_file.sh" \
  "$skill_stage/scripts/doctor.sh"

backup_dir=""
if [[ "$install_mode" == "update" ]]; then
  backup_stamp="$(date +%Y%m%d_%H%M%S)"
  backup_dir="$install_home/.local/share/codex-deepseek-review/backups/$backup_stamp"
  mkdir -p "$backup_dir"

  if [[ -e "$skill_target" ]]; then
    cp -R "$skill_target" "$backup_dir/deepseek-chinese-review"
  fi
  if [[ -e "$flash_target" ]]; then
    cp "$flash_target" "$backup_dir/deepseek-zh-flash.md"
  fi
  if [[ -e "$pro_target" ]]; then
    cp "$pro_target" "$backup_dir/deepseek-zh-pro.md"
  fi

  if [[ -e "$skill_target" ]]; then
    /bin/rm -rf -- "$skill_target"
  fi
fi

mv "$skill_stage" "$skill_target"
mv -f "$flash_stage" "$flash_target"
mv -f "$pro_stage" "$pro_target"
trap - EXIT INT TERM

print "安装完成：$skill_target"
if [[ -n "$backup_dir" ]]; then
  print "原版本备份：$backup_dir"
fi
print "未修改 ~/.codex/config.toml，也未读取或写入 API Key。"
print "若 Codex 没有自动发现新 Skill，请重启 Codex。"
