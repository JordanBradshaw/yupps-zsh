#!/usr/bin/env -S zsh -f
#
# Tests for zshenv.d/10-toolchains.zsh: toolchain bin dirs on PATH, after
# XDG_BIN_HOME and before the system dirs; missing dirs skipped.
# Run: zsh -f tests/toolchains_test.zsh

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/zshenv.d/10-toolchains.zsh
source $REPO_DIR/tests/lib.zsh

# envpath [VAR=value]... [-- CODE]: source the file in a clean zsh, then print
# "PATH|PNPM_HOME". CODE runs before printing.
envpath() {
  local -a vars
  while (( $# )) && [[ $1 != -- ]]; do vars+=($1); shift; done
  [[ $1 == -- ]] && shift
  env -i HOME=$HOME PATH=/usr/bin:/bin $vars \
    zsh -fc "source $CONF; $1"' print -r -- "${(j.:.)path}|${PNPM_HOME-}"'
}

typeset -ga XDG=()
xdg() { XDG=(XDG_BIN_HOME=$HOME/.local/bin XDG_DATA_HOME=$HOME/.local/share) }

test_bins_in_order() {
  xdg
  local h=$HOME
  mkdir -p $h/.local/share/pnpm/bin $h/.cargo/bin $h/go/bin
  assert_eq "$(envpath $XDG)" \
    "$h/.local/bin:$h/.local/share/pnpm/bin:$h/.cargo/bin:$h/go/bin:/usr/bin:/bin|$h/.local/share/pnpm"
}

test_missing_dirs_skipped() {
  xdg
  assert_eq "$(envpath $XDG)" "$HOME/.local/bin:/usr/bin:/bin|"
}

test_home_overrides() {
  xdg
  local s=$SANDBOX h=$HOME
  mkdir -p $s/pnpm/bin $s/cargo/bin $s/gopath/bin $s/gobin $h/go/bin
  assert_eq "$(envpath $XDG PNPM_HOME=$s/pnpm CARGO_HOME=$s/cargo GOPATH=$s/gopath:$s/other)" \
    "$h/.local/bin:$s/pnpm/bin:$s/cargo/bin:$s/gopath/bin:/usr/bin:/bin|$s/pnpm"
  assert_eq "$(envpath $XDG GOBIN=$s/gobin)" "$h/.local/bin:$s/gobin:/usr/bin:/bin|"
}

test_nested_shell_no_duplicates() {
  xdg
  local h=$HOME
  mkdir -p $h/.cargo/bin $h/go/bin
  assert_eq "$(envpath $XDG -- "source $CONF;")" "$h/.local/bin:$h/.cargo/bin:$h/go/bin:/usr/bin:/bin|"
}

test_tuned_bin_first() {
  xdg
  local h=$HOME
  mkdir -p $h/.local/tuned/bin $h/.cargo/bin
  assert_eq "$(envpath $XDG)" "$h/.local/tuned/bin:$h/.local/bin:$h/.cargo/bin:/usr/bin:/bin|"
}

# Without chezmoi's base env (no XDG vars) the defaults apply and PATH gets
# no empty element.
test_toolchains_without_xdg_vars() {
  local h=$HOME
  mkdir -p $h/.cargo/bin $h/.local/share/pnpm/bin
  assert_eq "$(envpath)" "$h/.local/bin:$h/.local/share/pnpm/bin:$h/.cargo/bin:/usr/bin:/bin|$h/.local/share/pnpm"
}

run_all
