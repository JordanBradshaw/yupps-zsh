# _zc_init_cache: cache a tool's shell init script (zoxide init zsh, atuin init
# zsh, direnv hook zsh, ...), so shells don't run the tool on every startup.
# The cache is rebuilt when the binary changes or the init command does.
#
#   _zc_init_cache zoxide init zsh && source $REPLY

zmodload -F zsh/files b:zf_mkdir b:zf_mv b:zf_rm

##? _zc_init_cache CMD ARGS... - set $REPLY to a cached copy of `CMD ARGS` output; fail if CMD is missing or fails
function _zc_init_cache() {
  emulate -L zsh
  local bin=${commands[$1]}
  [[ -n $bin ]] || return 1

  local dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init
  local cache=$dir/$1.zsh
  local header="# $bin ${@[2,-1]}"

  if [[ ! -s $cache || $bin -nt $cache || ${"$(<$cache)"%%$'\n'*} != $header ]]; then
    zf_mkdir -p $dir
    { print -r -- $header; "$bin" "${@[2,-1]}" } >| $cache.tmp 2>/dev/null
    if (( $? )) || [[ $(<$cache.tmp) == $header ]]; then
      zf_rm -f $cache.tmp
      return 1
    fi
    zf_mv -f $cache.tmp $cache
  fi
  REPLY=$cache
}
