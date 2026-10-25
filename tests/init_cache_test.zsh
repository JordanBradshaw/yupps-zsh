#!/usr/bin/env -S zsh -f
#
# Tests for conf.d/45-init-cache.zsh: _zc_init_cache caches a tool's init
# script (e.g. `zoxide init zsh`) so shells don't run the tool at startup.
# Run: zsh -f tests/init_cache_test.zsh
#
# PATH holds only stubs, so no real tool runs.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/conf.d/45-init-cache.zsh
source $REPO_DIR/tests/lib.zsh

typeset -g INIT_DIR

load_conf() {
  path=($STUB_BIN)
  INIT_DIR=$XDG_CACHE_HOME/zsh/init
  rehash
  source $CONF
}

# stub_init TOOL FUNC: TOOL logs its arguments to $SANDBOX/runs and prints
# an init script defining FUNC.
stub_init() {
  stub_cmd $1 "echo \"$1 \$*\" >> $SANDBOX/runs
echo 'function $2() { print -r -- $2 \"\$@\" }'"
}

runs() {
  local -a lines
  [[ -f $SANDBOX/runs ]] && lines=("${(@f)$(<$SANDBOX/runs)}")
  print $#lines
}

# init TOOL ARGS...: what a config does with the helper.
init() {
  _zc_init_cache "$@" && source $REPLY
}

test_missing_tool_fails_without_cache_dir() {
  load_conf
  _zc_init_cache zoxide init zsh && fail "succeeded without zoxide"
  [[ ! -e $INIT_DIR ]] || fail "cache dir created"
}

test_init_script_is_sourced_with_its_arguments() {
  stub_init zoxide z
  load_conf
  init zoxide init zsh
  assert_eq "$(z foo)" "z foo"
  assert_eq "$(<$SANDBOX/runs)" "zoxide init zsh"
}

test_cache_reused() {
  stub_init zoxide z
  load_conf
  init zoxide init zsh
  init zoxide init zsh
  assert_eq "$(runs)" 1
  [[ -s $INIT_DIR/zoxide.zsh ]] || fail "no cache file"
}

test_cache_rebuilt_when_binary_newer() {
  stub_init zoxide z
  load_conf
  init zoxide init zsh
  /usr/bin/touch -d '+1 minute' $STUB_BIN/zoxide
  init zoxide init zsh
  assert_eq "$(runs)" 2
}

test_cache_rebuilt_when_command_changes() {
  stub_init zoxide z
  load_conf
  init zoxide init zsh
  print -l '# /old/zoxide init zsh --old' 'function z() { print stale }' >| $INIT_DIR/zoxide.zsh
  /usr/bin/touch -d '+1 minute' $INIT_DIR/zoxide.zsh
  init zoxide init zsh
  assert_eq "$(runs)" 2
  assert_eq "$(z foo)" "z foo"
}

test_failed_init_is_not_cached() {
  stub_cmd zoxide 'exit 1'
  load_conf
  init zoxide init zsh 2>/dev/null && fail "succeeded"
  [[ ! -e $INIT_DIR/zoxide.zsh ]] || fail "cached a failed init"
  (( ! $+functions[z] )) || fail "z defined"
}

run_all
