# Help for this repo's functions, read from their `##?` notes.
#
# A note is one or more `##? ` comment lines directly above a function:
#
#   ##? NAME [ARGS...] - one-line summary
#   ##? optional extra lines (usage, caveats)
#   function NAME() {
#
# zhelp reads conf.d when it runs, so notes cost nothing at startup.

typeset -g _zc_help_dir=${${(%):-%x}:A:h}

##? _zc_help_index - fill _zc_help_summary, _zc_help_notes and _zc_help_where from the notes in $_zc_help_dir
function _zc_help_index() {
    emulate -L zsh
    setopt extended_glob
    typeset -gA _zc_help_summary=() _zc_help_notes=() _zc_help_where=()
    local file line name
    local -a block
    integer n
    for file in $_zc_help_dir/*.zsh(N); do
        n=0 block=()
        for line in "${(@f)"$(<$file)"}"; do
            (( n++ ))
            if [[ $line == [[:space:]]#'##?'(|' '*) ]]; then
                block+=("${${line##[[:space:]]#'##?'}# }")
                continue
            fi
            (( $#block )) || continue
            if [[ $line == (#b)[[:space:]]#function[[:space:]]##([^[:space:]\(\{]##)* ||
                  $line == (#b)[[:space:]]#([^[:space:]\(\{=]##)[[:space:]]#'()'* ]]; then
                name=$match[1]
                _zc_help_notes[$name]=${(F)block}
                _zc_help_where[$name]=$file:$n
                if [[ $block[1] == *' - '* ]]; then
                    _zc_help_summary[$name]=${block[1]#* - }
                else
                    _zc_help_summary[$name]=$block[1]
                fi
            fi
            block=()
        done
    done
}

##? zhelp [-a] [NAME] - list documented functions (-a includes _private ones), or show NAME's notes and where it is defined
function zhelp() {
    emulate -L zsh
    local all=0
    if [[ $1 == -a ]]; then
        all=1
        shift
    fi
    _zc_help_index

    if (( $# )); then
        if (( ! ${+_zc_help_notes[$1]} )); then
            print -u2 -r -- "zhelp: no ##? notes for $1"
            return 1
        fi
        print -r -- "$_zc_help_notes[$1]"
        print -r -- ""
        print -r -- "defined in $_zc_help_where[$1]"
        return 0
    fi

    local name
    local -a names
    integer width=0
    for name in ${(ko)_zc_help_summary}; do
        [[ $name == _* ]] && (( ! all )) && continue
        names+=("$name")
        (( $#name > width )) && width=$#name
    done
    for name in "${names[@]}"; do
        printf '%-*s  %s\n' $width "$name" "$_zc_help_summary[$name]"
    done
}

##? _zhelp - completion for zhelp: documented public function names with their summaries
function _zhelp() {
    _zc_help_index
    local name
    local -a described
    for name in ${(ko)_zc_help_summary}; do
        [[ $name == _* ]] && continue
        described+=("${name//:/\\:}:$_zc_help_summary[$name]")
    done
    _describe -t functions 'documented function' described
}
