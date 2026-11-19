#!/usr/bin/env -S zsh -f
#
# Tests for yupps.plugin.zsh: which dirs it sources, and in what order.
# Run: zsh -f tests/loader_test.zsh
#
# Each test copies the loader into a sandbox plugin dir with marker files.

typeset -g REPO_DIR=${0:A:h:h}
source $REPO_DIR/tests/lib.zsh

# plugin [FILE LABEL]...: a sandbox plugin whose FILEs print LABEL.
plugin() {
  local p=$SANDBOX/p
  mkdir -p $p
  cp $REPO_DIR/yupps.plugin.zsh $p/
  while (( $# >= 2 )); do
    mkdir -p $p/${1:h}
    print -r -- "print -rn -- '$2 '" >| $p/$1
    shift 2
  done
}

test_loads_rc_dirs_in_order() {
  plugin zstyles.d/10-a.zsh s10 zshrc.d/10-a.zsh r10 \
    functions.d/20-b.zsh f20 functions.d/10-a.zsh f10
  assert_eq "$(source $SANDBOX/p/yupps.plugin.zsh)" "f10 f20 r10 s10 "
}

test_skips_tilde_files() {
  plugin zshrc.d/10-a.zsh r10 'zshrc.d/~20-off.zsh' off
  assert_eq "$(source $SANDBOX/p/yupps.plugin.zsh)" "r10 "
}

test_does_not_source_zshenv_d() {
  plugin zshenv.d/10-a.zsh env functions.d/10-a.zsh f10
  assert_eq "$(source $SANDBOX/p/yupps.plugin.zsh)" "f10 "
}

test_leaves_no_loop_variables() {
  plugin functions.d/10-a.zsh f10
  source $SANDBOX/p/yupps.plugin.zsh >/dev/null
  (( ! ${+_yupps_f} && ! ${+_yupps_d} )) || fail "loop variables left set"
}

test_no_conf_d_left() {
  [[ ! -e $REPO_DIR/conf.d ]] || fail "conf.d still exists"
}

run_all
