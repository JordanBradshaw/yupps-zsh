##? wrap-sudo [-u USER] CMD [ARGS...] - sudo wrapper which expands aliases and handles noglob/nocorrect
##? usage: alias sudo='noglob wrap-sudo '  (not enabled by default, see 30-aliases.zsh)
function wrap-sudo() {
    emulate -L zsh
    setopt extended_glob no_nomatch

    integer glob=1
    local -a run
    run=(command sudo)

    if (( $# > 1 )) && [[ $1 == -u ]]; then
        run+=("$1" "$2")
        shift 2
    fi

    while (( $# )); do
        case $1 in
            command|exec|-)
                shift
                break
                ;;
            nocorrect)
                shift
                ;;
            noglob)
                glob=0
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if (( glob )); then
        ${run} $~==*
    else
        ${run} $==*
    fi
}
(( ${+functions[compdef]} )) && compdef _sudo wrap-sudo

##? wrap-man [ARGS...] - coloured man without spelling-correction prompts
function wrap-man() {
    emulate -L zsh

    # When MANPAGER is bat, it does the coloring; termcaps only affect less.
    if [[ $MANPAGER != *bat* ]]; then
        # with new groff we need to explicitly ask for color support
        local -x MANROFFOPT=-c

        # set originally "bold" as "bold and red"
        # set originally "underline" as "underline and green"

        # termcap codes
        # md    start bold
        # mb    start blink
        # me    turn off bold, blink and underline
        # so    start standout (reverse video)
        # se    stop standout
        # us    start underline
        # ue    stop underline
        local -x LESS_TERMCAP_md=$(echoti bold; echoti setaf 1)
        local -x LESS_TERMCAP_mb=$(echoti blink)
        local -x LESS_TERMCAP_me=$(echoti sgr0)
        local -x LESS_TERMCAP_so=$(echoti smso)
        local -x LESS_TERMCAP_se=$(echoti rmso)
        local -x LESS_TERMCAP_us=$(echoti smul; echoti setaf 2)
        local -x LESS_TERMCAP_ue=$(echoti sgr0)
    fi

    nocorrect command man "$@"

    # vim: ft=zsh
}
