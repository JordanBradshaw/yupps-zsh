# Debugging helpers: logs, network and zsh itself.
# Related helpers elsewhere: lsopenports, envdiff, whichall, lj-host, lj-debug.

# -------------------------------------------------------------------
# Logs
# -------------------------------------------------------------------

unalias journalctl 2>/dev/null
##? journalctl [ARGS...] - journalctl with tspin/bat color and safe privilege handling
function journalctl() {
    emulate -L zsh

    if (( ! ${+commands[journalctl]} )); then
        print -u2 "journalctl: command not found"
        return 127
    fi

    local -a args cmd pipe_status
    local arg group
    local -i explicit_output=0 user_journal=0 informational=0 passthrough=0 parsing_options=1
    local -i journal_access=0

    for arg in "$@"; do
        if (( parsing_options )) && [[ $arg == -- ]]; then
            parsing_options=0
            continue
        fi

        (( parsing_options )) || continue
        case $arg in
            --user)
                user_journal=1
                ;;
            -h|--help|--version)
                informational=1
                ;;
            -o|--output|-o?*|--output=*)
                explicit_output=1
                ;;
            --disk-usage|--verify|--verify-key|--sync|--flush|--rotate|\
            --relinquish-var|--smart-relinquish-var|--setup-keys|--vacuum-*)
                passthrough=1
                ;;
        esac
    done

    # Help and version information never need elevated access.
    if (( informational )); then
        command journalctl "$@"
        return
    fi

    # systemd grants full journal access to these groups on common distros.
    # Check at invocation time so a newly opened login shell picks up changes.
    if (( EUID != 0 && ! user_journal && ${+commands[id]} )); then
        for group in ${(s: :)$(command id -nG 2>/dev/null)}; do
            if [[ $group == systemd-journal || $group == adm || $group == wheel ]]; then
                journal_access=1
                break
            fi
        done
    fi

    if (( user_journal || EUID == 0 || journal_access )); then
        cmd=(journalctl)
    elif (( ${+commands[sudo]} )); then
        cmd=(sudo journalctl)
    else
        print -u2 "journalctl: sudo is required to read the system journal"
        return 127
    fi

    # Maintenance and verification output is not a stream of log records.
    if (( passthrough )); then
        command "${cmd[@]}" "$@" --no-pager
        return
    fi

    args=("$@")
    (( explicit_output )) || args+=(--output=short-iso-precise)
    # Keep this last: even a caller-supplied pager option cannot start a
    # privileged pager whose shell escapes would run as root.
    args+=(--no-pager)

    # Preserve machine-readable formats and non-interactive output.
    if (( explicit_output )) || [[ ! -t 1 ]] || [[ -n ${NO_COLOR:-} ]]; then
        command "${cmd[@]}" "${args[@]}"
        return
    fi

    if (( ${+commands[tspin]} )); then
        command "${cmd[@]}" "${args[@]}" | command tspin
        pipe_status=("${pipestatus[@]}")
        (( pipe_status[1] )) && return ${pipe_status[1]}
        return ${pipe_status[2]}
    fi

    if (( ${+commands[bat]} )); then
        command "${cmd[@]}" "${args[@]}" |
            command bat --style=plain --paging=never --color=always --language=log
        pipe_status=("${pipestatus[@]}")
        (( pipe_status[1] )) && return ${pipe_status[1]}
        return ${pipe_status[2]}
    fi

    command "${cmd[@]}" "${args[@]}"
}

##? sj [JOURNALCTL_ARGS...] - compatibility shorthand for the journalctl wrapper
function sj() {
    journalctl "$@"
}

##? jerr [SINCE] - journal errors (err and worse) for this boot, or since SINCE (e.g. 1 hour ago)
function jerr() {
    if (( $# )); then
        journalctl -p err --since "$*"
    else
        journalctl -p err -b
    fi
}

##? jboot [N] - journal errors from boot N (default -1, the previous boot)
function jboot() {
    journalctl -p err -b "${1:--1}"
}

##? jfollow UNIT - follow a unit's journal
function jfollow() {
    if (( $# != 1 )); then
        print -u2 "usage: jfollow UNIT"
        return 2
    fi
    journalctl -f -u "$1"
}

##? failed - failed systemd units, system and user
function failed() {
    print -P "%BSystem%b"
    command systemctl --failed --no-pager
    print -P "\n%BUser%b"
    command systemctl --user --failed --no-pager
}

##? kmsg - kernel warnings and errors for this boot
function kmsg() {
    journalctl -k -b -p warning
}

# -------------------------------------------------------------------
# Processes
# -------------------------------------------------------------------

##? printenv_pid PID [NAME...] - environment PID was started with, sorted (bat-colored on a terminal); with NAMEs, just their values
function printenv_pid() {
    emulate -L zsh

    if (( $# < 1 )) || [[ $1 != <1-> ]]; then
        print -u2 "usage: printenv_pid PID [NAME...]"
        return 2
    fi

    local pid=$1 file=/proc/$1/environ data
    shift
    if [[ ! -e $file ]]; then
        print -u2 "printenv_pid: no such process: $pid"
        return 1
    fi

    # Readable only by the owner (and root); NUL-separated.
    { data=$(<$file) } 2>/dev/null ||
        if (( EUID )) && (( ${+commands[sudo]} )); then
            data=$(command sudo cat -- $file) || return 1
        else
            print -u2 "printenv_pid: cannot read $file"
            return 1
        fi

    local -a vars=(${(0)data})

    # Like printenv NAME: values only; status 1 if any NAME is unset. The
    # first entry wins, as for getenv.
    if (( $# )); then
        local name entry
        integer missing=0
        for name in "$@"; do
            entry=${vars[(r)${(b)name}=*]}
            if [[ -n $entry ]]; then
                print -r -- ${entry#*=}
            else
                missing=1
            fi
        done
        return missing
    fi

    vars=(${(o)vars})
    if [[ ! -t 1 ]]; then
        (( $#vars )) && print -rl -- $vars
        return 0
    fi

    # On a terminal: the command line as a header comment, then colors.
    local cmdline
    { cmdline=${(j: :)${(0)"$(</proc/$pid/cmdline)"}} } 2>/dev/null
    [[ -n $cmdline ]] || { cmdline="[$(</proc/$pid/comm)]" } 2>/dev/null
    local -a lines=("# PID $pid: $cmdline" $vars)

    local bat
    if [[ -z ${NO_COLOR:-} ]]; then
        (( ${+commands[bat]} )) && bat=bat
        (( ${+commands[batcat]} )) && bat=batcat
    fi
    if [[ -n $bat ]]; then
        print -rl -- $lines |
            command $bat --language=dotenv --style=plain --paging=never --color=always
    else
        print -rl -- $lines
    fi
}

# -------------------------------------------------------------------
# Network
# -------------------------------------------------------------------

##? port PORT - sockets on PORT (listening or connected) and their processes
function port() {
    if [[ $1 != <1-65535> ]]; then
        print -u2 "usage: port PORT"
        return 2
    fi
    # Other users' processes are only shown to root.
    local -a pre
    (( EUID )) && (( ${+commands[sudo]} )) && pre=(sudo)
    command $pre ss -tunap "( sport = :$1 or dport = :$1 )"
}

##? tcpcheck HOST PORT - can HOST:PORT be reached (3 second timeout)
function tcpcheck() {
    if (( $# != 2 )); then
        print -u2 "usage: tcpcheck HOST PORT"
        return 2
    fi
    command nc -zv -w 3 "$1" "$2"
}

##? dnsq NAME - resolve NAME with the system resolver and with 1.1.1.1, to spot local DNS problems
function dnsq() {
    if (( $# != 1 )); then
        print -u2 "usage: dnsq NAME"
        return 2
    fi
    print -P "%BSystem resolver%b"
    if (( ${+commands[resolvectl]} )); then
        command resolvectl query -- "$1"
    else
        getent ahosts "$1"
    fi
    print -P "\n%Bdig @1.1.1.1%b"
    command dig +short @1.1.1.1 "$1"
}

##? netinfo - interfaces, routes and DNS servers
function netinfo() {
    print -P "%BInterfaces%b"
    command ip -br -c addr
    print -P "\n%BRoutes%b"
    command ip -c route
    if (( ${+commands[resolvectl]} )); then
        print -P "\n%BDNS%b"
        command resolvectl dns
    fi
}

# -------------------------------------------------------------------
# zsh
# -------------------------------------------------------------------

##? zsh-bench [N] - time interactive zsh startup N times (default 5); deferred plugins are not counted
function zsh-bench() {
    emulate -L zsh
    zmodload zsh/datetime
    local -i n=${1:-5} i
    local -F start ms total=0

    for (( i = 1; i <= n; i++ )); do
        start=$EPOCHREALTIME
        command zsh -i -c exit </dev/null >/dev/null 2>&1
        ms=$(( (EPOCHREALTIME - start) * 1000 ))
        (( total += ms ))
        printf 'run %d: %.0f ms\n' $i $ms
    done
    printf 'average: %.0f ms\n' $(( total / n ))
}

##? zsh-prof - profile interactive zsh startup with zprof (needs the ZSH_PROF line in .zshrc)
function zsh-prof() {
    ZSH_PROF=1 command zsh -i -c zprof
}

##? wherefrom NAME - what NAME is and where it is defined
function wherefrom() {
    emulate -L zsh
    zmodload -F zsh/parameter p:functions_source
    if (( $# != 1 )); then
        print -u2 "usage: wherefrom NAME"
        return 2
    fi

    local name=$1 file
    integer found=0
    if (( ${+aliases[$name]} )); then
        print -r -- "alias: $name=${(q+)aliases[$name]}"
        found=1
    fi
    if (( ${+functions[$name]} )); then
        print -r -- "function: ${functions_source[$name]:-(defined interactively)}"
        found=1
    fi
    if (( ${+builtins[$name]} )); then
        print -r -- "builtin: $name"
        found=1
    fi
    for file in ${(f)"$(whence -ap -- $name 2>/dev/null)"}; do
        if [[ $file:A != $file ]]; then
            print -r -- "command: $file -> $file:A"
        else
            print -r -- "command: $file"
        fi
        found=1
    done

    (( found )) || { print -u2 "wherefrom: $name not found"; return 1 }
}

##? ztrace CMD [ARGS...] - run one command with xtrace, in a subshell
function ztrace() {
    (
        PS4='+%x:%I> '
        setopt xtrace
        "$@"
    )
}
