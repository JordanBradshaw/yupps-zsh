#!/usr/bin/env -S zsh -f
#
# Tests for conf.d/26-functions-docker.zsh.
# Run: zsh -f tests/docker_test.zsh
#
# PATH holds only stubs. sudo prints one argument per line, so word splitting
# is visible in the output.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/conf.d/26-functions-docker.zsh
source $REPO_DIR/tests/lib.zsh

# load_conf PID: docker inspect prints PID (and logs its arguments), or fails
# when PID is empty.
load_conf() {
  path=($STUB_BIN)
  if [[ -n $1 ]]; then
    stub_cmd docker "echo \"\$@\" >> $SANDBOX/docker.log; echo $1"
  else
    stub_cmd docker 'echo "Error: No such object: $4" >&2; exit 1'
  fi
  # sudo runs its arguments; root skips sudo. Either way nsenter prints.
  stub_cmd sudo 'echo sudo >> '$SANDBOX'/sudo.log; exec "$@"'
  stub_cmd nsenter 'printf "%s\n" nsenter "$@"'
  stub_echo ss sh
  rehash
  source $CONF
}

test_runs_nsenter_in_net_and_pid_namespaces() {
  load_conf 4242
  local -a want=(
    nsenter -t 4242 -n -p -- unshare -m --mount-proc -- $STUB_BIN/ss -tlnp
  )
  local out=$(run-in-container web ss -tlnp)
  assert_eq "${(j: :)${(f)out}}" "${(j: :)want}"
  assert_eq "$(<$SANDBOX/docker.log)" "inspect -f {{.State.Pid}} web"
  if (( EUID )); then
    [[ -e $SANDBOX/sudo.log ]] || fail "sudo not used"
  else
    [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo used as root"
  fi
}

test_usage_without_command() {
  load_conf 4242
  local err
  err=$(run-in-container web 2>&1 >/dev/null)
  assert_eq $? 2 "status"
  [[ $err == *'usage: run-in-container'* ]] || fail "no usage: [$err]"
  [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo was called"
}

test_stopped_container() {
  load_conf 0
  local err
  err=$(run-in-container web ss 2>&1 >/dev/null)
  assert_eq $? 1 "status"
  [[ $err == *'not running'* ]] || fail "no error: [$err]"
  [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo was called"
}

test_unknown_container() {
  load_conf ''
  local err
  err=$(run-in-container nope ss 2>&1 >/dev/null)
  assert_eq $? 1 "status"
  [[ $err == *nope* ]] || fail "error does not name container: [$err]"
  [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo was called"
}

test_args_with_spaces_kept() {
  load_conf 4242
  local out=$(run-in-container web sh -c 'echo a b')
  local -a lines=("${(@f)out}")
  assert_eq "${lines[-3]}" "$STUB_BIN/sh"
  assert_eq "${lines[-2]}" "-c"
  assert_eq "${lines[-1]}" "echo a b"
}

test_command_status_passed_through() {
  load_conf 4242
  stub_cmd nsenter 'exit 7'
  run-in-container web ss
  assert_eq $? 7
}

run_all
