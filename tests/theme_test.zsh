#!/usr/bin/env -S zsh -f
#
# Tests for themes/yupps.zsh-theme.
# Run: zsh -f tests/theme_test.zsh

typeset -g REPO_DIR=${0:A:h:h}
typeset -g THEME=$REPO_DIR/themes/yupps.zsh-theme
source $REPO_DIR/tests/lib.zsh

load_theme() {
  zmodload zsh/zle
  typeset -g color_prompt=yes PROMPT_ALTERNATIVE=twoline
  source $THEME
}

# zshrinkwrap prints the upper prompt lines itself and hands zle only the last
# one, which zle draws from reset attributes. A color carried over from the
# line above is lost, so the last line must set its own.
test_twoline_bottom_line_sets_its_own_color() {
  load_theme
  local bottom=${PROMPT##*$'\n'}
  [[ $bottom == '%F{'* ]] || fail "bottom line has no color of its own: $bottom"
}

test_twoline_bottom_line_matches_top_line_color() {
  load_theme
  local top=${PROMPT%%╔*} bottom=${PROMPT##*$'\n'}
  assert_eq "${bottom%%╚*}" "$top"
}

# Stand-ins for the constants zsh-vi-mode defines when it loads.
stub_zvm() {
  typeset -g ZVM_MODE_NORMAL=n ZVM_MODE_INSERT=i ZVM_MODE_VISUAL=v \
    ZVM_MODE_VISUAL_LINE=vl ZVM_MODE_REPLACE=r
  typeset -g ZVM_CURSOR_BLOCK=bl ZVM_CURSOR_UNDERLINE=ul ZVM_CURSOR_BEAM=be \
    ZVM_CURSOR_BLINKING_BLOCK=bbl
}

# Top line after the parameter expansion zshrinkwrap does at precmd.
top_line() {
  _yupps_venv_name
  local full=${(e)PROMPT}
  print -r -- ${full%%$'\n'*}
}

# What the terminal shows for a prompt string: prompt escapes expanded and
# color sequences removed.
plain() {
  setopt local_options extended_glob
  local x=${(%)1}
  print -r -- ${x//$'\e'\[[0-9;]##m/}
}

test_venv_name_uses_dir_name() {
  load_theme
  unset VIRTUAL_ENV_PROMPT
  VIRTUAL_ENV=/x/myenv
  _yupps_venv_name
  assert_eq "$_yupps_venv" myenv
}

test_venv_name_uses_project_for_dot_venv() {
  load_theme
  unset VIRTUAL_ENV_PROMPT
  local dir
  for dir in .venv venv env .env; do
    VIRTUAL_ENV=/x/proj/$dir
    _yupps_venv_name
    assert_eq "$_yupps_venv" proj "$dir"
  done
}

test_venv_name_prefers_virtual_env_prompt() {
  load_theme
  VIRTUAL_ENV=/x/proj/.venv
  VIRTUAL_ENV_PROMPT='(foo) '
  _yupps_venv_name
  assert_eq "$_yupps_venv" foo "old-style prompt"
  VIRTUAL_ENV_PROMPT=bar
  _yupps_venv_name
  assert_eq "$_yupps_venv" bar "plain prompt"
}

test_venv_name_empty_without_venv() {
  load_theme
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  _yupps_venv=stale
  _yupps_venv_name
  assert_eq "$_yupps_venv" ''
}

test_twoline_top_line_shows_venv() {
  load_theme
  unset VIRTUAL_ENV_PROMPT
  VIRTUAL_ENV=/x/proj/.venv
  local top=$(plain "$(top_line)")
  [[ $top == '╔═(🐍 proj)═('* ]] || fail "no venv segment: $top"
}

test_twoline_venv_name_is_green() {
  load_theme
  unset VIRTUAL_ENV_PROMPT
  VIRTUAL_ENV=/x/proj/.venv
  [[ $(top_line) == *'%F{#a6e3a1}proj%F{'* ]] || fail "venv name not green: $(top_line)"
}

# A % in a venv name must print as-is, not start a prompt escape.
test_twoline_venv_name_escapes_percent() {
  load_theme
  VIRTUAL_ENV=/x/proj/.venv VIRTUAL_ENV_PROMPT='50%off'
  [[ $(plain "$(top_line)") == *'(🐍 50%off)'* ]] || fail "$(plain "$(top_line)")"
}

test_twoline_top_line_layout() {
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT PROMPT_SYMBOL
  load_theme
  local want="╔═(${(%):-%n}🪐${(%):-%m})═[${(%):-%(6~.%-1~/…/%4~.%5~)}]"
  assert_eq "$(plain "$(top_line)")" "$want"
}

test_twoline_prompt_symbol_overrides_planet() {
  PROMPT_SYMBOL=@
  load_theme
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  [[ $(plain "$(top_line)") == "╔═(${(%):-%n}@${(%):-%m})"* ]] ||
    fail "$(plain "$(top_line)")"
}

test_twoline_frame_is_grey_red_for_root() {
  load_theme
  [[ $PROMPT == '%F{%(#.#f38ba8.#6c7086)}╔═'* ]] || fail "frame color: ${PROMPT[1,40]}"
}

test_twoline_user_is_blue_host_mauve() {
  load_theme
  [[ $PROMPT == *'%B%F{%(#.#f38ba8.#5f9cff)}%n%b'* ]] || fail "user color"
  [[ $PROMPT == *'%B%F{#cba6f7}%m%b'* ]] || fail "host color"
}

test_rprompt_shows_branch_in_peach() {
  load_theme
  git_prompt_info() { print -n main }
  local r=${(e)RPROMPT}
  assert_eq "$(plain "$r")" '[main]'
  [[ $r == *'%F{#fab387}main'* ]] || fail "branch not peach: $r"
}

test_rprompt_empty_outside_git() {
  load_theme
  git_prompt_info() { : }
  assert_eq "${(e)RPROMPT}" ''
}

test_twoline_top_line_hides_venv_when_inactive() {
  load_theme
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  [[ $(top_line) != *🐍* ]] || fail "venv segment shown: $(top_line)"
}

test_vi_mode_sets_emoji_color_label_per_mode() {
  stub_zvm
  load_theme
  local -A want=(
    $ZVM_MODE_INSERT      '📝 #a6e3a1  INSERT'
    $ZVM_MODE_NORMAL      '🧭 #89b4fa  NORMAL'
    $ZVM_MODE_VISUAL      '👀 #cba6f7  VISUAL'
    $ZVM_MODE_VISUAL_LINE '📏 #cba6f7  V-LINE'
    $ZVM_MODE_REPLACE     '🔄 #f38ba8 REPLACE'
  )
  local mode
  for mode in ${(k)want}; do
    ZVM_MODE=$mode
    _yupps_vi_mode
    assert_eq "$psvar[1] $psvar[2] $psvar[3]" "$want[$mode]" "mode $mode"
  done
}

# A shorter label must cover a longer one when the slot is redrawn.
test_vi_mode_slot_has_fixed_width() {
  stub_zvm
  load_theme
  local mode
  for mode in $ZVM_MODE_INSERT $ZVM_MODE_NORMAL $ZVM_MODE_VISUAL \
      $ZVM_MODE_VISUAL_LINE $ZVM_MODE_REPLACE; do
    ZVM_MODE=$mode
    _yupps_vi_mode
    local slot=$(plain "$_yupps_slot")
    assert_eq "${(m)#slot}" 10 "mode $mode: [$slot]"
  done
}

test_vi_mode_label_is_bold_mode_color() {
  stub_zvm
  load_theme
  assert_eq "$_yupps_slot" '%(1V.%B%F{%2v}%3v%b%f %1v.)'
}

# zsh-vi-mode skips the mode hooks when a new line starts in the mode the
# last one ended in, so the first prompt and each one after an insert-mode
# command would show no mode.
test_precmd_syncs_vi_mode() {
  stub_zvm
  load_theme
  psvar=()
  ZVM_MODE=$ZVM_MODE_INSERT
  _yupps_precmd >/dev/null
  assert_eq "$psvar[1]" 📝
}

test_vi_mode_hook_registered() {
  load_theme
  (( ${zvm_after_select_vi_mode_commands[(Ie)_yupps_vi_mode]} )) ||
    fail "hook missing: $zvm_after_select_vi_mode_commands"
}

# The bottom line is frozen by zshrinkwrap, so the mode must come from a
# prompt escape that zle re-expands on every redraw, not a parameter.
test_twoline_bottom_line_is_clean() {
  stub_zvm
  load_theme
  local bottom=${PROMPT##*$'\n'}
  ZVM_MODE=$ZVM_MODE_NORMAL
  _yupps_vi_mode
  assert_eq "$(plain "$bottom")" '╚═❯ ' "with a mode"
  psvar=()
  assert_eq "$(plain "$bottom")" '╚═❯ ' "without a mode"
}

# Top line as printed for a prompt in /, after precmd.
top_at_root() {
  cd /
  _yupps_precmd >/dev/null
  plain "$(top_line)"
}

test_twoline_top_right_shows_mode() {
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT PROMPT_SYMBOL
  stub_zvm
  load_theme
  COLUMNS=80 ZVM_MODE=$ZVM_MODE_NORMAL
  local top=$(top_at_root)
  local left="╔═(${(%):-%n}🪐${(%):-%m})═[/]"
  [[ $top == "$left "*' NORMAL 🧭' ]] || fail "top: [$top]"
  assert_eq "${(m)#top}" 79 "ends one column before the edge"
}

test_twoline_top_right_follows_width() {
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  stub_zvm
  load_theme
  COLUMNS=80 ZVM_MODE=$ZVM_MODE_INSERT
  cd /
  _yupps_precmd >/dev/null
  COLUMNS=100
  local top=$(plain "$(top_line)")
  assert_eq "${(m)#top}" 99
}

test_twoline_top_right_narrow_keeps_one_space() {
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  stub_zvm
  load_theme
  COLUMNS=10 ZVM_MODE=$ZVM_MODE_INSERT
  [[ $(top_at_root) == *'/]  INSERT 📝' ]] || fail "$(top_at_root)"
}

# Output of the top-right redraw for the given typed text.
paint() {
  zle() { return 0 }
  LBUFFER=$1
  _yupps_paint_mode
}

paint_setup() {
  unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  stub_zvm
  load_theme
  COLUMNS=60 LINES=40 ZVM_MODE=$ZVM_MODE_NORMAL
  cd /
  _yupps_precmd >/dev/null
}

test_paint_redraws_top_right_slot() {
  paint_setup
  assert_eq "$(paint 'git status')" $'\e7\e[1A\e[50G'"${(%)_yupps_slot}"$'\e8'
}

test_paint_climbs_past_wrapped_command() {
  paint_setup
  [[ $(paint ${(l:70::x:)}) == $'\e7\e[2A'* ]] || fail "$(paint ${(l:70::x:)} | od -c | head -2)"
}

test_paint_climbs_past_multiline_command() {
  paint_setup
  [[ $(paint $'echo a\nb') == $'\e7\e[2A'* ]] || fail "one newline"
  [[ $(paint $'a\n\nb') == $'\e7\e[3A'* ]] || fail "empty line"
}

test_paint_skips_when_top_line_does_not_fit() {
  paint_setup
  COLUMNS=25
  assert_eq "$(paint ls)" ''
}

test_paint_skips_when_top_line_is_off_screen() {
  paint_setup
  LINES=2
  assert_eq "$(paint ${(l:70::x:)})" ''
}

test_paint_skips_outside_zle() {
  paint_setup
  zle() { return 1 }
  LBUFFER=ls
  assert_eq "$(_yupps_paint_mode)" ''
}

test_paint_skips_in_oneline() {
  paint_setup
  PROMPT_ALTERNATIVE=oneline
  configure_prompt
  assert_eq "$(paint ls)" ''
}

test_mode_change_repaints() {
  paint_setup
  zle() { return 0 }
  LBUFFER=ls ZVM_MODE=$ZVM_MODE_VISUAL
  [[ $(_yupps_vi_mode) == $'\e7'*VISUAL* ]] || fail "no repaint"
}

test_twoline_symbol_is_mauve() {
  load_theme
  [[ ${PROMPT##*$'\n'} == *'%B%(#.%F{#f38ba8}#.%F{#cba6f7}❯)%b%f '* ]] ||
    fail "symbol: ${PROMPT##*$'\n'}"
}

test_oneline_shows_vi_mode_on_the_right() {
  stub_zvm
  load_theme
  PROMPT_ALTERNATIVE=oneline
  configure_prompt
  ZVM_MODE=$ZVM_MODE_VISUAL
  _yupps_vi_mode
  git_prompt_info() { : }
  [[ $(plain "$PROMPT") == *' ❯ ' && $(plain "$PROMPT") != *👀* ]] ||
    fail "left: $(plain "$PROMPT")"
  assert_eq "$(plain "${(e)RPROMPT}")" '  VISUAL 👀' right
}

test_highlight_styles_use_catppuccin() {
  load_theme
  assert_eq "$ZSH_HIGHLIGHT_STYLES[command]" 'fg=#a6e3a1' command
  assert_eq "$ZSH_HIGHLIGHT_STYLES[unknown-token]" 'fg=#eba0ac' unknown-token
  assert_eq "$ZSH_HIGHLIGHT_STYLES[single-quoted-argument]" 'fg=#f9e2af' string
  assert_eq "$ZSH_HIGHLIGHT_STYLES[double-hyphen-option]" 'fg=#fab387' option
  assert_eq "$ZSH_HIGHLIGHT_STYLES[comment]" 'fg=#585b70' comment
}

test_vi_visual_selection_is_grey() {
  load_theme
  assert_eq "$ZVM_VI_HIGHLIGHT_BACKGROUND" '#45475a' background
  assert_eq "$ZVM_VI_HIGHLIGHT_FOREGROUND" '#cdd6f4' foreground
}

test_vi_mode_cursor_shapes() {
  stub_zvm
  load_theme
  assert_eq "$ZVM_INSERT_MODE_CURSOR" be insert
  assert_eq "$ZVM_NORMAL_MODE_CURSOR" bl normal
  assert_eq "$ZVM_VISUAL_MODE_CURSOR" bbl visual
  assert_eq "$ZVM_VISUAL_LINE_MODE_CURSOR" bbl visual-line
  assert_eq "$ZVM_OPPEND_MODE_CURSOR" ul replace/oppend
}

run_all
