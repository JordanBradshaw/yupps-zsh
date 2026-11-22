#!/usr/bin/env -S zsh -f
#
# Tests for functions.d/26-functions-tmux.zsh.
# Run: zsh -f tests/tmux_test.zsh
#
# tmux is a stub that logs its arguments; has-session succeeds only when
# $SANDBOX/up exists.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/functions.d/26-functions-tmux.zsh
source $REPO_DIR/tests/lib.zsh

load_conf() {
  path=($STUB_BIN /usr/bin /bin)
  stub_cmd tmux 'echo "$*" >> '$SANDBOX'/tmux.log
[ "$1" != has-session ] || [ -e '$SANDBOX'/up ]'
  rehash
  unset TMUX YUPPS_TMUX_SESSION
  source $CONF
}

calls() { print -r -- "$(<$SANDBOX/tmux.log)" }

test_t_attaches_or_creates_main() {
  load_conf
  t
  assert_eq "$(calls)" "new-session -A -s main"
}

test_t_named_session() {
  load_conf
  t work
  assert_eq "$(calls)" "new-session -A -s work"
}

test_t_default_from_env() {
  load_conf
  YUPPS_TMUX_SESSION=dev
  t
  assert_eq "$(calls)" "new-session -A -s dev"
}

# Inside tmux, attaching would nest; switch the client instead.
test_t_inside_tmux_switches_to_existing() {
  load_conf
  touch $SANDBOX/up
  TMUX=/tmp/tmux-1000/default,1,0
  t work
  assert_eq "$(calls)" $'has-session -t =work\nswitch-client -t =work'
}

test_t_inside_tmux_creates_then_switches() {
  load_conf
  TMUX=/tmp/tmux-1000/default,1,0
  t work
  assert_eq "$(calls)" $'has-session -t =work\nnew-session -d -s work\nswitch-client -t =work'
}

test_t_without_tmux() {
  load_conf
  rm $STUB_BIN/tmux
  path=($STUB_BIN)
  rehash
  t 2>/dev/null
  assert_eq $? 127
}

run_all
