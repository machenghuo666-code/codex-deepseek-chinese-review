#!/bin/zsh
set -u

repo_root="${0:A:h:h}"
bridge="$repo_root/deepseek-chinese-review/scripts/deepseek-review"
review_file="$repo_root/deepseek-chinese-review/scripts/review_file.sh"
fake_opencode="$repo_root/tests/fixtures/fake-opencode"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/codex-deepseek-tests.XXXXXX")"
trap '/bin/rm -rf -- "$test_tmp"' EXIT INT TERM

pass_count=0
fail_count=0

pass() {
  print "PASS  $1"
  pass_count=$((pass_count + 1))
}

fail() {
  print -u2 "FAIL  $1"
  fail_count=$((fail_count + 1))
}

run_bridge_case() {
  case_name="$1"
  scenario="$2"
  mode="$3"
  expected_status="$4"
  expected_text="$5"

  output_file="$test_tmp/${case_name}.out"
  OPENCODE_BIN="$fake_opencode" \
    FAKE_OPENCODE_SCENARIO="$scenario" \
    "$bridge" "$mode" < "$test_tmp/input.txt" > "$output_file" 2>&1
  actual_status=$?

  if (( actual_status == expected_status )) && /usr/bin/grep -Fq "$expected_text" "$output_file"; then
    pass "$case_name"
  else
    fail "$case_name（status=$actual_status）"
  fi
}

print -r -- '用于本地确定性测试的中文文本。' > "$test_tmp/input.txt"

chmod 700 "$fake_opencode" "$bridge" "$review_file"

run_bridge_case "完整结果正常退出" "complete" "flash" 0 "【DeepSeek V4 Flash 审阅意见】"
run_bridge_case "完整结果但 OpenCode 退出 1" "complete-exit-1" "flash" 0 "测试审阅正文"
run_bridge_case "不完整结果保持失败" "incomplete-exit-1" "flash" 1 "未自动重试"
run_bridge_case "沙箱启动失败分类" "sandbox-exit-1" "flash" 77 "工作区沙箱阻止"
run_bridge_case "Pro 路由与标题" "assert-pro" "pro" 0 "【DeepSeek V4 Pro 审阅意见】"

empty_output="$test_tmp/empty.out"
OPENCODE_BIN="$fake_opencode" "$bridge" flash < /dev/null > "$empty_output" 2>&1
empty_status=$?
if (( empty_status == 2 )) && /usr/bin/grep -Fq "待审内容为空" "$empty_output"; then
  pass "空输入拒绝"
else
  fail "空输入拒绝（status=$empty_status）"
fi

oversize_input="$test_tmp/oversize.txt"
/usr/bin/yes x | /usr/bin/head -c 200001 > "$oversize_input"
oversize_output="$test_tmp/oversize.out"
OPENCODE_BIN="$fake_opencode" "$review_file" flash "$oversize_input" > "$oversize_output" 2>&1
oversize_status=$?
if (( oversize_status == 3 )) && /usr/bin/grep -Fq "超过 200000 字节" "$oversize_output"; then
  pass "超大文件拒绝"
else
  fail "超大文件拒绝（status=$oversize_status）"
fi

credential_input="$test_tmp/auth.json"
print -r -- '{}' > "$credential_input"
credential_output="$test_tmp/credential.out"
OPENCODE_BIN="$fake_opencode" "$review_file" flash "$credential_input" > "$credential_output" 2>&1
credential_status=$?
if (( credential_status == 3 )) && /usr/bin/grep -Fq "拒绝提交可能包含凭据" "$credential_output"; then
  pass "凭据文件名拒绝"
else
  fail "凭据文件名拒绝（status=$credential_status）"
fi

print ""
print "结果：${pass_count} PASS，${fail_count} FAIL"
if (( fail_count > 0 )); then
  exit 1
fi
