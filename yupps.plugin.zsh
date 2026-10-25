# yupps-zsh: shell functions, tool wrappers and completions, in conf.d/*.zsh
# (name order; files starting with ~ are skipped). The yupps theme is in
# themes/ for oh-my-zsh-style loaders ($ZSH_CUSTOM/themes).

for _yupps_f in ${0:A:h}/conf.d/*.zsh(N); do
  [[ ${_yupps_f:t} == '~'* ]] || source $_yupps_f
done
unset _yupps_f
