# yupps-zsh: shell functions, tool wrappers, completions and zstyles.
#
#   functions.d/  shell functions
#   zshrc.d/      aliases, the init-cache helper, completions
#   zstyles.d/    completion and plugin zstyles
#   zshenv.d/     environment (PATH); not sourced here: source it from
#                 .zshenv so every zsh gets it, not only interactive ones
#
# This file sources functions.d, zshrc.d and zstyles.d in that order, each in
# name order; files starting with ~ are skipped. The yupps theme is in themes/
# for oh-my-zsh-style loaders ($ZSH_CUSTOM/themes).

for _yupps_d in functions.d zshrc.d zstyles.d; do
  for _yupps_f in ${0:A:h}/$_yupps_d/*.zsh(N); do
    [[ ${_yupps_f:t} == '~'* ]] || source $_yupps_f
  done
done
unset _yupps_d _yupps_f
