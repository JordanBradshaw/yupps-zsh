# yupps-zsh

Shell functions, tool wrappers, completions and zstyles for zsh, plus the
yupps prompt theme. Everything degrades gracefully: a wrapper only takes over
when its tool (eza, lsd, bat, tspin, delta, ...) is installed.

## Layout

| Dir | Holds | Loaded by |
|---|---|---|
| `zshenv.d/` | environment: toolchain bin dirs on PATH | your `.zshenv` |
| `functions.d/` | shell functions (`zhelp` lists them) | `yupps.plugin.zsh` |
| `zshrc.d/` | aliases, the `_zc_init_cache` helper, completions | `yupps.plugin.zsh` |
| `zstyles.d/` | completion, fzf-tab, ssh-agent and zshrinkwrap zstyles | `yupps.plugin.zsh` |
| `themes/` | `yupps.zsh-theme`, `yupps-classic.zsh-theme` | `$ZSH_CUSTOM/themes` loaders |

`yupps.plugin.zsh` sources `functions.d`, `zshrc.d` and `zstyles.d`, in that
order and each in name order; files starting with `~` are skipped. Load it
after the plugins whose zstyles it sets defaults over (oh-my-zsh's
`lib/completion.zsh`).

`zshenv.d` is not sourced by the plugin, so that scripts and `zsh -c` get the
same PATH as interactive shells. Source it from `.zshenv`, before the
plugin manager runs (files starting with `~` are skipped here too):

```zsh
() {
  local f
  for f in ${YUPPS_DIR:-${ZDOTDIR:-$HOME}/plugins/yupps-zsh}/zshenv.d/*.zsh(N); do
    [[ ${f:t} == '~'* ]] || source $f
  done
}
```

Tests: `bash tests/run.sh`.
