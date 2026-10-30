if status is-interactive
    # Starship custom prompt
    command -v starship &> /dev/null && starship init fish | source

    # ---- Hacker Amber theme (warm amber on near-black) ----
    set -g fish_color_normal d4c9b8
    set -g fish_color_command e6bd7a
    set -g fish_color_param d4c9b8
    set -g fish_color_keyword d8a657
    set -g fish_color_quote 9fb56a
    set -g fish_color_redirection 7fb5a8
    set -g fish_color_end d8a657
    set -g fish_color_error d1605f
    set -g fish_color_comment 5a5146
    set -g fish_color_selection --background=2a231a
    set -g fish_color_search_match --background=2a231a
    set -g fish_color_operator 7fb5a8
    set -g fish_color_escape 9db8d4
    set -g fish_color_cwd d8a657
    set -g fish_color_cwd_root d1605f
    set -g fish_color_autosuggestion 5a5146
    set -g fish_color_cancel d1605f
    set -g fish_color_user d8a657
    set -g fish_color_host e6bd7a
    set -g fish_color_host_remote 9fb56a
    set -g fish_color_status d1605f
    set -g fish_color_valid_path --underline
    set -g fish_color_match --background=2a231a
    set -g fish_pager_color_progress 5a5146
    set -g fish_pager_color_prefix d8a657
    set -g fish_pager_color_completion d4c9b8
    set -g fish_pager_color_description 5a5146
    set -g fish_pager_color_selected_background --background=2a231a

    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # FZF: Ctrl+T files, Alt+C cd (Ctrl+R is Atuin)
    set -gx FZF_DEFAULT_OPTS "--height 40% --border --color=fg:#d4c9b8,bg:#0f0d0a,hl:#d8a657,fg+:#efe6d8,bg+:#2a231a,hl+:#e6bd7a,info:#5a5146,prompt:#d8a657,pointer:#d8a657,marker:#9fb56a,spinner:#7fb5a8,header:#5a5146"
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
