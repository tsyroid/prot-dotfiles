#
# ~/.bashrc
#

# Description
# ===========
#
# BASH configuration file.  Any modules such as the `dircolors` config
# are stored in ~/.local/share/my_bash/.  This setup is part of my
# dotfiles.  See https://gitlab.com/protesilaos/dotfiles.
#
# Note that ALL MY SCRIPTS are designed to work with `#!/bin/bash`.
# They are not tested for portability.
#
# Last full review on 2019-06-28

# Shorter version of a common command that it used herein.
_checkexec() {
	command -v "$1" > /dev/null
}

# General settings
# ================

# Include my scripts in the PATH.
if [ -d "$HOME"/bin ]; then
    PATH=$PATH:"$HOME"/bin
fi

if [ -d "$HOME"/.local/bin ]; then
    PATH=$PATH:"$HOME"/.local/bin
fi

# May be needed for Jekyll…
if [ -d "$HOME"/.local/share/gems ]; then
    GEM_HOME="$HOME"/.local/share/gems
    PATH=$PATH:"$HOME"/.local/share/gems/bin
fi


# Default pager.  Note that the option I pass to it will quit once you
# try to scroll past the end of the file.
export PAGER="less --quit-at-eof"
export MANPAGER="$PAGER"

# Default editor.
if pgrep -x emacs > /dev/null; then
    export VISUAL="emacsclient -c"
	export EDITOR="emacsclient -t"
elif _checkexec gvim; then
	export VISUAL="gvim"
	export EDITOR=vim
else
	export VISUAL=vim
	export EDITOR=$VISUAL
fi

# Default browser.  This leverages the MIME list.
export BROWSER=/usr/bin/xdg-open

# Simple prompt
if [ -n "$SSH_CONNECTION" ]; then
	export PS1="\u@\h: \w \$ "
else
	export PS1="\w \$ "
fi
export PS2="> "

# The following is taken from the .bashrc shipped with Debian 9.  Enable
# programmable completion features (you don't need to enable this, if
# it's already enabled in /etc/bash.bashrc and /etc/profile sources
# /etc/bash.bashrc).
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
	fi
fi

# Enable tab completion when starting a command with 'sudo'
[ "$PS1" ] && complete -cf sudo

# If not running interactively, don't do anything.  This too is taken
# from Debian 9's bashrc.
case $- in
	*i*) ;;
	  *) return;;
esac

# Don't put duplicate lines or lines starting with space in the history.
# See `man bash` for more options.
HISTCONTROL=ignoreboth

# Append to the history file, don't overwrite it.
shopt -s histappend

# For setting history length see HISTSIZE and HISTFILESIZE in `man bash`.
HISTSIZE=1000
HISTFILESIZE=2000

# Check the window size after each command and, if necessary, update the
# values of LINES and COLUMNS.
shopt -s checkwinsize

# Make `less` more friendly for non-text input files.
_checkexec lesspipe && eval "$(SHELL=/bin/sh lesspipe)"

# Aliases
# =======
# A note on how I define aliases.  I try to abstract the command into
# its initials or something that resembles the original.  This helps me
# remember the original command when necessary.  There are some
# exceptions for commands I seldom execute.

# APT (package management on Debian)
# ----------------------------------

# If you are coming to Debian from Arch-based distros, check
# compatibility with `pacman`:
# https://wiki.archlinux.org/index.php/Pacman/Rosetta
if _checkexec apt; then
	# up{dating,grading}.  The -V shows version changes.
	alias au="sudo apt-get update"
	alias aug="sudo apt-get upgrade -V"
	alias auu="sudo apt-get update && sudo apt-get upgrade -V"
	alias afu="sudo apt-get dist-upgrade -V"
	alias auufu="sudo apt-get update && sudo apt-get upgrade -V && sudo apt-get dist-upgrade -V"

	# act on package targets
	alias ai="sudo apt-get install"
	alias air="sudo apt-get install --reinstall"
	alias ar="sudo apt-get remove -V"

	# list local packages
	alias ard="apt rdepends" # followed by package name to print reverse dependencies
	alias ali="apt list --installed"
	alias alu="apt list --upgradable"
	alias aulu="sudo apt update && apt list --upgradable"

	# act on the repos
	alias as="apt search"
	alias ash="apt show"
	alias adl="apt download" # gets source .deb in current directory

	# package handling
	alias aac="sudo apt-get autoclean"
	alias aar="sudo apt-get autoremove -V"
	alias ama="sudo apt-mark auto"
	alias amm="sudo apt-mark manual"
fi

# No point in checking for dpkg on a Debian system.  Still, it can help
# people who copy-paste stuff.
if _checkexec dpkg; then
	alias dgl='dpkg --listfiles' # target a package name, e.g. dgl bspwm
	alias dgg='dpkg --get-selections' # would normally be pipped to grep
	# The following removes/purges unused configs without asking for
	# confirmation.  Same end product as 'alias apc' (see below where
	# aptitude is defined).
	alias dgp='sudo dpkg --purge $(dpkg --get-selections | grep deinstall | cut -f 1)'
fi

if _checkexec aptitude; then
	# The following two aliases perform the same action of removing
	# unused system files.  Unlike 'alias dgp', confirmation is needed.
	#alias apc="sudo aptitude purge ?config-files"
	alias apc="sudo aptitude purge ~c"
fi

# NOTE 2019-11-10: Work-in-progress
# XBPS (package management on Void Linux)
# ---------------------------------------
if _checkexec xbps-install; then
    alias xbi="sudo xbps-install -S"        # Update lists without a package arg
    alias xbiu="sudo xbps-install -Su"      # Upgrade system
    alias xbif="sudo xbps-install -f"       # Re-install 'forcefully' (no checks)
    alias xbiD="sudo xbps-install -D"       # Just download
    alias xbiSuvn="sudo xbps-install -Suvn" # List upgradeable
fi

if _checkexec xbps-remove; then
    alias xbr="sudo xbps-remove -R"         # Remove deps as well
    alias xbro="sudo xbps-remove -Oo"       # PKG, orphans, obsolete files
fi

if _checkexec xbps-query; then
    alias xbq="xbps-query"                  # Search for local package
    alias xbqR="xbps-query -Rs"             # Search for remote package
    alias xbqH="xbps-query -H"              # Query "hold" rules
    alias xbqX="xbps-query -X"              # Reverse dependencies
    alias xbql="xbps-query -l"              # List installed
    alias xbqL="xbps-query -L"              # List info sources
    alias xbqx="xbps-query -x"              # Dependencies
    alias xbqf="xbps-query -f"              # List local package files
    alias xbqF="xbps-query -Rf"             # Remote package files
    alias xbqO="xbps-query -O"              # List orphans
fi

if _checkexec xbps-pkgdb; then
    alias xbma="sudo xbps-pkgdb -m auto"    # Mark as auto install
    alias xbmm="sudo xbps-pkgdb -m manual"  # Mark as manual install
    alias xbmh="sudo xbps-pkgdb -m hold"
    alias xbmuh="sudo xbps-pkgdb -m unhold"
fi

if _checkexec xbps-remove && _checkexec xbps-query; then
    xbrq() {
        sudo xbps-remove -R $(xbps-query -s "$1" | cut -d ' ' -f 2 | tr '\n' ' ')
    }
fi


# Common tasks and utilities
# --------------------------

# Check these because some of them modify the behaviour of standard
# commands, such as `cp`, `mv`, `rm`, so that they provide verbose
# output and open a prompt when an existing file is affected.
#
# PRO TIP to ignore aliases, start them with a backslash \.  The
# original command will be used.  This is useful when the original
# command and the alias have the same name.  Example is my `cp` which is
# aliased to `cp -iv`:
#
#	cp == cp -iv
#	\cp == cp

# _Entering_ Vim is easy.
if _checkexec vim; then
    alias v='vim'
    alias vi='vim'
fi

# cd into the previous working directory by omitting `cd`.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safer default for cp, mv, rm.  These will print a verbose output of
# the operations.  If an existing file is affected, they will ask for
# confirmation.  This can make things a bit more cumbersome, but is a
# generally safer option.
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'

# Some common tasks for the `rsync` utiity.
if _checkexec rsync; then
	alias rsync='rsync --progress'
	alias rsyncavz='rsync -avz --progress'
	alias rsyncavzr='rsync -avzr --progress'
	alias rsyncavzrd='rsync -avzr --delete --progress'
fi

# Enable automatic color support for common commands that list output
# and also add handy aliases.  Note the link to the `dircolors`.  This
# is provided by my dotfiles.
if _checkexec dircolors; then
	dircolors_data="$HOME/.local/share/my_bash/dircolors"
	test -r $dircolors_data && eval "$(dircolors -b ${dircolors_data})" || eval "$(dircolors -b)"
fi

alias diff='diff --color=auto'

alias dir='dir --color=auto'
alias vdir='vdir --color=auto'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Make ls a bit easier to read.  Note that the -A is the same as -a but
# does not include implied paths (the current dir denoted by a dot and
# the previous dir denoted by two dots).  I would also like to use the
# -p option, which prepends a forward slash to directories, but it does
# not seem to work with symlinked directories. For more, see `man ls`.
alias ls='ls -pv --color=auto --group-directories-first'
alias lsa='ls -pvA --color=auto --group-directories-first'
alias lsl='ls -lhpv --color=auto --group-directories-first'
alias lsla='ls -lhpvA --color=auto --group-directories-first'

# Extra tasks and infrequently used tools
# ---------------------------------------

# These options are very opinionated, disabling images, javascript,
# etc.  See `man surf`.
if _checkexec surf; then
	alias surf="surf -giKMnps"
fi

# Quick shortcuts for `mpv`.  When I want to play a podcast that only
# shows a static image, I run the command with the --no-video option.
# When I only need to view the file I use --no-audio.  The one with
# --ytdl-raw-options is for those occasions where a video is 4k or
# something that slows things down considerably.
if _checkexec mpv; then
	alias mpvna='mpv --no-audio'
	alias mpvnv='mpv --no-video'
	alias mpvhd="mpv --ytdl-raw-options='format=[[bestvideo=height<=720]]'"
fi

# Quick shortcuts for `youtube-dl`.  Output is placed in the present
# working directory.
if _checkexec youtube-dl; then
	alias ytaud='youtube-dl --add-metadata -ci --extract-audio --audio-format mp3 -o "%(title)s.%(ext)s"'
	alias ytvid='youtube-dl --add-metadata --no-playlist --no-part --write-description --newline --prefer-free-formats -o "%(title)s.%(ext)s" '
fi

# When I need to copy the contents of a file to the clipboard
if _checkexec xclip; then
	alias xclipc='xclip -selection clipboard' # followed by path to file
fi

# I only ever use Stow to make symlinks with my home dir as the base
if _checkexec stow; then
    alias stow="stow -t $HOME"
fi

# Flatpak commands
# ----------------

if _checkexec flatpak; then
	alias fli="flatpak install" # must be followed by a source, e.g. fli flathub
	alias fliu="flatpak uninstall"
	alias flls="flatpak list --app --columns='desc,app,orig'"
	alias flu="flatpak update"
fi

# Git commands
# ------------

if _checkexec git; then
	export GIT_EDITOR="$EDITOR"

	# add, commit
	alias gadd='git add -v'
	alias gaddp='git add --patch'
	alias gaddi='git add --interactive'
	alias gall='git add -Av'
	alias gcom='git commit' # opens in the predefined editor.
	alias gcomm='git commit -m' # pass a message directly: gcomm 'My commit'
	alias gca='git commit --amend'
	alias grh='git reset HEAD'

	# stats and diffs
	alias gsh='git show'
	alias gsho='git show --oneline'
	alias glo='git log --oneline'
	alias glog='git log'
	alias gsta='git status'
	alias gstat='git status'
	alias gdif='git diff'
	alias gdiff='git diff'
	alias gdifs='git diff --stat --summary'
	alias gdiffss='git diff --stat --summary'

	# branching
	alias gch='git checkout'
	alias gchb='git checkout -b'
	alias gbd='git branch -d'
	alias gbl='git branch --list'
	alias gpd='git push origin --delete'
	alias gmerg='git merge --edit --stat'
	alias gmerge='git merge --edit --stat'

	# tagging
	alias gtag='git tag --sign' # followed by the tag's name
	alias gtagl='git tag --list'

	# syncing
	alias gpull='git pull'
	alias gfetch='git fetch'
	alias gpm='git push -u origin master'
	alias gph='git push -u origin HEAD'
fi

# Functions
# =========

# Colourise man pages
man() {
	env \
	LESS_TERMCAP_mb=$(tput bold; tput setaf 6) \
	LESS_TERMCAP_md=$(tput bold; tput setaf 6) \
	LESS_TERMCAP_me=$(tput sgr0) \
	LESS_TERMCAP_se=$(tput rmso; tput sgr0) \
	LESS_TERMCAP_ue=$(tput rmul; tput sgr0) \
	LESS_TERMCAP_us=$(tput smul; tput bold; tput setaf 4) \
	LESS_TERMCAP_mr=$(tput rev) \
	LESS_TERMCAP_mh=$(tput dim) \
	LESS_TERMCAP_ZN=$(tput ssubm) \
	LESS_TERMCAP_ZV=$(tput rsubm) \
	LESS_TERMCAP_ZO=$(tput ssupm) \
	LESS_TERMCAP_ZW=$(tput rsupm) \
		man "$@"
}

# Enter directory and list contents
cd() {
	if [ -n "$1" ]; then
		builtin cd "$@" && ls -pvA --color=auto --group-directories-first
	else
		builtin cd ~ && ls -pvA --color=auto --group-directories-first
	fi
}

# Back up a file. Usage "backupthis <filename>"
backupthis() {
	cp -riv $1 ${1}-$(date +%Y%m%d%H%M).backup;
}
