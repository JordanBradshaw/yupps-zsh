# ssh completion: hosts from ~/.ssh/config (and Include'd files) through the
# _zc_ssh_hosts (zshrc.d/50-completion.zsh), plus common users.

_zc_ssh_cmds='(ssh|scp|sftp|rsync|ssh-copy-id|mosh|sshfs)'

reply=()
(( ${+functions[_zc_ssh_hosts]} )) && _zc_ssh_hosts $HOME/.ssh/config
if (( $#reply )); then
  zstyle ":completion:*:${_zc_ssh_cmds}:*" hosts $reply
fi
zstyle ":completion:*:${_zc_ssh_cmds}:*" users root $USER
zstyle ":completion:*:${_zc_ssh_cmds}:*:hosts" ignored-patterns \
  localhost 'ip6-*' broadcasthost

unset _zc_ssh_cmds reply
