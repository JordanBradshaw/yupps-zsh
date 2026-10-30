#!/usr/bin/env -S zsh -f
#
# Tests for conf.d/26-functions-debug.zsh.
# Run: zsh -f tests/debug_test.zsh
#
# PATH holds only stubs that print their name and arguments.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/conf.d/26-functions-debug.zsh
typeset -g ZSH_BIN=$(whence -p zsh)
source $REPO_DIR/tests/lib.zsh

# load_conf TOOL...: stub TOOL..., then source the helpers. The user is in
# adm, so the journalctl wrapper reads the system journal without sudo.
load_conf() {
  path=($STUB_BIN)
  stub_cmd id 'echo tester adm'
  (( $# )) && stub_echo "$@"
  rehash
  source $CONF
}

# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------

# The journalctl wrapper adds precise timestamps and puts --no-pager last, so
# no pager (with its shell escapes) can start under sudo.
typeset -g JTAIL='--output=short-iso-precise --no-pager'

test_jerr_this_boot() {
  load_conf journalctl
  assert_eq "$(jerr)" "journalctl -p err -b $JTAIL"
}

test_jerr_since() {
  load_conf journalctl
  assert_eq "$(jerr 1 hour ago)" "journalctl -p err --since 1 hour ago $JTAIL"
}

test_jboot_defaults_to_previous_boot() {
  load_conf journalctl
  assert_eq "$(jboot)" "journalctl -p err -b -1 $JTAIL" "default"
  assert_eq "$(jboot -2)" "journalctl -p err -b -2 $JTAIL" "explicit"
}

test_jfollow_unit() {
  load_conf journalctl
  assert_eq "$(jfollow sshd)" "journalctl -f -u sshd $JTAIL"
}

test_jfollow_needs_unit() {
  load_conf journalctl
  jfollow 2>/dev/null && fail "succeeded without a unit"
  return 0
}

test_failed_checks_system_and_user() {
  load_conf systemctl
  local -a out=("${(@f)$(failed)}")
  assert_eq "$out[(r)systemctl *]" "systemctl --failed --no-pager" system
  assert_eq "$out[(R)systemctl *]" "systemctl --user --failed --no-pager" user
}

test_kmsg() {
  load_conf journalctl
  assert_eq "$(kmsg)" "journalctl -k -b -p warning $JTAIL"
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

test_port_uses_sudo_ss() {
  load_conf sudo ss
  (( EUID )) || return 0
  assert_eq "$(port 22)" "sudo ss -tunap ( sport = :22 or dport = :22 )"
}

test_port_rejects_non_number() {
  load_conf sudo ss
  port abc 2>/dev/null && fail "accepted abc"
  return 0
}

test_tcpcheck() {
  load_conf nc
  assert_eq "$(tcpcheck host 443)" "nc -zv -w 3 host 443"
}

test_tcpcheck_needs_host_and_port() {
  load_conf nc
  tcpcheck host 2>/dev/null && fail "succeeded without a port"
  return 0
}

test_dnsq_compares_resolvers() {
  load_conf resolvectl dig
  local out=$(dnsq example.com)
  [[ $out == *"resolvectl query -- example.com"* ]] || fail "no resolvectl: $out"
  [[ $out == *"dig +short @1.1.1.1 example.com"* ]] || fail "no dig: $out"
}

test_netinfo() {
  load_conf ip resolvectl
  local out=$(netinfo)
  [[ $out == *"ip -br -c addr"* ]] || fail "no addr: $out"
  [[ $out == *"ip -c route"* ]] || fail "no route: $out"
  [[ $out == *"resolvectl dns"* ]] || fail "no dns: $out"
}

# ---------------------------------------------------------------------------
# zsh
# ---------------------------------------------------------------------------

test_zsh_bench_runs_n_times() {
  load_conf zsh
  local -a out=("${(@f)$(zsh-bench 3)}")
  assert_eq "$#out" 4 "lines"
  [[ $out[1] == 'run 1: '<->' ms' ]] || fail "bad run line: $out[1]"
  [[ $out[4] == 'average: '<->' ms' ]] || fail "bad average: $out[4]"
}

test_zsh_prof_sets_env() {
  stub_cmd zsh 'echo "ZSH_PROF=$ZSH_PROF zsh $*"'
  load_conf
  assert_eq "$(zsh-prof)" "ZSH_PROF=1 zsh -i -c zprof"
}

test_wherefrom_alias_function_command() {
  load_conf foo
  alias foo='foo --bar'
  function foo() { : }
  local out=$(wherefrom foo)
  [[ $out == *"alias: foo='foo --bar'"* ]] || fail "alias: $out"
  [[ $out == *"function: "* ]] || fail "function: $out"
  [[ $out == *"command: $STUB_BIN/foo"* ]] || fail "command: $out"
}

test_wherefrom_unknown() {
  load_conf
  wherefrom nosuchthing >/dev/null 2>&1 && fail "found nosuchthing"
  return 0
}

test_ztrace_traces_without_leaking() {
  load_conf
  local err=$(ztrace print hi 2>&1 >/dev/null)
  [[ $err == *"print hi"* ]] || fail "no trace: $err"
  [[ ! -o xtrace ]] || fail "xtrace leaked"
}

# ---------------------------------------------------------------------------
# Processes
# ---------------------------------------------------------------------------

test_printenv_pid_lists_only_that_process() {
  load_conf
  /usr/bin/env -i A=1 'B=two words' /bin/sleep 30 &
  local pid=$!
  /bin/sleep 0.2
  local out=$(printenv_pid $pid)
  kill $pid
  assert_eq "$out" $'A=1\nB=two words'
}

test_printenv_pid_empty_environment() {
  load_conf
  /usr/bin/env -i /bin/sleep 30 &
  local pid=$!
  /bin/sleep 0.2
  local out
  out=$(printenv_pid $pid)
  local -i rc=$?
  kill $pid
  assert_eq $rc 0 "status"
  assert_eq "$out" ""
}

# Another user's process: /proc/PID/environ needs root.
test_printenv_pid_other_user_uses_sudo() {
  (( EUID )) || return 0
  load_conf
  stub_cmd sudo 'echo "$@" > '$SANDBOX'/sudo.log; printf "X=1\0Y=2\0"'
  assert_eq "$(printenv_pid 1)" $'X=1\nY=2'
  assert_eq "$(<$SANDBOX/sudo.log)" "cat -- /proc/1/environ"
}

test_printenv_pid_no_such_process() {
  load_conf sudo
  local err
  err=$(printenv_pid 999999999 2>&1 >/dev/null)
  assert_eq $? 1 "status"
  [[ $err == *'no such process: 999999999'* ]] || fail "no error: [$err]"
}

test_printenv_pid_usage() {
  load_conf
  local arg
  for arg in '' abc -1; do
    printenv_pid ${=arg} 2>/dev/null
    assert_eq $? 2 "printenv_pid $arg"
  done
}

# Start `env -i ARGS... sleep 30` in the background; set $REPLY to its PID.
start_env_proc() {
  /usr/bin/env -i "$@" /bin/sleep 30 &
  REPLY=$!
  /bin/sleep 0.2
}

test_printenv_pid_sorted_by_name() {
  load_conf
  start_env_proc ZED=3 AB=2 A=1
  local out=$(printenv_pid $REPLY)
  kill $REPLY
  assert_eq "$out" $'A=1\nAB=2\nZED=3'
}

test_printenv_pid_names_print_values() {
  load_conf
  start_env_proc A=1 'B=two words'
  local out rc
  out=$(printenv_pid $REPLY B A)
  rc=$?
  printenv_pid $REPLY A NOPE >/dev/null
  local missing=$?
  kill $REPLY
  assert_eq "$out" $'two words\n1'
  assert_eq $rc 0 "status"
  assert_eq $missing 1 "missing name status"
}

# on_tty CODE: run zsh CODE with stdout on a terminal, helpers loaded.
on_tty() {
  SHELL=/bin/sh /usr/bin/script -qec \
    "/usr/bin/env -u NO_COLOR $ZSH_BIN -fc 'path=($STUB_BIN); source $CONF; $1'" /dev/null |
    /usr/bin/tr -d '\r'
}

test_printenv_pid_tty_colors_with_bat() {
  load_conf
  stub_cmd bat 'echo "bat $*"; exec /bin/cat'
  start_env_proc B=2 A=1
  local out=$(on_tty "printenv_pid $REPLY")
  kill $REPLY
  assert_eq "$out" "bat --language=dotenv --style=plain --paging=never --color=always
# PID $REPLY: /bin/sleep 30
A=1
B=2"
}

test_printenv_pid_tty_uses_batcat() {
  load_conf
  stub_cmd batcat 'echo batcat; exec /bin/cat'
  start_env_proc A=1
  local out=$(on_tty "printenv_pid $REPLY")
  kill $REPLY
  assert_eq "${${(f)out}[1]}" "batcat"
}

test_printenv_pid_tty_without_bat_still_has_header() {
  load_conf
  start_env_proc A=1
  local out=$(on_tty "printenv_pid $REPLY")
  kill $REPLY
  assert_eq "$out" "# PID $REPLY: /bin/sleep 30
A=1"
}

test_printenv_pid_no_color_skips_bat() {
  load_conf
  stub_cmd bat 'echo bat; exec /bin/cat'
  start_env_proc A=1
  local out=$(on_tty "NO_COLOR=1 printenv_pid $REPLY")
  kill $REPLY
  [[ $out != bat* ]] || fail "bat used with NO_COLOR: [$out]"
}

# printenv_process: pgrep is a stub that logs its arguments and prints PIDS.
stub_pgrep() {
  stub_cmd pgrep 'echo "$@" > '$SANDBOX'/pgrep.log; [ -n "'"$*"'" ] || exit 1; printf "%s\n" '"$*"
  stub_cmd ps 'exec /bin/ps "$@"'
}

test_printenv_process_one_match() {
  load_conf
  start_env_proc A=1 B=2
  stub_pgrep $REPLY
  local out=$(printenv_process sleep)
  local vals=$(printenv_process sleep B A)
  kill $REPLY
  assert_eq "$out" $'A=1\nB=2'
  assert_eq "$vals" $'2\n1'
  assert_eq "$(<$SANDBOX/pgrep.log)" "-x -- sleep"
}

test_printenv_process_full_command_line() {
  load_conf
  start_env_proc A=1
  stub_pgrep $REPLY
  local out=$(printenv_process -f 'sleep 30')
  kill $REPLY
  assert_eq "$out" "A=1"
  assert_eq "$(<$SANDBOX/pgrep.log)" "-f -- sleep 30"
}

test_printenv_process_no_match() {
  load_conf
  stub_pgrep
  local err
  err=$(printenv_process nope 2>&1 >/dev/null)
  assert_eq $? 1 "status"
  [[ $err == *'no process named nope'* ]] || fail "no error: [$err]"
}

test_printenv_process_usage() {
  load_conf
  printenv_process 2>/dev/null
  assert_eq $? 2 "no args"
  printenv_process -f 2>/dev/null
  assert_eq $? 2 "-f only"
}

# Off a terminal it never guesses: list the matches and fail.
test_printenv_process_many_piped_lists_matches() {
  load_conf
  start_env_proc A=1; local p1=$REPLY
  start_env_proc A=2; local p2=$REPLY
  stub_pgrep $p1 $p2
  local out err
  err=$(printenv_process sleep 2>&1 >$SANDBOX/out)
  local -i rc=$?
  kill $p1 $p2
  assert_eq $rc 1 "status"
  assert_eq "$(<$SANDBOX/out)" "" "stdout"
  [[ $err == *"$p1"*/bin/sleep*"$p2"*/bin/sleep*'printenv_pid PID'* ]] || fail "no list: [$err]"
}

# fzf stub: log its arguments, pick the line for PID $PICK (exit 130 if unset).
stub_fzf() {
  stub_cmd fzf 'printf "%s\n" "$@" > '$SANDBOX'/fzf.log
[ -n "'"$1"'" ] || exit 130
while read -r p rest; do [ "$p" = "'"$1"'" ] && echo "$p $rest"; done; exit 0'
}

test_printenv_process_many_on_tty_picks_with_fzf() {
  load_conf
  start_env_proc A=1; local p1=$REPLY
  start_env_proc A=2; local p2=$REPLY
  stub_pgrep $p1 $p2
  stub_fzf $p2
  local out=$(on_tty "printenv_process sleep")
  kill $p1 $p2
  assert_eq "$out" "# PID $p2: /bin/sleep 30
A=2"
  [[ $(<$SANDBOX/fzf.log) == *--preview* ]] || fail "no preview: $(<$SANDBOX/fzf.log)"
}

test_printenv_process_fzf_cancel() {
  load_conf
  start_env_proc A=1; local p1=$REPLY
  start_env_proc A=2; local p2=$REPLY
  stub_pgrep $p1 $p2
  stub_fzf
  local out=$(on_tty "printenv_process sleep; print rc=\$?")
  kill $p1 $p2
  assert_eq "$out" "rc=1"
}

test_printenv_process_prompts_without_fzf() {
  load_conf
  start_env_proc A=1; local p1=$REPLY
  start_env_proc A=2; local p2=$REPLY
  stub_pgrep $p1 $p2
  local out=$( { /bin/sleep 0.5; print $p1 } | on_tty "printenv_process sleep")
  local bad=$( { /bin/sleep 0.5; print 1 } | on_tty "printenv_process sleep; print rc=\$?")
  kill $p1 $p2
  [[ $out == *"PID: "*"# PID $p1: /bin/sleep 30"$'\n'"A=1" ]] || fail "no prompt/pick: [$out]"
  [[ $bad == *"1 is not one of the matches"*"rc=1" ]] || fail "accepted bad PID: [$bad]"
}

# ---------------------------------------------------------------------------

run_all
