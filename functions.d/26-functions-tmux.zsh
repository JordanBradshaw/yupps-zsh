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
