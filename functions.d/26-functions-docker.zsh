# Docker helpers.

##? run-in-container CONTAINER CMD [ARGS...] - run host CMD in CONTAINER's network and PID namespaces (e.g. tcpdump, ss, ps)
function run-in-container() {
    emulate -L zsh

    if (( $# < 2 )); then
        print -u2 "usage: run-in-container CONTAINER CMD [ARGS...]"
        return 2
    fi

    local container=$1 info pid id
    shift
    info=$(command docker inspect --type container -f '{{.State.Pid}} {{.Id}}' -- $container) ||
        return 1
    pid=${info%% *} id=${info#* }
    if [[ $pid != <1-> ]]; then
        print -u2 "run-in-container: $container is not running"
        return 1
    fi

    # A remote daemon (DOCKER_HOST, Docker Desktop's VM) reports a PID from
    # another machine; never enter whatever local process has that PID.
    if [[ -z $id || ! -r /proc/$pid/cgroup || $(</proc/$pid/cgroup) != *$id* ]]; then
        print -u2 "run-in-container: PID $pid is not $container's on this host (remote Docker daemon?)"
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
