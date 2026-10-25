#!/usr/bin/env -S zsh -f
#
# Tests for conf.d/27-functions-help.zsh and the ##? note convention.
# Run: zsh -f tests/help_test.zsh
#
# Notes are consecutive `##? ` comment lines directly above a function
# definition. The first line is `NAME [ARGS...] - summary`; later lines are
# extra help.

typeset -g REPO_DIR=${0:A:h:h}
typeset -g CONF=$REPO_DIR/conf.d/27-functions-help.zsh
source $REPO_DIR/tests/lib.zsh

# load_conf [FILE CONTENT]...: source the help functions and point them at a
# fixture directory holding the given files.
load_conf() {
  source $CONF
  _zc_help_dir=$SANDBOX/notes
  mkdir -p $_zc_help_dir
  while (( $# >= 2 )); do
    print -r -- "$2" >| $_zc_help_dir/$1
    shift 2
  done
}

typeset -g FIXTURE='# not a note
##? greet NAME - say hello to NAME
##? Prints "hello, NAME".
function greet() {
  print "hello, $1"
}

##? bare - no-arguments helper
bare() { : }

##? _private_helper - internal
function _private_helper { : }

    ##? indented [X] - defined inside a block
    function indented () {
      :
    }

##? orphan - nothing defined below this note

function undocumented() { : }'

test_index_reads_summary_notes_and_location() {
  load_conf 10-a.zsh "$FIXTURE"
  _zc_help_index
  assert_eq "$_zc_help_summary[greet]" 'say hello to NAME' summary
  assert_eq "$_zc_help_notes[greet]" $'greet NAME - say hello to NAME\nPrints "hello, NAME".' notes
  assert_eq "$_zc_help_where[greet]" "$_zc_help_dir/10-a.zsh:4" where
}

test_index_understands_every_definition_form() {
  load_conf 10-a.zsh "$FIXTURE"
  _zc_help_index
  assert_eq "$_zc_help_summary[bare]" 'no-arguments helper' 'name() form'
  assert_eq "$_zc_help_summary[_private_helper]" 'internal' 'function name { form'
  assert_eq "$_zc_help_summary[indented]" 'defined inside a block' 'indented function name () form'
  assert_eq "$_zc_help_where[indented]" "$_zc_help_dir/10-a.zsh:15" 'indented line'
}

test_index_ignores_notes_not_directly_above_a_function() {
  load_conf 10-a.zsh "$FIXTURE"
  _zc_help_index
  assert_eq "${+_zc_help_summary[orphan]}" 0 orphan
  assert_eq "${+_zc_help_summary[undocumented]}" 0 undocumented
}

test_zhelp_lists_public_documented_functions() {
  load_conf 10-a.zsh "$FIXTURE"
  local out=$(zhelp)
  assert_eq "${(j:|:)${(f)out}//  #/ }" 'bare no-arguments helper|greet say hello to NAME|indented defined inside a block'
}

test_zhelp_all_includes_private_functions() {
  load_conf 10-a.zsh "$FIXTURE"
  local out=$(zhelp -a)
  [[ $out == *_private_helper* ]] || fail "zhelp -a: $out"
}

test_zhelp_name_shows_notes_and_location() {
  load_conf 10-a.zsh "$FIXTURE"
  assert_eq "$(zhelp greet)" $'greet NAME - say hello to NAME\nPrints "hello, NAME".\n\ndefined in '"$_zc_help_dir/10-a.zsh:4"
}

test_zhelp_unknown_name_fails() {
  load_conf 10-a.zsh "$FIXTURE"
  local err
  err=$(zhelp nope 2>&1) && fail 'zhelp nope succeeded'
  assert_eq "$err" 'zhelp: no ##? notes for nope'
}

test_zhelp_completion_describes_public_functions() {
  load_conf 10-a.zsh "$FIXTURE"
  _describe() { print -rl -- "${(@P)${@[-1]}}" }
  assert_eq "$(_zhelp)" $'bare:no-arguments helper\ngreet:say hello to NAME\nindented:defined inside a block'
}

test_default_dir_is_conf_d() {
  source $CONF
  assert_eq "$_zc_help_dir" "$REPO_DIR/conf.d"
}

# Every ##? block in conf.d must sit directly above a function and start with
# that function's name, so zhelp and the editor can find it.
test_every_conf_d_note_names_the_function_below_it() {
  local file line name
  local -a bad block
  integer n
  for file in $REPO_DIR/conf.d/*.zsh; do
    n=0 block=()
    for line in "${(@f)"$(<$file)"}"; do
      (( n++ ))
      if [[ $line == [[:space:]]#'##?'* ]]; then
        block+=("${${line##[[:space:]]#'##?'}# }")
        continue
      fi
      if (( $#block )); then
        name=
        if [[ $line == (#b)[[:space:]]#function[[:space:]]##([^[:space:]\(\{]##)* ||
              $line == (#b)[[:space:]]#([^[:space:]\(\{=]##)[[:space:]]#'()'* ]]; then
          name=$match[1]
        fi
        if [[ -z $name ]]; then
          bad+=("${file:t}:$n: note is not directly above a function")
        elif [[ $block[1] != $name(|' '*) || $block[1] != *' - '* ]]; then
          bad+=("${file:t}:$n: first line should be '$name [ARGS...] - summary', got '$block[1]'")
        fi
        block=()
      fi
    done
  done
  (( $#bad == 0 )) || fail ${(F)bad}
}

run_all
