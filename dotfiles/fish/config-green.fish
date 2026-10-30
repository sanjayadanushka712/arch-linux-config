if status is-interactive
    # Starship custom prompt
    command -v starship &> /dev/null && starship init fish | source

    # ---- Hacker Minimal theme (soft green on near-black) ----
    set -g fish_color_normal c3c9c0
    set -g fish_color_command 9cd89c
    set -g fish_color_param c3c9c0
    set -g fish_color_keyword 7ec87e
    set -g fish_color_quote d8b36a
    set -g fish_color_redirection 6fbfb0
    set -g fish_color_end 7ec87e
    set -g fish_color_error e06c75
    set -g fish_color_comment 4a544a
    set -g fish_color_selection --background=1f2a22
    set -g fish_color_search_match --background=1f2a22
    set -g fish_color_operator 6fbfb0
    set -g fish_color_escape 86bfd9
    set -g fish_color_cwd 7ec87e
    set -g fish_color_cwd_root e06c75
    set -g fish_color_autosuggestion 4a544a
    set -g fish_color_cancel e06c75
    set -g fish_color_user 7ec87e
    set -g fish_color_host 9cd89c
    set -g fish_color_host_remote d8b36a
    set -g fish_color_status e06c75
    set -g fish_color_valid_path --underline
    set -g fish_color_match --background=1f2a22
    set -g fish_pager_color_progress 4a544a
    set -g fish_pager_color_prefix 7ec87e
    set -g fish_pager_color_completion c3c9c0
    set -g fish_pager_color_description 4a544a
    set -g fish_pager_color_selected_background --background=1f2a22

    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # FZF: Ctrl+T files, Alt+C cd (Ctrl+R is Atuin)
    set -gx FZF_DEFAULT_OPTS "--height 40% --border --color=fg:#c3c9c0,bg:#0b0f0c,hl:#7ec87e,fg+:#e6eae5,bg+:#1f2a22,hl+:#9cd89c,info:#4a544a,prompt:#7ec87e,pointer:#7ec87e,marker:#d8b36a,spinner:#6fbfb0,header:#4a544a"
    command -v fzf &> /dev/null && fzf --fish | source

    # Atuin: searchable shell history (Ctrl+R), keep normal Up-arrow
    command -v atuin &> /dev/null && atuin init fish --disable-up-arrow | source

    # Carapace: tab-completions for many CLIs
    command -v carapace &> /dev/null && carapace _carapace fish | source

    # mise: per-project version manager (node, python, rust, ...)
    command -v mise &> /dev/null && mise activate fish | source

    # Clear screen + scrollback on Ctrl+L, shortcut `c`
    abbr c clear
    bind \cl 'clear; printf "\e[3J"; commandline -f repaint'

    # Better ls
    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    # Abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    # Custom colours
    # cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    # For jumping between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end

    # Custom fish config
    set -q XDG_CONFIG_HOME && set -l cConf $XDG_CONFIG_HOME/caelestia || set -l cConf $HOME/.config/caelestia
    source $cConf/user-config.fish 2> /dev/null
end

# Local bin on PATH
if not contains "$HOME/.local/bin" $PATH
    set -gx PATH "$HOME/.local/bin" $PATH
end
