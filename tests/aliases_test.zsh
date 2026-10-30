#!/usr/bin/env -S zsh -f
#
# Tests for the ls/tree/apt wrappers in conf.d/30-aliases.zsh and bin/zc-apt.
# Run: zsh -f tests/aliases_test.zsh
#
# PATH holds only stubs, so the real eza/lsd/nala on this machine never run.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/conf.d/30-aliases.zsh
typeset -g ZC_APT=$REPO_DIR/bin/zc-apt
source $REPO_DIR/tests/lib.zsh

# load_conf TOOL...: stub TOOL... (plus ls), then source the aliases.
load_conf() {
  path=($STUB_BIN)
  stub_echo ls "$@"
  rehash
  source $CONF
}

typeset -g EZA='eza --group-directories-first --icons=always --color=always --git --smart-group --time-style=long-iso --octal-permissions'
typeset -g LSD='lsd --long --group-dirs first --icon always'

# ---------------------------------------------------------------------------
# ls: eza > lsd > ls
# ---------------------------------------------------------------------------

test_ls_prefers_eza() {
  load_conf eza lsd
  assert_eq "$(ls -la foo)" "$EZA --long -a foo"
}

# Long view only on request: plain ls is a grid.
test_ls_eza_plain_is_grid() {
  load_conf eza
  assert_eq "$(ls foo)" "$EZA foo"
}

test_ls_eza_long_flag() {
  load_conf eza
  assert_eq "$(ls -l foo)" "$EZA --long foo"
  assert_eq "$(ls -al foo)" "$EZA -a --long foo"
}

test_ls_uses_lsd_without_eza() {
  load_conf lsd
  assert_eq "$(ls -la foo)" "$LSD -la foo"
}

test_ls_plain_without_eza_or_lsd() {
  load_conf
  (( ! $+functions[ls] )) || fail "ls wrapper defined"
}

test_ls_eza_drops_human_flag() {
  load_conf eza
  assert_eq "$(ls -lh)" "$EZA --long ."
}

test_ls_eza_time_sort() {
  load_conf eza
  # eza's modified sort is oldest first; ls -t is newest first.
  assert_eq "$(ls -lt)" "$EZA --sort=modified --reverse --long ." "-t"
  assert_eq "$(ls -ltr)" "$EZA --sort=modified --long ." "-tr"
}

test_ls_eza_size_sort() {
  load_conf eza
  assert_eq "$(ls -S)" "$EZA --sort=size --reverse ." "-S"
  assert_eq "$(ls -Sr)" "$EZA --sort=size ." "-Sr"
}

test_ls_eza_unsorted() {
  load_conf eza
  assert_eq "$(ls -U b a)" "$EZA --sort=none b a"
}

# eza sorts operands by base name; lspath must keep its root-to-leaf order.
test_lspath_keeps_path_order_with_eza() {
  load_conf eza
  source $REPO_DIR/conf.d/26-functions-ls.zsh
  assert_eq "$(lspath /a/b)" "$EZA --sort=none --long -d -- / /a /a/b"
}

test_ls_eza_reverse_alone() {
  load_conf eza
  assert_eq "$(ls -r)" "$EZA --reverse ."
}

test_ls_eza_shared_long_options() {
  load_conf eza
  assert_eq "$(ls --all --reverse dir)" "$EZA --reverse --all dir"
}

test_ls_eza_double_dash() {
  load_conf eza
  assert_eq "$(ls -a -- -t)" "$EZA -a -- -t"
}

test_ls_eza_unknown_flag_uses_lsd() {
  load_conf eza lsd
  assert_eq "$(ls -v foo)" "$LSD -v foo"
}

test_ls_eza_unknown_flag_uses_ls_without_lsd() {
  load_conf eza
  assert_eq "$(ls -v foo)" "ls -v foo"
}

test_ls_gnu_only_option_uses_ls() {
  load_conf eza lsd
  assert_eq "$(ls --time-style=iso)" "ls --time-style=iso"
}

test_ls_eza_no_git_passes_through() {
  load_conf eza lsd
  assert_eq "$(ls --no-git)" "$EZA --no-git ."
}

test_ll_eza_full_view() {
  load_conf eza lsd
  assert_eq "$(ll src)" "$EZA --long --header --total-size -a src"
}

test_ll_without_eza_uses_ls_wrapper() {
  load_conf lsd
  assert_eq "$(ll src)" "$LSD -la src"
}

# ---------------------------------------------------------------------------
# tree
# ---------------------------------------------------------------------------

test_tree_prefers_eza() {
  load_conf eza lsd
  assert_eq "$(tree src)" \
    "eza --tree --level=4 --group-directories-first --icons=always --color=always src"
}

# eza reads file names from stdin when given none and stdin is not a tty.
test_ls_eza_bare_does_not_read_stdin() {
  load_conf eza
  assert_eq "$(print foo | ls)" "$EZA ."
}

test_ll_eza_bare_lists_current_dir() {
  load_conf eza
  assert_eq "$(print foo | ll)" "$EZA --long --header --total-size -a ."
}

test_tree_eza_bare_lists_current_dir() {
  load_conf eza
  assert_eq "$(print foo | tree -a)" \
    "eza --tree --level=4 --group-directories-first --icons=always --color=always -a ."
}

test_tree_uses_lsd_without_eza() {
  load_conf lsd
  assert_eq "$(tree src)" "lsd --tree --depth=4 src"
}

# ---------------------------------------------------------------------------
# apt -> bin/zc-apt (a script, so `sudo apt` can run it too)
# ---------------------------------------------------------------------------

typeset -g APT_OPTS='-o Acquire::Retries=5 -o APT::Get::Show-Versions=true'

test_apt_alias_points_at_script() {
  load_conf apt
  assert_eq "$aliases[apt]" "$ZC_APT"
  [[ -x $ZC_APT ]] || fail "$ZC_APT not executable"
}

test_apt_no_alias_without_apt() {
  load_conf
  (( ! $+aliases[apt] )) || fail "apt alias defined"
}

test_zc_apt_uses_nala() {
  stub_echo apt nala
  assert_eq "$(PATH=$STUB_BIN $ZC_APT install -y foo)" "nala install --no-autoremove -y foo"
}

# nala only where it can do exactly what apt does: autoremove off (apt never
# autoremoves), no list refresh before full-upgrade.
test_zc_apt_nala_mappings() {
  stub_echo apt nala
  local -A want=(
    'update'                        'nala update'
    'install foo bar'               'nala install --no-autoremove foo bar'
    'remove foo'                    'nala remove --no-autoremove foo'
    'purge foo'                     'nala purge --no-autoremove foo'
    'autoremove'                    'nala autoremove'
    'autopurge -y'                  'nala autopurge -y'
    'full-upgrade'                  'nala full-upgrade --no-update --no-autoremove'
    'dist-upgrade -y'               'nala full-upgrade --no-update --no-autoremove -y'
    'history'                       'nala history'
    'fetch'                         'nala fetch'
  )
  local args
  for args in ${(k)want}; do
    assert_eq "$(PATH=$STUB_BIN $ZC_APT ${=args})" "$want[$args]" "apt $args"
  done
}

# Options both take the same way stay on nala, values included.
test_zc_apt_shared_options_stay_on_nala() {
  stub_echo apt nala
  local -A want=(
    'install -t bookworm-backports foo'      'nala install --no-autoremove -t bookworm-backports foo'
    'install --target-release=testing foo'   'nala install --no-autoremove --target-release=testing foo'
    'install -o Dpkg::Use-Pty=0 -d foo'      'nala install --no-autoremove -o Dpkg::Use-Pty=0 -d foo'
    'install --no-install-recommends foo'    'nala install --no-autoremove --no-install-recommends foo'
    'install https://example.org/foo.deb'    'nala install --no-autoremove https://example.org/foo.deb'
    'remove --purge --assume-yes foo'        'nala remove --no-autoremove --purge --assume-yes foo'
    'update --option Acquire::Retries=3'     'nala update --option Acquire::Retries=3'
    'full-upgrade --download-only'           'nala full-upgrade --no-update --no-autoremove --download-only'
  )
  local args
  for args in ${(k)want}; do
    assert_eq "$(PATH=$STUB_BIN $ZC_APT ${=args})" "$want[$args]" "apt $args"
  done
}

# Anything nala lacks, or takes differently, runs apt.
test_zc_apt_falls_back_to_apt() {
  stub_echo apt nala
  local args
  for args in \
    'upgrade' 'search foo' 'search --names-only foo' 'list --installed' 'show foo' \
    'clean' 'policy foo' 'install -f' 'install --reinstall foo' 'install -s foo' \
    'install -yq foo' 'install ./foo.deb' 'install /tmp/foo.deb' 'install foo/bookworm-backports' \
    'install -o' 'remove -t testing foo' 'full-upgrade -t testing' 'autoremove -t testing' \
    'update -y'; do
    assert_eq "$(PATH=$STUB_BIN $ZC_APT ${=args})" "apt $APT_OPTS $args" "apt $args"
  done
}

test_zc_apt_no_arguments_runs_apt() {
  stub_echo apt nala
  assert_eq "$(PATH=$STUB_BIN $ZC_APT)" "apt $APT_OPTS"
}

# The installed nala accepts every command line zc-apt builds. Not as root:
# nala would act on it. As a normal user nala stops at "needs root" after
# parsing, and rejects unknown options before that.
test_zc_apt_real_nala_accepts_its_command_lines() {
  [[ -x /usr/bin/nala && $EUID -ne 0 ]] || return 0
  stub_echo apt
  local args out
  for args in \
    'update -o A=b --option A=b' \
    'install -y --assume-yes -d --download-only -t x --target-release=x --install-recommends --no-install-recommends --purge -o A=b zz' \
    'remove -y -d --purge -o A=b zz' 'purge -y zz' \
    'autoremove -y -d --purge -o A=b' 'autopurge -y' \
    'full-upgrade -y -d --purge -o A=b' 'dist-upgrade -y'; do
    out=$(PATH=$STUB_BIN:/usr/bin $ZC_APT ${=args} </dev/null 2>&1)
    [[ $out == *'needs root'* ]] || fail "nala rejected apt $args: ${(j: :)${(f)out}[1,6]}"
  done
}

test_zc_apt_unsupported_subcommand_uses_apt() {
  stub_echo apt nala
  assert_eq "$(PATH=$STUB_BIN $ZC_APT policy foo)" "apt $APT_OPTS policy foo"
}

test_zc_apt_without_nala_uses_tuned_apt() {
  stub_echo apt
  assert_eq "$(PATH=$STUB_BIN $ZC_APT install foo)" "apt $APT_OPTS install foo"
}

test_zc_apt_leading_option_uses_apt() {
  stub_echo apt nala
  assert_eq "$(PATH=$STUB_BIN $ZC_APT -y install foo)" "apt $APT_OPTS -y install foo"
}

# ---------------------------------------------------------------------------
# lazyjournal: settings as flags; ssh hosts stay in the local config.yml
# ---------------------------------------------------------------------------

typeset -g LJ_BASE='--tail-lines 20000 --update-interval 2 --min-symbols-filter 1 --unit-types service --journal-field SYSLOG_IDENTIFIER --journal-priority debug'

test_lazyjournal_alias_uses_tailspin() {
  load_conf lazyjournal tspin
  assert_eq "$(lazyjournal -b 0)" "lazyjournal $LJ_BASE --color-mode tailspin -b 0"
}

test_lazyjournal_alias_default_color_without_tailspin() {
  load_conf lazyjournal
  assert_eq "$(lazyjournal)" "lazyjournal $LJ_BASE --color-mode default"
}

test_lazyjournal_no_alias_without_lazyjournal() {
  load_conf
  (( ! $+aliases[lazyjournal] )) || fail "lazyjournal alias defined"
}

test_lj_hosts_reads_ssh_config_and_lazyjournal_config() {
  load_conf lazyjournal
  source $REPO_DIR/conf.d/50-completion.zsh  # provides _zc_ssh_hosts
  print -l 'Host nuc' '  User me' 'Host *' >| $HOME/.ssh/config
  /bin/mkdir -p $XDG_CONFIG_HOME/lazyjournal
  print -l 'settings:' '  colorMode: default' 'ssh:' '  hosts:' \
    '    - root@172.29.0.8' '    - "admin@box -p 2222"' 'hotkeys:' '  exit: ctrl+c' \
    >| $XDG_CONFIG_HOME/lazyjournal/config.yml
  local -a reply
  _zc_lj_hosts
  assert_eq "${(j:|:)reply}" "nuc|root@172.29.0.8|admin@box -p 2222"
}

test_lj_host_with_argument() {
  load_conf lazyjournal
  assert_eq "$(lj-host 'root@h -p 22' -b 0)" \
    "lazyjournal $LJ_BASE --color-mode default --ssh root@h -p 22 -b 0"
}

test_lj_debug_logs_to_state_dir() {
  load_conf lazyjournal
  export XDG_STATE_HOME=$SANDBOX/state
  local out=$(lj-debug -b 0)
  assert_eq "${${(f)out}[1]}" "lazyjournal $LJ_BASE --color-mode default --logging -b 0"
  assert_eq "${${(f)out}[2]}" "log: $SANDBOX/state/lazyjournal/lazyjournal.log"
}

# ---------------------------------------------------------------------------

run_all
