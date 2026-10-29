#!/usr/bin/env -S zsh -f
#
# Tests for conf.d/50-completion.zsh.
# Run: zsh -f tests/completion_test.zsh
#
# Each test runs in a subshell with a temporary HOME, cache dir, PATH stubs and
# fpath stubs, against a real compinit.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/conf.d/50-completion.zsh
source $REPO_DIR/tests/lib.zsh

load_conf() {
  rehash
  autoload -Uz compinit
  compinit -D -i
  source $CONF
}

# ---------------------------------------------------------------------------
# SSH hosts
# ---------------------------------------------------------------------------

test_ssh_hosts_skips_wildcards() {
  print -l 'Host zbox nuc' '  HostName 10.0.0.1' 'Host *' 'Host cuas*' 'host trillium' \
    >| $HOME/.ssh/config
  load_conf
  _zc_ssh_hosts $HOME/.ssh/config
  assert_eq "${(j: :)${(@o)reply}}" "nuc trillium zbox"
}

test_ssh_hosts_follow_includes() {
  mkdir -p $HOME/.ssh/config.d $HOME/other
  print -l 'Include config.d/*' 'Include ~/other/extra' 'Host main' >| $HOME/.ssh/config
  print -l 'Host work-a work-b' >| $HOME/.ssh/config.d/work
  print -l 'Host lab' 'Include ~/.ssh/config' >| $HOME/other/extra
  load_conf
  _zc_ssh_hosts $HOME/.ssh/config
  assert_eq "${(j: :)${(@o)reply}}" "lab main work-a work-b"
}

test_ssh_hosts_missing_config() {
  load_conf
  _zc_ssh_hosts $HOME/.ssh/config
  assert_eq "${#reply}" 0
}

# ---------------------------------------------------------------------------
# Generated completions
# ---------------------------------------------------------------------------

stub_generator() {
  stub_cmd foo "echo run >> $SANDBOX/runs
cat <<'EOF'
#compdef foo
_foo() { return 0 }
compdef _foo foo
EOF"
}

test_gencomp_creates_cache_and_registers() {
  stub_generator
  load_conf
  _zc_gencomp foo completion zsh
  [[ -s $XDG_CACHE_HOME/zsh/gencomp/_foo ]] || fail "cache not written"
  assert_eq "$_comps[foo]" "_foo"
}

test_gencomp_reuses_fresh_cache() {
  stub_generator
  load_conf
  _zc_gencomp foo completion zsh
  _zc_gencomp foo completion zsh
  assert_eq "$(wc -l < $SANDBOX/runs | tr -d ' ')" 1
}

test_gencomp_regenerates_when_binary_newer() {
  stub_generator
  load_conf
  _zc_gencomp foo completion zsh
  touch -d '+1 minute' $STUB_BIN/foo
  _zc_gencomp foo completion zsh
  assert_eq "$(wc -l < $SANDBOX/runs | tr -d ' ')" 2
}

test_gencomp_skips_missing_command() {
  load_conf
  _zc_gencomp nosuchtool completion zsh 2>/dev/null
  [[ ! -e $XDG_CACHE_HOME/zsh/gencomp/_nosuchtool ]] || fail "cache written"
}

test_gencomp_drops_empty_output() {
  stub_cmd foo "exit 1"
  load_conf
  _zc_gencomp foo completion zsh 2>/dev/null
  [[ ! -e $XDG_CACHE_HOME/zsh/gencomp/_foo ]] || fail "empty cache kept"
}

# shtab-style scripts (tldr) only call compdef when eval'd; when sourced they
# run the completion function directly, which fails outside completion.
test_gencomp_registers_shtab_style_script() {
  stub_cmd foo "cat <<'EOF'
#compdef foo
_shtab_foo() { return 0 }
if [[ \$zsh_eval_context[-1] == eval ]]; then
  compdef _shtab_foo -N foo
else
  _shtab_foo
fi
EOF"
  load_conf
  _zc_gencomp foo --print-completion zsh
  assert_eq "$_comps[foo]" "_shtab_foo"
}

# Older cobra scripts (depot) have a #compdef header but never call compdef;
# they only work when autoloaded.
test_gencomp_registers_autoload_only_script() {
  stub_cmd foo "cat <<'EOF'
#compdef foo
_foo() { print called >> $SANDBOX/called }
if [ \"\$funcstack[1]\" = \"_foo\" ]; then
  _foo
fi
EOF"
  load_conf
  _zc_gencomp foo completion zsh
  assert_eq "$_comps[foo]" "_foo"
  _foo
  assert_eq "$(<$SANDBOX/called)" "called" "autoloaded body runs"
}

# ---------------------------------------------------------------------------
# Post-compinit setup
# ---------------------------------------------------------------------------

test_setup_registers_repo_functions() {
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[mkcd]" "_directories" mkcd
  assert_eq "$_comps[pathappend]" "_directories" pathappend
  assert_eq "$_comps[pathprepend]" "_directories" pathprepend
  assert_eq "$_comps[bak]" "_files" bak
  assert_eq "$_comps[touchf]" "_files" touchf
  assert_eq "$_comps[tailf]" "_files" tailf
  assert_eq "$_comps[cdf]" "_files" cdf
  assert_eq "$_comps[lspath]" "_files" lspath
  assert_eq "$_comps[pathremove]" "_zc_pathremove" pathremove
  assert_eq "$_comps[ineachdir]" "_precommand" ineachdir
  assert_eq "$_comps[whichall]" "$_comps[whence]" whichall
  assert_eq "$_comps[zhelp]" "_zhelp" zhelp
}

test_setup_tree_prefers_eza_completion() {
  stub_comp _eza eza
  stub_comp _lsd lsd
  function tree() { : }
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[tree]" "_eza"
}

test_setup_tree_uses_lsd_completion() {
  stub_comp _lsd lsd
  function tree() { : }
  load_conf
  unset '_comps[eza]'  # the host's eza completion may be on fpath
  _zc_completion_setup
  assert_eq "$_comps[tree]" "_lsd"
}

test_setup_jfollow_completes_units() {
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[jfollow]" "_zc_units"
}

test_setup_sj_uses_journalctl_completion() {
  stub_comp _journalctl journalctl
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[sj]" "$_comps[journalctl]"
}

# zsh-bin on a host without zsh (zssh bundles) has no _journalctl: systemd
# ships it only alongside a system zsh.
test_setup_skips_sj_without_journalctl_completion() {
  load_conf
  unset '_comps[journalctl]'
  _zc_completion_setup 2>$SANDBOX/err
  assert_eq "$(<$SANDBOX/err)" "" stderr
  assert_eq "${+_comps[sj]}" 0
}

test_setup_maps_fdfind_to_fd() {
  stub_cmd fdfind
  stub_comp _fd fd
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[fdfind]" "_fd"
}

test_setup_gnu_generic_for_uncovered_tools() {
  stub_cmd duf
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[duf]" "_gnu_generic"
}

test_setup_keeps_existing_completion() {
  stub_cmd btm
  stub_comp _btm btm
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[btm]" "_btm"
}

test_setup_generates_tldr_completion() {
  stub_cmd tldr '[ "$1" = --print-completion ] || exit 1
echo "#compdef tldr"
echo "_tldr_gen() { return 0 }"
echo "compdef _tldr_gen tldr"'
  load_conf
  _zc_completion_setup
  assert_eq "$_comps[tldr]" "_tldr_gen"
}

test_setup_skips_uninstalled_tools() {
  load_conf
  (( ! $+commands[eget] )) || fail "eget unexpectedly on sandbox PATH"
  _zc_completion_setup
  assert_eq "${_comps[eget]-unset}" "unset"
}

test_setup_runs_once() {
  load_conf
  (( ${precmd_functions[(I)_zc_completion_setup]:-0} )) || fail "hook not registered"
  _zc_completion_setup
  (( ! ${precmd_functions[(I)_zc_completion_setup]:-0} )) || fail "hook not removed"
}

# ---------------------------------------------------------------------------
# argcomplete tools (ros2): may appear on PATH mid-session via ROS setup.zsh
# ---------------------------------------------------------------------------

# argcomplete >= 3 prints a script that calls compdef itself under zsh.
stub_argcomplete() {
  stub_cmd ${1:-register-python-argcomplete} "echo \"\$@\" >> $SANDBOX/reg
echo '_python_argcomplete() { return 0 }'
echo \"compdef _python_argcomplete \$1\""
}

test_argcomplete_registers_ros2() {
  stub_cmd ros2
  stub_argcomplete
  load_conf
  _zc_argcomplete_setup
  assert_eq "$_comps[ros2]" "_python_argcomplete"
  assert_eq "$(<$SANDBOX/reg)" "ros2" "register args"
}

test_argcomplete_waits_for_ros2_on_path() {
  stub_argcomplete
  load_conf
  _zc_argcomplete_setup
  (( ${precmd_functions[(I)_zc_argcomplete_setup]:-0} )) || fail "hook removed early"
  # Like sourcing /opt/ros/*/setup.zsh
  mkdir $SANDBOX/ros
  print '#!/bin/sh' >| $SANDBOX/ros/ros2
  chmod +x $SANDBOX/ros/ros2
  path=($SANDBOX/ros $path)
  _zc_argcomplete_setup
  assert_eq "$_comps[ros2]" "_python_argcomplete"
  (( ! ${precmd_functions[(I)_zc_argcomplete_setup]:-0} )) || fail "hook not removed"
}

test_argcomplete_keeps_ros_setup_completion() {
  stub_cmd ros2
  stub_argcomplete
  load_conf
  compdef _ros_own ros2
  _zc_argcomplete_setup
  assert_eq "$_comps[ros2]" "_ros_own"
  [[ ! -e $SANDBOX/reg ]] || fail "register-python-argcomplete ran"
  (( ! ${precmd_functions[(I)_zc_argcomplete_setup]:-0} )) || fail "hook not removed"
}

test_argcomplete_uses_register3_name() {
  stub_cmd ros2
  stub_argcomplete register-python-argcomplete3
  path=($STUB_BIN)  # hide the host's register-python-argcomplete
  load_conf
  _zc_argcomplete_setup
  assert_eq "$_comps[ros2]" "_python_argcomplete"
}

# argcomplete < 3 prints a bash-only script.
test_argcomplete_bash_script_uses_bashcompinit() {
  stub_cmd ros2
  stub_cmd register-python-argcomplete "cat <<'EOF'
_python_argcomplete() { return 0 }
complete -o nospace -o default -F _python_argcomplete ros2
EOF"
  load_conf
  _zc_argcomplete_setup 2>$SANDBOX/err
  assert_eq "$(<$SANDBOX/err)" "" stderr
  assert_eq "$_comps[ros2]" "_bash_complete -o nospace -o default -F _python_argcomplete"
}

test_argcomplete_without_register_tool() {
  stub_cmd ros2
  path=($STUB_BIN)
  load_conf
  _zc_argcomplete_setup 2>$SANDBOX/err
  assert_eq "$(<$SANDBOX/err)" "" stderr
  assert_eq "${+_comps[ros2]}" 0
  (( ! ${precmd_functions[(I)_zc_argcomplete_setup]:-0} )) || fail "hook not removed"
}

test_argcomplete_waits_for_compinit() {
  stub_cmd ros2
  stub_argcomplete
  source $CONF
  _zc_argcomplete_setup
  [[ ! -e $SANDBOX/reg ]] || fail "ran before compinit"
  (( ${precmd_functions[(I)_zc_argcomplete_setup]:-0} )) || fail "hook removed early"
}

# ---------------------------------------------------------------------------
# zstyles are configuration: they live in the dotfiles (zstyles.d), not here.
# ---------------------------------------------------------------------------

test_sets_no_zstyles() {
  rehash
  autoload -Uz compinit
  compinit -D -i
  local before=$(zstyle -L)
  source $CONF
  _zc_completion_setup
  [[ -z $(zstyle -L | grep -vxF -f <(print -r -- $before)) ]] ||
    fail "zstyles set: $(zstyle -L | grep -vxF -f <(print -r -- $before) | head -3)"
  [[ -z $(zstyle -L ':fzf-tab:*') ]] || fail "fzf-tab previews set"
}

# ---------------------------------------------------------------------------

run_all
