
function tailf() {
    local nl
    tail -f "$1" | while read -r j; do
      print -n "$nl$j"
      nl="\n"
    done
}
##? touchf - makes any dirs recursively and then touches a file if it doesn't exist
function touchf() {
    if [[ -n "$1" ]] && [[ ! -f "$1" ]]; then
      mkdir -p "$1:h" && touch "$1"
    fi

}
