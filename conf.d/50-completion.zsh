# Completion: completions for this plugin's functions, generated completions
# for tools that don't ship one, and _zc_ssh_hosts (Host names from ssh
# configs). zstyles are configuration and belong in the user's own config.
#
# compdef calls run in a one-shot precmd hook, after ez-compinit's compinit,
# so `_comps` can be checked to avoid replacing real completions.

autoload -Uz add-zsh-hook

##? _zc_ssh_hosts FILE... - set $reply to Host names from ssh configs, following Include
function _zc_ssh_hosts() {
  emulate -L zsh
  setopt extended_glob

  reply=()
  local -a queue=("$@") seen=() words matches
  local file line inc

  while (( $#queue )); do
    file=$queue[1]
    shift queue
    [[ -r $file ]] && (( ! ${seen[(Ie)$file]} )) || continue
    seen+=($file)

    for line in "${(@f)$(<$file)}"; do
      words=(${=line%%\#*})
      (( $#words )) || continue
      case ${(L)words[1]} in
        host)
          reply+=(${words[2,-1]:#*[*?!]*})
          ;;
        include)
          for inc in $words[2,-1]; do
            inc=${inc/#\~/$HOME}
            [[ $inc == /* ]] || inc=$HOME/.ssh/$inc
            matches=(${~inc}(N))
            queue+=($matches)
          done
          ;;
      esac
    done
  done

  reply=(${(u)reply})
}

##? _zc_gencomp CMD ARGS... - cache `CMD ARGS` completion output and source it
function _zc_gencomp() {
  emulate -L zsh
  local bin=${commands[$1]}
  [[ -n $bin ]] || return 1

  # Not oh-my-zsh's $ZSH_CACHE_DIR/completions: that is on fpath, and these
  # scripts are meant to be sourced, not autoloaded.
  local dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/gencomp
  local cache=$dir/_$1

  if [[ ! -s $cache || $bin -nt $cache ]]; then
    [[ -d $dir ]] || mkdir -p $dir
    if "$@" >| $cache.tmp 2>/dev/null && [[ -s $cache.tmp ]]; then
      mv -f $cache.tmp $cache
    else
      rm -f $cache.tmp
    fi
  fi

  [[ -s $cache ]] || return 1
  # eval, not source: shtab scripts (tldr) only register via compdef when
  # $zsh_eval_context ends in eval.
  eval "$(<$cache)"

  # Autoload-style scripts (older cobra, e.g. depot) define _<cmd> but never
  # call compdef.
  if (( ! ${+_comps[$1]} && ${+functions[_$1]} )); then
    compdef _$1 $1
  fi
}

function _zc_pathremove() {
  compadd -a path
}

# System and user units, for jfollow.
function _zc_units() {
  local -a units
  units=(${${(f)"$(systemctl list-units --all --plain --no-legend 2>/dev/null;
                   systemctl --user list-units --all --plain --no-legend 2>/dev/null)"}%% *})
  _describe -t units unit units
}

# Running Docker containers, described by image.
function _zc_docker_containers() {
  local -a containers
  containers=(${(f)"$(command docker ps --format '{{.Names}}:{{.Image}}' 2>/dev/null)"})
  _describe -t containers container containers
}

function _zc_run_in_container() {
  _arguments '1:container:_zc_docker_containers' '*:::command:_normal'
}

# Variable names in a process's environment (empty if unreadable).
function _zc_env_names() {
  local data
  local -a names
  { data=$(</proc/$1/environ) } 2>/dev/null
  names=(${(u)${${(0)data}%%=*}//:/\\:})
  _describe -t names 'environment variable' names
}

function _zc_printenv_pid() {
  _arguments '1:process:_pids' '*:environment variable:{_zc_env_names $words[2]}'
}

function _zc_completion_setup() {
  emulate -L zsh
  # compinit hasn't run yet; try again next prompt.
  (( ${+_comps} )) || return 0
  add-zsh-hook -d precmd _zc_completion_setup

  # Functions from this repo
  compdef _directories mkcd pathappend pathprepend
  compdef _files bak touchf tailf cdf lspath
  compdef _zc_pathremove pathremove
  compdef _zc_units jfollow
  compdef _zhelp zhelp
  compdef _zc_run_in_container run-in-container
  compdef _zc_printenv_pid printenv_pid
  # systemd ships _journalctl only next to a system zsh; zssh bundles lack it.
  (( ${+_comps[journalctl]} )) && compdef sj=journalctl
  compdef _precommand ineachdir
  compdef whichall=whence
  if (( ${+functions[tree]} && ${+_comps[eza]} )); then
    compdef tree=eza
  elif (( ${+functions[tree]} && ${+_comps[lsd]} )); then
    compdef tree=lsd
  fi

  # Debian/Ubuntu install fd as fdfind
  if (( ${+commands[fdfind]} && ! ${+_comps[fdfind]} && ${+functions[_fd]} )); then
    compdef _fd fdfind
  fi

  # Tools that can print their own completion script
  local gen
  local -a cmd
  for gen in \
    'lazygit completion zsh' \
    'chezmoi completion zsh' \
    'sake completion zsh' \
    'depot completion zsh' \
    'opencode --completions zsh' \
    'pnpm completion zsh' \
    'uv generate-shell-completion zsh' \
    'just --completions zsh' \
    'kubectl completion zsh' \
    'helm completion zsh' \
    'tldr --print-completion zsh'; do
    cmd=(${=gen})
    if (( ${+commands[$cmd[1]]} && ! ${+_comps[$cmd[1]]} )); then
      _zc_gencomp $cmd
    fi
  done

  # Everything else: options parsed from --help
  local tool
  for tool in duf btm micro eget lazydocker mlr; do
    if (( ${+commands[$tool]} && ! ${+_comps[$tool]} )); then
      compdef _gnu_generic $tool
    fi
  done
}
add-zsh-hook precmd _zc_completion_setup

# argcomplete tools (ros2) usually reach PATH mid-session, when a ROS
# setup.zsh is sourced, so check every prompt until one shows up.
function _zc_argcomplete_setup() {
  emulate -L zsh
  (( ${+_comps} && ${+commands[ros2]} )) || return 0
  add-zsh-hook -d precmd _zc_argcomplete_setup

  # ROS's setup.zsh registers its own completion.
  (( ${+_comps[ros2]} )) && return 0
  local reg=${commands[register-python-argcomplete]:-$commands[register-python-argcomplete3]}
  [[ -n $reg ]] || return 0
  local script
  script=$($reg ros2 2>/dev/null) || return 0
  # argcomplete < 3 prints a bash-only script.
  if [[ $script != *compdef* ]]; then
    autoload -Uz bashcompinit && bashcompinit
  fi
  eval "$script"
}
add-zsh-hook precmd _zc_argcomplete_setup
