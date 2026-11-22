# tmux session helper. The same command works locally and over ssh, so a
# session started at the desk can be picked up from another machine and back.

##? t [SESSION] - attach to tmux SESSION (default $YUPPS_TMUX_SESSION, else main), creating it if needed; inside tmux, switch to it
function t() {
    emulate -L zsh
    if (( ! ${+commands[tmux]} )); then
        print -u2 "t: tmux not installed"
        return 127
    fi
    local name=${1:-${YUPPS_TMUX_SESSION:-main}}
    if [[ -n $TMUX ]]; then
        # Attaching from inside tmux would nest a client.
        command tmux has-session -t "=$name" 2>/dev/null ||
            command tmux new-session -d -s "$name" || return
        command tmux switch-client -t "=$name"
    else
        command tmux new-session -A -s "$name"
    fi
}

##? tssh [-s SESSION] [user@]HOST [SSH_ARGS...] - ssh to HOST and attach to its tmux SESSION (default $YUPPS_TMUX_SESSION, else main), creating it; plain ssh is unchanged
##? Detaching closes the connection and leaves the session running. Without
##? tmux on HOST it opens a normal login shell.
function tssh() {
    emulate -L zsh
    local -A opts
    local usage='usage: tssh [-s SESSION] [user@]HOST [SSH_ARGS...]'
    zparseopts -D -F -A opts s: 2>/dev/null || { print -u2 -r -- $usage; return 2 }
    if (( ! $# )); then
        print -u2 -r -- $usage
        return 2
    fi
    local host=$1
    shift
    local name=${opts[-s]:-${YUPPS_TMUX_SESSION:-main}}
    # Runs in the remote user's shell; the session name is quoted for it.
    local remote="command -v tmux >/dev/null 2>&1 && exec tmux new-session -A -s ${(q-)name}; exec \"\${SHELL:-sh}\" -l"
    command ssh -t "$@" $host $remote
}
