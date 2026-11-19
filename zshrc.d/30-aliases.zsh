# -------------------------------------------------------------------
# sudo
#
# Trailing space makes zsh alias-expand the word after sudo, so
# `sudo ip a` becomes `sudo ip -c a`. Function wrappers below (ls, cat,
# grep, man, ...) are never passed to sudo; it runs the real binaries.
# -------------------------------------------------------------------
alias sudo='sudo '


# -------------------------------------------------------------------
# man
#
# A function rather than an alias, so `sudo man` still works.
# -------------------------------------------------------------------
if (( ${+commands[man]} )) && (( ${+functions[wrap-man]} )); then
    unalias man 2>/dev/null
    function man() {
        wrap-man "$@"
    }
fi


# -------------------------------------------------------------------
# fd -> fdfind
# This one is safe: same program, Debian/Ubuntu naming difference.
# -------------------------------------------------------------------
if (( ${+commands[fd]} )); then
    :
elif (( ${+commands[fdfind]} )); then
    alias fd="fdfind"
fi


# -------------------------------------------------------------------
# ls -> eza, else lsd
#
# eza does not share ls's short flags (-t takes a value, -h is
# --header), so common ones are translated and anything else goes to
# lsd, or to GNU ls. lsd in turn hands GNU-only options to GNU ls.
# Explicit /bin/ls or command ls always bypasses this anyway.
# -------------------------------------------------------------------

##? _zc_ls_eza_args ARGS... - set $reply to eza arguments for ls ARGS; fail if eza can't express them
function _zc_ls_eza_args() {
    emulate -L zsh
    reply=()
    local arg sort= flag
    integer reverse=0 i operand=0

    while (( $# )); do
        arg=$1
        shift
        case $arg in
            --)
                reply+=(-- "$@")
                (( $# )) && operand=1
                break
                ;;
            --(all|almost-all|directory|recursive|inode|dereference|classify|group-directories-first|no-git)|--color=*)
                reply+=($arg)
                ;;
            --reverse)
                (( reverse ^= 1 ))
                ;;
            -[^-]*)
                for (( i = 2; i <= $#arg; i++ )); do
                    flag=$arg[i]
                    case $flag in
                        [aAdRiF1]) reply+=(-$flag) ;;
                        l) reply+=(--long) ;;
                        h) ;;
                        r) (( reverse ^= 1 )) ;;
                        t) sort=time ;;
                        S) sort=size ;;
                        U) sort=none ;;
                        *) return 1 ;;
                    esac
                done
                ;;
            -?*)
                return 1
                ;;
            *)
                reply+=($arg)
                operand=1
                ;;
        esac
    done

    # ls -t and -S list newest/largest first; eza sorts both ascending.
    local -a order
    case $sort in
        time) (( reverse )) && order=(--sort=modified) || order=(--sort=modified --reverse) ;;
        size) (( reverse )) && order=(--sort=size) || order=(--sort=size --reverse) ;;
        none) order=(--sort=none) ;;
        *) (( reverse )) && order=(--reverse) ;;
    esac
    reply=($order $reply)
    # With no file names and stdin not a terminal, eza reads names from stdin.
    (( operand )) || reply+=(.)
}

##? _zc_ls_gnu_only ARGS... - succeed if ARGS use options only GNU ls understands
function _zc_ls_gnu_only() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --) return 1 ;;
            --block-size=*|\
            --time-style=*|\
            --quoting-style=*|\
            --indicator-style=*|\
            --hide=*|\
            --ignore=*|\
            --format=*|\
            --sort=*|\
            --color=*|\
            --dired|\
            --full-time|\
            --author|\
            --context|\
            --zero)
                return 0
                ;;
        esac
    done
    return 1
}

if (( ${+commands[eza]} || ${+commands[lsd]} )); then
    unalias ls ll 2>/dev/null

    # --git costs ~0.01 s per listing; `ls --no-git` turns it off once.
    typeset -ga _zc_eza_ls=(
        eza --group-directories-first --icons=always --color=always
        --git --smart-group --time-style=long-iso --octal-permissions
    )

    function ls() {
        emulate -L zsh
        local -a reply

        if (( ${+commands[eza]} )) && _zc_ls_eza_args "$@"; then
            command $_zc_eza_ls "${reply[@]}"
        elif (( ${+commands[lsd]} )) && ! _zc_ls_gnu_only "$@"; then
            command lsd --long --group-dirs first --icon always "$@"
        else
            command ls "$@"
        fi
    }

    ##? ll [ARGS...] - full listing: hidden files, header, octal permissions, folder sizes
    function ll() {
        emulate -L zsh
        local -a reply

        if (( ${+commands[eza]} )) && _zc_ls_eza_args -a "$@"; then
            # --total-size walks every subfolder, so it is slow in big trees.
            command $_zc_eza_ls --long --header --total-size "${reply[@]}"
        else
            ls -la "$@"
        fi
    }

    function tree() {
        if (( ${+commands[eza]} )); then
            local -a args=("$@")
            # As in ls: name a directory so eza never reads names from stdin.
            (( ${args[(I)[^-]*]} )) || args+=(.)
            command eza --tree --level=4 --group-directories-first --icons=always --color=always "${args[@]}"
        else
            command lsd --tree --depth=4 "$@"
        fi
    }
fi


# -------------------------------------------------------------------
# cat -> bat (batcat on Debian/Ubuntu)
#
# For normal "show me this file", use bat.
# Fall back when options indicate actual cat semantics are wanted.
# -------------------------------------------------------------------
if (( ${+commands[batcat]} || ${+commands[bat]} )); then
    unalias cat 2>/dev/null

    function cat() {
        local arg bat=bat
        (( ${+commands[batcat]} )) && bat=batcat

        for arg in "$@"; do
            case "$arg" in
                -A|-b|-e|-E|-n|-s|-t|-T|-u|-v|\
                --show-all|\
                --number-nonblank|\
                --show-ends|\
                --number|\
                --squeeze-blank|\
                --show-tabs|\
                --show-nonprinting)
                    command cat "$@"
                    return
                    ;;
            esac
        done

        command $bat --paging=never "$@"
    }
fi


# -------------------------------------------------------------------
# grep -> ripgrep
#
# rg is only used when every option has the same meaning in both tools
# (e.g. -r, -h, -L, -s, -E, -I differ). Anything else goes to real grep.
# -------------------------------------------------------------------
if (( ${+commands[rg]} )); then
    unalias grep 2>/dev/null

    function grep() {
        emulate -L zsh
        setopt extended_glob
        local arg
        integer skip=0

        for arg in "$@"; do
            if (( skip )); then
                skip=0
                continue
            fi
            case "$arg" in
                --)
                    break
                    ;;
                --(ignore-case|invert-match|line-number|count|files-with-matches|word-regexp|line-regexp|only-matching|quiet|with-filename|no-filename|text|fixed-strings|perl-regexp|byte-offset|null))
                    ;;
                --(max-count|after-context|before-context|context|regexp|file|color)=*)
                    ;;
                --(max-count|after-context|before-context|context|regexp|file))
                    skip=1
                    ;;
                -[ABCm][0-9]##)
                    ;;
                -[ivnclwxoqHaFPb]#[ABCmef])
                    skip=1
                    ;;
                -[ivnclwxoqHaFPb]##)
                    ;;
                -?*)
                    command grep "$@"
                    return
                    ;;
            esac
        done

        command rg "$@"
    }
fi


# -------------------------------------------------------------------
# ip
#
# Same iproute2 command, just enable color.
# Very low-risk replacement.
# -------------------------------------------------------------------
if (( ${+commands[ip]} )); then
    alias ip="ip -c"
fi


# -------------------------------------------------------------------
# df -> duf
#
# duf is NOT a drop-in df replacement. Only use it for bare `df`.
# Any arguments/options go to real df.
# -------------------------------------------------------------------
if (( ${+commands[duf]} )); then
    unalias df 2>/dev/null
    function df() {
        if (( $# == 0 )); then
            command duf
        else
            command df "$@"
        fi
    }
else
    alias df="df -h"
fi


# -------------------------------------------------------------------
# du -> dust
#
# dust is also NOT command-line compatible with GNU du.
# Bare `du` gets dust; arguments go to real du.
# -------------------------------------------------------------------
if (( ${+commands[dust]} )); then
    unalias du 2>/dev/null
    function du() {
        if (( $# == 0 )); then
            command dust
        else
            command du "$@"
        fi
    }
fi


# -------------------------------------------------------------------
# apt -> nala where nala does exactly what apt would, else apt with extra
# options (see bin/zc-apt)
#
# An alias to a script rather than a function, so `sudo apt` uses it too.
# -------------------------------------------------------------------
if (( ${+commands[apt]} )); then
    alias apt="${${(%):-%x}:A:h:h}/bin/zc-apt"
fi


# -------------------------------------------------------------------
# lazyjournal
#
# Settings are passed as flags so they follow the repo; the local
# ~/.config/lazyjournal/config.yml keeps only machine-specific bits
# (ssh hosts for the F2 switcher, hotkeys). A flag only beats config.yml
# when it differs from lazyjournal's built-in default, so keep the
# `settings:` block out of config.yml.
# -------------------------------------------------------------------
if (( ${+commands[lazyjournal]} )); then
    typeset -ga _zc_lj_flags=(
        --tail-lines 20000
        --update-interval 2
        --min-symbols-filter 1
        --unit-types service
        --journal-field SYSLOG_IDENTIFIER
        --journal-priority debug
        --color-mode ${${commands[tspin]:+tailspin}:-default}
    )
    alias lazyjournal='lazyjournal $_zc_lj_flags'

    ##? _zc_lj_hosts - set $reply to hosts from ~/.ssh/config and lazyjournal's ssh.hosts
    function _zc_lj_hosts() {
        emulate -L zsh -o extended_glob
        local cfg=${XDG_CONFIG_HOME:-$HOME/.config}/lazyjournal/config.yml line
        local -a hosts
        integer in_ssh=0

        if (( ${+functions[_zc_ssh_hosts]} )); then
            _zc_ssh_hosts $HOME/.ssh/config
            hosts=($reply)
        fi
        if [[ -r $cfg ]]; then
            for line in "${(@f)$(<$cfg)}"; do
                case $line in
                    ssh:*) in_ssh=1 ;;
                    [^[:space:]\#]*) in_ssh=0 ;;
                    [[:space:]]##-[[:space:]]*)
                        (( in_ssh )) && hosts+=("${${${line#*-[[:space:]]}#\"}%\"}")
                        ;;
                esac
            done
        fi
        reply=(${(u)hosts})
    }

    ##? lj-host [HOST [ARGS...]] - lazyjournal over ssh; pick HOST with fzf when omitted
    function lj-host() {
        local host=$1
        (( $# )) && shift
        if [[ -z $host ]]; then
            local -a reply
            _zc_lj_hosts
            (( $#reply )) || { print -u2 "lj-host: no hosts in ~/.ssh/config or lazyjournal config"; return 1 }
            host=$(print -rl -- $reply | fzf --height=40% --reverse --prompt='lazyjournal host> ') || return
        fi
        command lazyjournal $_zc_lj_flags --ssh "$host" "$@"
    }

    ##? lj-debug [ARGS...] - lazyjournal with command logging; the log goes to the state dir
    function lj-debug() {
        local dir=${XDG_STATE_HOME:-$HOME/.local/state}/lazyjournal
        zmodload -F zsh/files b:zf_mkdir
        zf_mkdir -p $dir
        # lazyjournal writes lazyjournal.log to the current directory.
        ( cd $dir && command lazyjournal $_zc_lj_flags --logging "$@" )
        print -r -- "log: $dir/lazyjournal.log"
    }
fi


# -------------------------------------------------------------------
# tar shortcuts
# These don't replace tar, so they're inherently safe.
# -------------------------------------------------------------------
if (( ${+commands[tar]} )); then
    alias targz="tar -xvzf"
    alias tarbz2="tar -xvjf"
    alias tarxz="tar -xvJf"
fi


# -------------------------------------------------------------------
# htop -> btm
#
# btm is not CLI-compatible with htop.
# Bare `htop` gets btm; arguments go to actual htop.
# -------------------------------------------------------------------
if (( ${+commands[btm]} )); then
    unalias htop 2>/dev/null
    function htop() {
        if (( $# == 0 )); then
            command btm
        elif (( ${+commands[htop]} )); then
            command htop "$@"
        else
            command btm "$@"
        fi
    }
fi
