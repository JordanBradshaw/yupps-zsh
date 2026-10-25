unalias ls 2>/dev/null
##? lspath - list all directories leading up to a filename; this is useful to see if some permissions are blocking access to a file.
function lspath () {
    emulate -L zsh
    local pathlist
    if [[ "${1}" = "${1##/}" ]]; then
        pathlist=(/ ${(s:/:)PWD} ${(s:/:)1})
    else
        pathlist=(/ ${(s:/:)1})
    fi
    local allpaths=()
    local filepath=${pathlist[1]}
    shift pathlist
    for i in ${pathlist[@]}; do
        allpaths=(${allpaths[@]} ${filepath})
        filepath="${filepath%/}/$i"
    done
    allpaths=(${allpaths[@]} ${filepath})
    ls -ldU -- "${allpaths[@]}"
    # vim: ft=zsh
}

function lsopenports() {
  if (( $+commands[ss] )); then
    ss -tuln
  else
    netstat -tuln
  fi
}
