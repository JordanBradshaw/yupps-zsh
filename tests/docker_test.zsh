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

# load_conf PID [ID]: docker inspect prints "PID ID" (and logs its arguments),
# or fails when PID is empty. ID defaults to a name from PID's cgroup, as a
# local container's ID would be.
load_conf() {
  path=($STUB_BIN)
  local id=${2-${${(f)"$(</proc/$$/cgroup)"}[-1]:t}}
  if [[ -n $1 ]]; then
    stub_cmd docker "echo \"\$@\" >> $SANDBOX/docker.log; echo '$1 $id'"
  else
    stub_cmd docker 'echo "Error: No such container: $7" >&2; exit 1'
  fi
  # sudo runs its arguments; root skips sudo. Either way nsenter prints.
  stub_cmd sudo 'echo sudo >> '$SANDBOX'/sudo.log; exec "$@"'
  stub_cmd nsenter 'printf "%s\n" nsenter "$@"'
  stub_echo ss sh
  rehash
  source $CONF
}

test_runs_nsenter_in_net_and_pid_namespaces() {
  load_conf $$
  local -a want=(
    nsenter -t $$ -n -p -- unshare -m --mount-proc -- $STUB_BIN/ss -tlnp
  )
  local out=$(run-in-container web ss -tlnp)
  assert_eq "${(j: :)${(f)out}}" "${(j: :)want}"
  assert_eq "$(<$SANDBOX/docker.log)" "inspect --type container -f {{.State.Pid}} {{.Id}} -- web"
  if (( EUID )); then
    [[ -e $SANDBOX/sudo.log ]] || fail "sudo not used"
  else
    [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo used as root"
  fi
}

# A remote daemon (DOCKER_HOST, Docker Desktop's VM) reports a PID from
# another machine; whatever local process has it is not the container.
test_pid_from_another_host() {
  load_conf $$ 0123456789abcdef
  local err
  err=$(run-in-container web ss 2>&1 >/dev/null)
  assert_eq $? 1 "status"
  [[ $err == *'not web'*'this host'* ]] || fail "no error: [$err]"
  [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo was called"
}

test_pid_without_proc_entry() {
  load_conf 999999999
  local err
  err=$(run-in-container web ss 2>&1 >/dev/null)
  assert_eq $? 1 "status"
  [[ ! -e $SANDBOX/sudo.log ]] || fail "sudo was called"
}

test_usage_without_command() {
  load_conf $$
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
  load_conf $$
  local out=$(run-in-container web sh -c 'echo a b')
  local -a lines=("${(@f)out}")
  assert_eq "${lines[-3]}" "$STUB_BIN/sh"
  assert_eq "${lines[-2]}" "-c"
  assert_eq "${lines[-1]}" "echo a b"
}

test_command_status_passed_through() {
  load_conf $$
  stub_cmd nsenter 'exit 7'
  run-in-container web ss
  assert_eq $? 7
}

run_all
