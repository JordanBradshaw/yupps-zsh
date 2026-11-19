pathappend() {
  local d
  for d in "$@"; do
    [[ -d $d ]] && PATH="$PATH:$d"
  done
}

pathprepend() {
  local d
  for d in "$@"; do
    [[ -d $d ]] && PATH="$d:$PATH"
  done
}

pathremove() {
  local p newpath=()
  for p in ${(ps/:/)PATH}; do
    [[ $p != "$1" ]] && newpath+=("$p")
  done
  PATH="${(j/:/)newpath}"
}
