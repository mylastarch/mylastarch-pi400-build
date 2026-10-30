# MyLastArch shell defaults, curated for the Raspberry Pi 400 image.
export EDITOR='nano'
export VISUAL='nano'
export HISTCONTROL='ignoreboth:erasedups'
export PAGER='less'

PS1='[\u@\h \W]\$ '

# Do not run interactive settings from scripts or scp sessions.
[[ $- != *i* ]] && return

[[ -d "$HOME/.bin" ]] && PATH="$HOME/.bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion
fi
bind 'set completion-ignore-case on'

shopt -s autocd cdspell cmdhist dotglob histappend expand_aliases

# Listing and navigation.
alias ls='ls --color=auto'
alias la='ls -A'
alias ll='ls -alFh'
alias l='ls'
alias l.="ls -A | grep '^\.'"
alias cd..='cd ..'
alias pdw='pwd'
alias df='df -h'
alias free='free -mt'

# Package management. The Pi image uses yay, not paru.
alias sps='sudo pacman -S'
alias spr='sudo pacman -R'
alias sprs='sudo pacman -Rs'
alias sprdd='sudo pacman -Rdd'
alias spqo='pacman -Qo'
alias spsii='pacman -Sii'
alias update='sudo pacman -Syu'
alias upd='sudo pacman -Syu'
alias u='sudo pacman -Syu'
alias udpate='sudo pacman -Syu'
alias upate='sudo pacman -Syu'
alias updte='sudo pacman -Syu'
alias updqte='sudo pacman -Syu'
alias pksyua='yay -Syu --noconfirm'
alias upall='yay -Syu --noconfirm'
alias upa='yay -Syu --noconfirm'
alias upal='yay -Syu --noconfirm'
alias upqll='yay -Syu --noconfirm'
alias yayskip='yay -S --mflags --skipinteg'
alias list='pacman -Qqe'
alias listt='pacman -Qqet'
alias listaur='pacman -Qqem'
alias cleanup='orphans=$(pacman -Qtdq); [[ -z "$orphans" ]] || sudo pacman -Rns $orphans'

depends() {
    pacman -Sii "$1" | sed -n 's/^Required By[[:space:]]*:[[:space:]]*//p'
}

# Output, diagnostics, and common configuration files.
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
alias rg='rg --sort path'
alias psa='ps auxf'
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias jctl='journalctl -p 3 -xb'
alias sysfailed='systemctl list-units --failed'
alias audio="pactl info | grep 'Server Name'"
alias microcode='grep . /sys/devices/system/cpu/vulnerabilities/*'
alias kernel='ls /usr/lib/modules'
alias kernels='ls /usr/lib/modules'
alias userlist="cut -d: -f1 /etc/passwd | sort"
alias ff='fastfetch'
alias npacman='sudo $EDITOR /etc/pacman.conf'
alias nmakepkg='sudo $EDITOR /etc/makepkg.conf'
alias nmirrorlist='sudo $EDITOR /etc/pacman.d/mirrorlist'
alias nfstab='sudo $EDITOR /etc/fstab'
alias nnsswitch='sudo $EDITOR /etc/nsswitch.conf'
alias nsamba='sudo $EDITOR /etc/samba/smb.conf'
alias nhosts='sudo $EDITOR /etc/hosts'
alias nhostname='sudo $EDITOR /etc/hostname'
alias nresolv='sudo $EDITOR /etc/resolv.conf'
alias nvconsole='sudo $EDITOR /etc/vconsole.conf'
alias nenvironment='sudo $EDITOR /etc/environment'
alias nb='$EDITOR ~/.bashrc'
alias ssn='sudo shutdown now'
alias sr='sudo reboot'
alias give-me-qwerty-us='sudo localectl set-x11-keymap us'
alias setlocale='sudo localectl set-locale LANG=en_US.UTF-8'

# Extract common archive types with one command: ex archive.ext
ex() {
    [[ -f $1 ]] || { printf "'%s' is not a valid file\n" "$1"; return 1; }
    case $1 in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.tar|*.tar.xz|*.tar.zst) tar xf "$1" ;;
        *.zip)            unzip "$1" ;;
        *.Z)              uncompress "$1" ;;
        *.7z)             7z x "$1" ;;
        *.deb)            ar x "$1" ;;
        *) printf "'%s' cannot be extracted via ex()\n" "$1"; return 2 ;;
    esac
}

[[ -f "$HOME/.bashrc-personal" ]] && . "$HOME/.bashrc-personal"

# Preserve the original MyLastArch interactive welcome without breaking a
# shell if fastfetch is ever removed.
command -v fastfetch >/dev/null && fastfetch
