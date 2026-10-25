# The following block is surrounded by two delimiters.
# These delimiters must not be modified. Thanks.
# START KALI CONFIG VARIABLES
#set -x
[ -n "$PROMPT_ALTERNATIVE" ] || PROMPT_ALTERNATIVE=twoline
[ -n "$NEWLINE_BEFORE_PROMPT" ] || NEWLINE_BEFORE_PROMPT=yes
# STOP KALI CONFIG VARIABLES
# echo "$NEWLINE_BEFORE_PROMPT $PROMPT_ALTERNATIVE"

# echo "\ue0b0 \u00b1 \ue0a0 \u27a6 \u2718 \u26a1 \u2699"
#  ±  ➦ ✘ ⚡ ⚙
# configure `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'
ZSH_THEME_GIT_PROMPT_PREFIX=''
ZSH_THEME_GIT_PROMPT_SUFFIX=''
ZSH_THEME_GIT_PROMPT_DIRTY=''
ZSH_THEME_GIT_PROMPT_CLEAN=''

# Catppuccin Mocha. The frame turns red for root.
typeset -gA _yupps_color=(
    frame   '#6c7086'
    red     '#f38ba8'
    maroon  '#eba0ac'
    green   '#a6e3a1'
    user    '#5f9cff'
    blue    '#89b4fa'
    mauve   '#cba6f7'
    peach   '#fab387'
    yellow  '#f9e2af'
    text    '#cdd6f4'
    comment '#585b70'
    surface '#45475a'
)
typeset -g _yupps_frame="%F{%(#.$_yupps_color[red].$_yupps_color[frame])}"

# Name of the active virtualenv, set at precmd. Activation scripts (venv, uv)
# export VIRTUAL_ENV_PROMPT, older ones as "(name) ". Otherwise a generic
# venv directory is named after the project that holds it.
_yupps_venv_name() {
    typeset -g _yupps_venv= _yupps_venv_seg=
    [[ -n $VIRTUAL_ENV ]] || return 0
    local name=${VIRTUAL_ENV_PROMPT//[() ]/}
    if [[ -z $name ]]; then
        name=${VIRTUAL_ENV:t}
        [[ $name == (.venv|venv|env|.env) ]] && name=${VIRTUAL_ENV:h:t}
    fi
    _yupps_venv=$name
    # Built here rather than in PROMPT: the } of a %F{...} inside
    # ${_yupps_venv:+...} would end the expansion early.
    _yupps_venv_seg="(🐍 %F{$_yupps_color[green]}${name//\%/%%}${_yupps_frame})"
}

# Right prompt: the git branch, if any.
_yupps_git() {
    local gi=$(git_prompt_info)
    [[ -n $gi ]] && print -nr -- "${_yupps_frame}[%F{$_yupps_color[peach]}${gi//\%/%%}${_yupps_frame}]%f"
}

# zsh-vi-mode indicator, shown at the top right of the two-line prompt as
# "LABEL emoji" in the mode's color. psvar holds 1: emoji, 2: color, 3: label
# padded to a fixed width, so redrawing the slot covers the previous label.
typeset -g _yupps_slot='%(1V.%B%F{%2v}%3v%b%f %1v.)'
typeset -gi _yupps_slot_w=0 _yupps_top_w=0 _yupps_bottom_w=0
typeset -g _yupps_top_left _yupps_bottom _yupps_none

_yupps_vi_mode() {
    local emoji color label
    (( ${+ZVM_MODE_INSERT} )) || { psvar[1,3]=(); return 0 }
    case ${ZVM_MODE:-$ZVM_MODE_INSERT} in
        $ZVM_MODE_INSERT)      emoji=📝 color=green label=INSERT ;;
        $ZVM_MODE_NORMAL)      emoji=🧭 color=blue  label=NORMAL ;;
        $ZVM_MODE_VISUAL)      emoji=👀 color=mauve label=VISUAL ;;
        $ZVM_MODE_VISUAL_LINE) emoji=📏 color=mauve label=V-LINE ;;
        $ZVM_MODE_REPLACE)     emoji=🔄 color=red   label=REPLACE ;;
        *)                     psvar[1,3]=(); return 0 ;;
    esac
    psvar[1,3]=($emoji $_yupps_color[$color] ${(l:7:)label})
    _yupps_paint_mode
}

# Redraw the mode slot after a mode change. zshrinkwrap prints the top line
# once as plain output, so zle never redraws it: save the cursor, climb from
# the cursor row to the top line, rewrite the slot, and restore the cursor.
_yupps_paint_mode() {
    [[ $PROMPT_ALTERNATIVE == twoline ]] && zle || return 0
    (( _yupps_slot_w && _yupps_top_w + _yupps_slot_w + 2 <= COLUMNS )) || return 0
    local -i up=1 w=_yupps_bottom_w
    local -a lines=("${(@ps:\n:)LBUFFER}")
    local line
    for line in "${(@)lines[1,-2]}"; do
        (( up += (w + ${(m)#line}) / COLUMNS + 1, w = 0 ))
    done
    (( up += (w + ${(m)#lines[-1]}) / COLUMNS ))
    (( up < LINES )) || return 0
    print -rn -- $'\e7\e['$up$'A\e['$(( COLUMNS - _yupps_slot_w ))'G'"${(%)_yupps_slot}"$'\e8'
}

# Widths the top-right padding and the redraw need, taken at precmd.
_yupps_measure() {
    setopt local_options extended_glob
    local top=${(%)${(e)_yupps_top_left}} bottom=${(%)_yupps_bottom}
    top=${top//$'\e'\[[0-9;]##m/}
    bottom=${bottom//$'\e'\[[0-9;]##m/}
    _yupps_top_w=${(m)#top}
    _yupps_bottom_w=${(m)#bottom}
    _yupps_slot_w=$(( $#psvar[1] ? 10 : 0 ))
}

# Spaces between the top line and the mode slot, so the slot ends one column
# before the edge like the right prompt. A math function so the prompt reads
# the current COLUMNS whenever the line is printed, including after a resize.
_yupps_pad_w() {
    (( _yupps_slot_w )) || return
    local -i pad=$(( COLUMNS - _yupps_top_w - _yupps_slot_w - 1 ))
    (( pad > 1 ? pad : 1 ))
}
functions -M _yupps_pad_w 0 0

typeset -ga zvm_after_select_vi_mode_commands
zvm_after_select_vi_mode_commands+=(_yupps_vi_mode)

# Cursor per vi mode. zsh-vi-mode draws replace mode with the operator
# pending cursor.
if (( ${+ZVM_CURSOR_BEAM} )); then
    ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
    ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
    ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
    ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
    ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_UNDERLINE
fi

# Visual mode selection.
ZVM_VI_HIGHLIGHT_BACKGROUND=$_yupps_color[surface]
ZVM_VI_HIGHLIGHT_FOREGROUND=$_yupps_color[text]

configure_prompt() {
    local frame=$_yupps_frame
    local user="%B%F{%(#.$_yupps_color[red].$_yupps_color[user])}%n%b"
    local host="%B%F{$_yupps_color[mauve]}%m%b"
    local symbol="%B%(#.%F{$_yupps_color[red]}#.%F{$_yupps_color[mauve]}❯)%b%f"
    local between=${PROMPT_SYMBOL:-🪐}
    [[ $EUID -eq 0 ]] && between=💀
    case "$PROMPT_ALTERNATIVE" in
        twoline)
            # The bottom line sets its own color: zshrinkwrap prints the top
            # line itself, and zle draws the rest from reset attributes.
            _yupps_top_left="${frame}╔═"'${debian_chroot:+($debian_chroot)═}${_yupps_venv_seg}${_yupps_venv:+═}'
            _yupps_top_left+="(${user}${between}${host}${frame})═[%B%f%(6~.%-1~/…/%4~.%5~)%b${frame}]"
            _yupps_bottom="${frame}╚═${symbol} "
            PROMPT=$_yupps_top_left'${(l:_yupps_pad_w():: :)_yupps_none}'$_yupps_slot$'\n'$_yupps_bottom
            RPROMPT='$(_yupps_git)'
            ;;
        oneline)
            PROMPT="${frame}"'${debian_chroot:+($debian_chroot)}${_yupps_venv_seg}'
            PROMPT+="${user}${frame}@${host}${frame}:%B%f%~%b ${symbol} "
            RPROMPT='$(_yupps_git)%(1V. .)'$_yupps_slot
            ;;
        backtrack)
            PROMPT='${debian_chroot:+($debian_chroot)}${_yupps_venv_seg}'
            PROMPT+="%B%F{$_yupps_color[red]}%n@%m%b%f:%B%F{$_yupps_color[blue]}%~%b%f %(1V.%1v .)%(#.#.$) "
            RPROMPT=
            ;;
    esac
}


if [ "$color_prompt" = yes ]; then
    # override default virtualenv indicator in prompt
    VIRTUAL_ENV_DISABLE_PROMPT=1

    configure_prompt

    # zsh-syntax-highlighting styles (the plugin keeps pre-set values), from
    # catppuccin/zsh-syntax-highlighting plus bracket levels.
    typeset -gA ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
    () {
        local -A c=("${(@kv)_yupps_color}")
        local style
        for style in alias suffix-alias global-alias function command builtin \
                reserved-word hashed-command; do
            ZSH_HIGHLIGHT_STYLES[$style]="fg=$c[green]"
        done
        ZSH_HIGHLIGHT_STYLES[precommand]="fg=$c[green],italic"
        ZSH_HIGHLIGHT_STYLES[autodirectory]="fg=$c[peach],italic"
        ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=$c[peach]"
        ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=$c[peach]"
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument]="fg=$c[mauve]"
        ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=$c[mauve]"
        for style in commandseparator back-quoted-argument-delimiter \
                back-double-quoted-argument back-dollar-quoted-argument; do
            ZSH_HIGHLIGHT_STYLES[$style]="fg=$c[red]"
        done
        for style in command-substitution-quoted command-substitution-delimiter-quoted \
                single-quoted-argument double-quoted-argument rc-quote; do
            ZSH_HIGHLIGHT_STYLES[$style]="fg=$c[yellow]"
        done
        for style in unknown-token single-quoted-argument-unclosed \
                double-quoted-argument-unclosed dollar-quoted-argument-unclosed \
                back-quoted-argument-unclosed; do
            ZSH_HIGHLIGHT_STYLES[$style]="fg=$c[maroon]"
        done
        for style in default arg0 cursor globbing redirection assign named-fd numeric-fd \
                dollar-quoted-argument dollar-double-quoted-argument \
                command-substitution-delimiter command-substitution-delimiter-unquoted \
                process-substitution-delimiter; do
            ZSH_HIGHLIGHT_STYLES[$style]="fg=$c[text]"
        done
        ZSH_HIGHLIGHT_STYLES[path]="fg=$c[text],underline"
        ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=$c[text],underline"
        ZSH_HIGHLIGHT_STYLES[path_pathseparator]="fg=$c[red],underline"
        ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]="fg=$c[red],underline"
        ZSH_HIGHLIGHT_STYLES[comment]="fg=$c[comment]"
        ZSH_HIGHLIGHT_STYLES[bracket-error]="fg=$c[red],bold"
        ZSH_HIGHLIGHT_STYLES[bracket-level-1]="fg=$c[blue],bold"
        ZSH_HIGHLIGHT_STYLES[bracket-level-2]="fg=$c[green],bold"
        ZSH_HIGHLIGHT_STYLES[bracket-level-3]="fg=$c[mauve],bold"
        ZSH_HIGHLIGHT_STYLES[bracket-level-4]="fg=$c[yellow],bold"
        ZSH_HIGHLIGHT_STYLES[bracket-level-5]='fg=#94e2d5,bold'
        ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
    }
else
    PROMPT='${debian_chroot:+($debian_chroot)}%n@%m:%~%(#.#.$) '
fi
unset color_prompt force_color_prompt

toggle_oneline_prompt(){
    if [ "$PROMPT_ALTERNATIVE" = oneline ]; then
        PROMPT_ALTERNATIVE=twoline
    else
        PROMPT_ALTERNATIVE=oneline
    fi
    configure_prompt
    zle reset-prompt
}
zle -N toggle_oneline_prompt
bindkey "^X^P" toggle_oneline_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty)
    TERM_TITLE=$'\e]0;${debian_chroot:+($debian_chroot)}${_yupps_venv:+(${_yupps_venv})}%n@%m: %~\a'
    ;;
*)
    ;;
esac

_yupps_precmd() {
    _yupps_venv_name
    _yupps_vi_mode
    [[ $PROMPT_ALTERNATIVE == twoline ]] && _yupps_measure

    # Print the previously configured title
    [[ -n "$TERM_TITLE" ]] && print -Pnr -- "$TERM_TITLE"

    # Print a new line before the prompt, but only if it is not the first line
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
            _NEW_LINE_BEFORE_PROMPT=1
        else
            print ""
        fi
    fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _yupps_precmd
#set +x
