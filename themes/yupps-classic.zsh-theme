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

configure_prompt() {
    prompt_symbol=🍤🐟
    [[ $EUID -eq 0 ]] && prompt_symbol=💀
    case "$PROMPT_ALTERNATIVE" in
        twoline)
            PROMPT=$'%F{%(#.blue.#dfafff)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'$prompt_symbol$'%m%b%F{%(#.blue.#dfafff)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.#dfafff)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
            # PROMPT=$'%F{%(#.blue.dfafff)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'$prompt_symbol$'%m%b%F{%(#.blue.dfafff)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
            # Right-side prompt with exit codes and background processes
            # RPROMPT=[%B%F{reset}%(%t)%b%F{%(#.blue.green)}]
            # ${$(git_prompt_info):+$($'%F{%(#.blue.#dfafff)}[%B%F{reset}$(git_prompt_info)%b%F{%(#.blue.#dfafff)}]')}
            # RPROMPT='${$(git_prompt_info):+%F{cyan}$(git_prompt_info)%f}'
            RPROMPT='$(gi=$(git_prompt_info); [[ -n $gi ]] && print -nr -- "%F{%(#.blue.#dfafff)}[%B%F{reset}${gi}%b%F{%(#.blue.#dfafff)}]")'

            # RPROMPT=$'{ gi=$(git_prompt_info); [[ -n $gi ]] && print -nr -- "%F{%(#.blue.#dfafff)}[%B%F{reset}${gi}%b%F{%(#.blue.#dfafff)}]" }'
            # RPROMPT=$'%F{%(#.blue.#dfafff)}[%B%F{reset}$(git_prompt_info)%b%F{%(#.blue.#dfafff)}]'
            # RPROMPT=$'${$(git_prompt_info):+%F{cyan}$(git_prompt_info)%f}%F{240}%*%f'

            # RPROMPT='%F{cyan}$(git_prompt_info)%f'

            # RPROMPT='$(git_prompt_info)'
            # RPROMPT='${vcs_info_msg_0_:+%F{cyan}${vcs_info_msg_0_}%f}'

            #RPROMPT=$'%(?.. %? %F{red}%B⨯%b%F{reset})%(1j. %j %F{yellow}%B⚙%b%F{reset}.)'
            ;;
        oneline)
            PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{%(#.red.blue)}%n@%m%b%F{reset}:%B%F{%(#.blue.green)}%~%b%F{reset}%(#.#.$) '
            RPROMPT=
            ;;
        backtrack)
            PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{red}%n@%m%b%F{reset}:%B%F{blue}%~%b%F{reset}%(#.#.$) '
            RPROMPT=
            ;;
    esac
    unset prompt_symbol
}


if [ "$color_prompt" = yes ]; then
    # override default virtualenv indicator in prompt
    VIRTUAL_ENV_DISABLE_PROMPT=1

    configure_prompt
    
    # enable syntax-highlighting
    # if [[ -n "$(antidote path zsh-users/zsh-syntax-highlighting)" ]]; then
    #     source "$(antidote path zsh-users/zsh-syntax-highlighting)/zsh-syntax-highlighting.zsh"
        # source "$(antidote path zsh-users/zsh-syntax-highlighting)"

    if typeset -f antidote &>/dev/null; then
        highlight_path="$(antidote path zsh-users/zsh-syntax-highlighting)"
        if [[ -n "$highlight_path" && -f "$highlight_path/zsh-syntax-highlighting.zsh" ]]; then
        # source "$highlight_path/zsh-syntax-highlighting.zsh"

    #if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
        # ksharrays breaks the plugin. This is fixed now but let's disable it in the
	    # meantime.
	    # https://github.com/zsh-users/zsh-syntax-highlighting/pull/689
	    #unsetopt ksharrays
        #  zmodload zsh/parameter
# print -l ${(k)ZSH_HIGHLIGHT_STYLES}
        typeset -gA ZSH_HIGHLIGHT_STYLES
        #. /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
        ZSH_HIGHLIGHT_STYLES[default]=none
        ZSH_HIGHLIGHT_STYLES[unknown-token]=underline
        ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
        ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
        ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green,bold
        ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
        ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
        ZSH_HIGHLIGHT_STYLES[path]=bold
        ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
        ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
        ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[command-substitution]=none
        ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[process-substitution]=none
        ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
        ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
        ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
        ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
        ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
        ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
        ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[assign]=none
        ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
        ZSH_HIGHLIGHT_STYLES[named-fd]=none
        ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
        ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
        ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
        ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
        ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
        fi
    fi
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
bindkey "^P" toggle_oneline_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty)
    TERM_TITLE=$'\e]0;${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%n@%m: %~\a'
    ;;
*)
    ;;
esac

precmd() {
    # Print the previously configured title
    [[ -n "$TERM_TITLE" ]] && print -Pnr -- "$TERM_TITLE"
    # print -Pnr -- "$TERM_TITLE"

    # Print a new line before the prompt, but only if it is not the first line
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
            _NEW_LINE_BEFORE_PROMPT=1
        else
            print ""
        fi
    fi
}
#set +x
