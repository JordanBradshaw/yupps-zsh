# Docker helpers.

##? run-in-container CONTAINER CMD [ARGS...] - run host CMD in CONTAINER's network and PID namespaces (e.g. tcpdump, ss, ps)
function run-in-container() {
    emulate -L zsh

    if (( $# < 2 )); then
        print -u2 "usage: run-in-container CONTAINER CMD [ARGS...]"
        return 2
    fi

    local container=$1 pid
    shift
    pid=$(command docker inspect -f '{{.State.Pid}}' $container) || return 1
    if [[ $pid != <1-> ]]; then
        print -u2 "run-in-container: $container is not running"
        return 1
    fi

    # sudo's secure_path would hide commands in user directories.
    local -a cmd=("$@")
    if [[ $cmd[1] != */* && -n ${commands[$cmd[1]]} ]]; then
        cmd[1]=${commands[$cmd[1]]}
    fi

    # The host filesystem stays visible; only /proc is remounted, in a private
    # mount namespace, so ps and friends see the container's PIDs.
    local -a run=(nsenter -t $pid -n -p -- unshare -m --mount-proc -- "${cmd[@]}")
    (( EUID )) && run=(sudo "${run[@]}")
    command "${run[@]}"
}
