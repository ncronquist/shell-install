#!/usr/bin/env bash

###############################################################################
# Begin Generic Functions
###############################################################################

add_apt_repo() {
    local repo="$1"

    if apt_repo_exists "$repo"; then
	echo "Apt repository $repo already exists"
    else
	echo "$repo missing; adding apt repository ppa:$repo now!"
        sudo add-apt-repository -y "ppa:$repo"
    fi
}

app_exists() {
    local app="$1"

    if (! type "$app" >/dev/null 2>&1); then
        # App doesn't exist
        return 1
    else
	# App exists
        return 0
    fi
}

append_to_shell_rc_files() {
  local text="$1"
  local zshrc=""
  local bashrc="$HOME/.bashrc"
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi

  if ! grep -Fqs "$text" "$bashrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$bashrc"
    else
      printf "\n%s\n" "$text" >> "$bashrc"
    fi
  fi
}

apt_install() {
    # Using apt_install function so that we can change things later if
    # necessary, but this is basically just going to run a normal install
    local package="$1"
    local package_alias="$2"

    echo "installing or updating $package"
    sudo apt-get install -y -qq "$package"
    # if [ "$package_alias" == "" ]; then
	# package_alias="$package"
    # fi
    #
    # if app_exists "$package_alias"; then
	# echo "$package already installed"
    # else
	# echo "$package not installed; installing now!"
	# sudo apt-get install -y "$package"
    # fi
}

apt_repo_exists() {
    local repo="$1"

    if [ $(find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep -c "$repo") -eq 0 ]; then
        # Doesn't exist
        return 1;
    else
        # Exists
        return 0;
    fi
}

download_file() {
    local url="$1" # Download url
    local filename="$2" # Filename (including path) where you would like the file placed

    echo "Downloading $url to $filename"

    # -s - silent or quiet mode
    # -S - when used with -s this will show the error if it fails
    # -L - allows for 301 redirects
    curl -sSL $url -o $filename
}

install_by_directory() {
    local dir="$1"
    local app="$2"

    if [ ! -d "$dir" ]; then
        echo "$app not installed; installing now!"
        install_$app
    else
        echo "$app already installed"
    fi
}

install_if_missing() {
    local app="$1"

    if app_exists "$app"; then
    	echo "$app already installed"
    else
	    echo "$app not installed; installing now!"
	    install_"$app"
    fi
}

###############################################################################
# End Generic Functions
###############################################################################
#
###############################################################################
# Begin Install/Action Functions
###############################################################################

configure_git() {
    local user_name="$1"
    local user_email="$2"

    if [ $(git config -l | grep user.email | wc -l) -eq 1 ]; then
        echo "git already configured"
    else
        git config --global user.name "$user_name"
        git config --global user.email "$user_email"
    fi
}

create_a_docker_group() {
    # https://docs.docker.com/engine/installation/linux/ubuntulinux/#/create-a-docker-group
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
}

do_spotify_preinstall() {
    if app_exists spotify; then
        echo "spotify already installed, no need to add repo"
    else
        echo "adding spotify repository key and repository"
        # Instructions found https://www.spotify.com/us/download/linux/
        # 1. Add the Spotify repository signing key to be able to verify downloaded packages
        sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886

        # 2. Add the Spotify repository
        echo deb http://repository.spotify.com stable non-free | sudo tee /etc/apt/sources.list.d/spotify.list
    fi
}

generate_ssh() {
    local user_email="$1"

    if [ ! -d "$HOME/.ssh/" ]; then
        echo "Generating ssh key"
        ssh-keygen -t rsa -b 4096 -C $USER_EMAIL

        # Add ssh key to ssh -agent
        eval "$(ssh-agent -s)"

        # Add key to ssh agent
        ssh-add ~/.ssh/id_rsa

        cat $HOME/.ssh/id_rsa.pub
        echo "Copy the above SSH key and paste it into any onlie Git repo accounts you use."
        echo "GitHub: https://github.com/settings/ssh"
        echo "GitLab: https://gitlab.com/profile/keys"
        echo "Bitbucket: https://bitbucket.org/account/user/YOUR_BITBUCKET_USERNAME/ssh-keys/"
        printf "Press any key to continue when you have finishd: "

        echo "Testing SSH key"
        ssh -T git@github.com
        ssh -T git@gitlab.com
    else
        echo "ssh already set up"
    fi
}

install_atom() {
    local url="https://atom.io/download/deb"
    local filename="$HOME/Downloads/atom-amd64.deb"

    download_file $url $filename
    sudo dpkg -i $filename
}

install_bundler() {
    gem install bundler
}

get_docker_repo() {
    # https://github.com/ncronquist/laptop/blob/thoughtbot-to-ncronquist/todo/ubuntu-shared-functions
    if [ "$UBUNTU_VERSION_NUMBER" == "16.04" ]; then
        echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main"
    elif [ "$UBUNTU_VERSION_NUMBER" == "14.04" ]; then
        echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main"
    else
        echo "Ooof, Ubuntu 16.04 and 14.04 are the only supported OS versions right now... Feel free to make a PR to add support for other versions"
        exit 1
    fi
}

install_docker() {
    if [ $(systemctl list-unit-files --type=service | grep docker.service | wc -l) -eq 0 ]; then
        echo "docker not installed yet; installing now!"
        # Instructions found here: https://docs.docker.com/engine/installation/linux/ubuntulinux/
        # Add the new GPG key
        sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

        # Find the repo for your version of ubuntu
        local repo=$(get_docker_repo)

        # Add the reop information to your sources list
        echo "$repo" | sudo tee /etc/apt/sources.list.d/docker.list

        # Update the APT package index
        sudo apt-get update

        # Install the docker-engine
        apt_install docker-engine

        # Start the docker service
        sudo service docker start

        # Configure Docker to start on boot
        # Ubuntu 15.04 and up uses systemd and requires the following command
        # to configure the docker daemon to start on boot; 14.10 and below
        # use upstart and the normal install configures upstart to start the
        # docker daemon on boot
        if [ "$UBUNTU_VERSION_NUMBER" == "16.04" ]; then
            sudo systemctl enable docker
        fi
    else
        echo "docker already installed"
    fi
}

install_docker_client() {
    local docker_version="1.12.3"

    . $HOME/.dvm/dvm.sh

    if [ $(dvm ls | wc -l) -eq 0 ]; then
        echo "no docker clients installed; installing docker $docker_version"
        dvm install "$docker_version"
        dvm use "$docker_version"
    else
        echo "docker client already install"
    fi
}

install_dvm() {
    local url="https://download.getcarina.com/dvm/latest/install.sh"
    local filename="$HOME/Downloads/dvm_install.sh"

    export DVM_DIR="$HOME/.dvm"

    download_file $url $filename

    # Run install script
    /bin/sh "$filename"

    # Source dvm
    . $HOME/.dvm/dvm.sh

    # Add to rc files
    append_to_shell_rc_files 'export DVM_DIR="$HOME/.dvm"'
    append_to_shell_rc_files '[ -s "$DVM_DIR/dvm.sh" ] && . $DVM_DIR/dvm.sh  # This loads dvm'
    append_to_shell_rc_files '[[ -r $DVM_DIR/bash_completion ]] && . $DVM_DIR/bash_completion'
}

install_elixir() {
    local version_name="1.3.2"

    kiex install "$version_name"

    kiex default "$version_name"
    kiex use "$version_name"

    . $HOME/.kiex/elixirs/elixir-"$version_name".env
}

install_erl() {
    # Erlang install
    # GIT_TAG="OTP-18.3.2" # https://github.com/erlang/otp/tags
    # VERSION_NAME="18.3.2" # The name you want to give this build (I generally just go with the version number)
    # kerl build git https://github.com/erlang/otp.git $GIT_TAG $VERSION_NAME

    # GIT_TAG="OTP-18.3.2" # https://github.com/erlang/otp/tags
    VERSION_NAME="18.3.4.4" # The name you want to give this build (I generally just go with the version number)
    kerl build "$VERSION_NAME" "$VERSION_NAME"

    # Update kerl to use tarballs of Erlang from git tags
    export KERL_BUILD_BACKEND=git
    kerl update releases

    # Install the build
    mkdir -p $HOME/erlang/"$VERSON_NAME"
    kerl install $VERSION_NAME ~/erlang/"$VERSION_NAME"

    # Activate the build
    . $HOME/erlang/"$VERSION_NAME"/activate

    append_to_shell_rc_files '. $HOME/erlang/'"$VERSION_NAME"'/activate'
}

install_go() {
    gvm install go1.4 -B
    gvm use go1.4 --default
}

install_gvm() {
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    . $HOME/.gvm/scripts/gvm
    append_to_shell_rc_files '[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"'
}

install_insync() {
    local version="insync_1.3.12.36116-trusty_amd64"
    local url="http://s.insynchq.com/builds/$version.deb"
    local filename="$HOME/Downloads/$version.deb"

    download_file $url $filename
    sudo dpkg -i $filename
}

install_kerl() {
    # Install kerl - basically nvm for erlang (although not as easy)
    # https://github.com/kerl/kerl
    local url="https://raw.githubusercontent.com/spawngrid/kerl/master/kerl"
    local filename="$HOME/Downloads/kerl"

    download_file $url $filename
    chmod +x $filename
    sudo mv $filename /usr/local/bin/
}

install_kiex() {
    # Install kiex - basically nvm for elixir
    # https://github.com/taylor/kiex
    \curl -sSL https://raw.githubusercontent.com/taylor/kiex/master/kiex | bash -s install_kiex

    append_to_shell_rc_files 'test -s "$HOME/.kiex/scripts/kiex" && source "$HOME/.kiex/scripts/kiex"'
}

install_kubectl() {
    local kubectl_version="1.2.3"
    local url="https://storage.googleapis.com/kubernetes-release/release/v$kubectl_version/bin/linux/amd64/kubectl"
    local filename="$HOME/Downloads/kubectl"

    download_file $url $filename

    chmod +x $filename
    sudo mv $filename /usr/local/bin/
}

install_node() {
    node_version="4.4.3"
    nvm install "$node_version"
}

install_nvm() {
    git clone https://github.com/creationix/nvm.git $HOME/.nvm && pushd $HOME/.nvm && git checkout `git describe --abbrev=0 --tags` && popd
    nvm_always
}

install_oh-my-zsh() {
    git clone https://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh
    cp $HOME/.zshrc $HOME/.zshrc.pre-oh-my-zsh
    cp $HOME/.oh-my-zsh/templates/zshrc.zsh-template $HOME/.zshrc
    # Copy the content from the original zshrc file to the new zshrc file
    cat $HOME/.zshrc.pre-oh-my-zsh >> $HOME/.zshrc
}

install_pyenv() {
    # https://github.com/yyuu/pyenv
    git clone https://github.com/yyuu/pyenv.git $HOME/.pyenv

    append_to_shell_rc_files 'export PYENV_ROOT="$HOME/.pyenv"'
    append_to_shell_rc_files 'export PATH="$PYENV_ROOT/bin:$PATH"'
    append_to_shell_rc_files 'eval "$(pyenv init -)"'

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
}

install_python() {
    # Ubuntu ships with Python installed, but we want to use pyenv to manage
    # multiple versions of Python
    PYTHON_VERSION="3.5.2"

    if [ $(which python) == '/usr/bin/python' ]; then
        echo "pyenv python is missing; installing now"
        pyenv install "$PYTHON_VERSION"
        pyenv global "$PYTHON_VERSION"

        pyenv rehash
        source_shell
    else
        echo "pyenv python already installed"
    fi
}

install_rails() {
    RAILS_VERSION="4.2.6"
    gem install rails -v "$RAILS_VERSION"
}

install_rbenv() {
    # Instructions from https://gorails.com/setup/ubuntu/16.04
    cd
    git clone https://github.com/rbenv/rbenv.git $HOME/.rbenv
    append_to_shell_rc_files 'export PATH="$HOME/.rbenv/bin:$PATH"'
    append_to_shell_rc_files 'eval "$(rbenv init -)"'
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
}

install_ruby-build() {
    git clone https://github.com/rbenv/ruby-build.git $HOME/.rbenv/plugins/ruby-build
    append_to_shell_rc_files 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"'
    export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
}

install_ruby() {
    # Ubuntu ships with Ruby installed, but we want to use rbenv to manage
    # multiple versions of Ruby
    RUBY_VERSION="2.3.1"

    if [ $(which ruby) == '/usr/bin/ruby' ]; then
        echo "rbenv ruby is missing; installing now"
        rbenv install "$RUBY_VERSION"
        rbenv global "$RUBY_VERSION"

        rbenv rehash
        source_shell
    else
        echo "rbenv ruby already installed"
    fi
}

install_slack() {
    local slack_version="slack-desktop-2.2.1-amd64.deb"
    local url="https://downloads.slack-edge.com/linux_releases/$slack_version"
    local filename="$HOME/Downloads/$slack_version"

    download_file $url $filename
    sudo dpkg -i $filename
}

set_default_shell_to_zsh() {
    if [ $(echo $SHELL) == "/usr/bin/zsh" ]; then
        echo "Default shell already set to zsh"
    else
        echo "Setting zsh as your primary shell"
        chsh -s $(which zsh)
    fi
}

set_os_version_vars() {
    # /etc/os-release contains a list of environment variables that can be
    # used to determine the current OS information
    # Available variables (samples from 16.04):
    # - NAME="Ubuntu"
    # - VERSION="16.04.1 LTS (Xenial Xerus)"
    # - ID=ubuntu
    # - ID_LIKE=debian
    # - PRETTY_NAME="Ubuntu 16.04.1 LTS"
    # - VERSION_ID="16.04"
    # - HOME_URL="http://www.ubuntu.com/"
    # - SUPPORT_URL="http://help.ubuntu.com/"
    # - BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
    # - UBUNTU_CODENAME=xenial
    . /etc/os-release

    UBUNTU_VERSION_NUMBER="$VERSION_ID"
}

nvm_always() {
    . $HOME/.nvm/nvm.sh
    append_to_shell_rc_files 'export NVM_DIR="$HOME/.nvm"'
    append_to_shell_rc_files '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm'
}

source_shell() {
    if [ $(echo $0) == "zsh" ]; then
        echo "sourcing zsh"
        source $HOME/.zshrc
    else
        echo "sourcing bash"
        source $HOME/.bashrc
    fi
}

update_gems() {
    gem update --system
}

###############################################################################
# End Install Functions
###############################################################################
#
###############################################################################
# Begin Install
###############################################################################

set_os_version_vars

echo ""
printf "Enter the name you want associated to your Git commits (eg: John Doe): "
read USER_NAME

echo ""
printf "Enter the email you want associated to your Git commits (eg. jdoe@protonmail.com): "
read USER_EMAIL

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

if [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.zshrc"
fi

append_to_shell_rc_files 'export PATH="$HOME/.bin:$PATH"'

add_apt_repo "git-core/ppa"
add_apt_repo "canonical-chromium-builds/stage"
do_spotify_preinstall

sudo apt-get update

remove_system_ruby

apt_install chromium-browser
apt_install httpie http
apt_install jq
apt_install git
configure_git $USER_NAME $USER_EMAIL
apt_install vim-gnome vim
# Allows setup of better window management; I use Put to move windows from monitor to monitor
apt_install compizconfig-settings-manager
apt_install compiz-plugins
# Allows for making the notification bar transparent
apt_install unity-tweak-tool
apt_install git-crypt
apt_install vpnc

# Erlang install dependencies
apt_install m4
apt_install libncurses5-dev
apt_install autoconf

# Ruby install dependencies
apt_install zlib1g-dev
apt_install build-essential
apt_install libssl-dev
apt_install libreadline-dev
apt_install libyaml-dev
apt_install libsqlite3-dev
apt_install sqlite3
apt_install libxml2-dev
apt_install libxslt1-dev
apt_install libcurl4-openssl-dev
apt_install python-software-properties
apt_install libffi-dev

# Go install dependencies
apt_install mercurial
apt_install make
apt_install binutils
apt_install bison
apt_install gcc

# Slack install dependencies
apt_install libappindicator1

# Python install dependencies
apt_install libbz2-dev

# Docker install dependencies
apt_install apt-transport-https
apt_install ca-certificates
apt_install linux-image-extra-$(uname -r)
apt_install linux-image-extra-virtual

apt_install zsh
set_default_shell_to_zsh

install_by_directory "$HOME/.oh-my-zsh" "oh-my-zsh"
install_by_directory "$HOME/.nvm" "nvm"

install_if_missing rbenv
install_if_missing "ruby-build"
install_ruby
update_gems
install_if_missing bundler
install_if_missing rails
install_if_missing kubectl
install_if_missing node
install_if_missing atom
install_if_missing kerl
install_if_missing erl
install_if_missing kiex
install_if_missing elixir
install_if_missing gvm
install_if_missing go
install_if_missing pyenv
install_python
install_docker
create_a_docker_group
install_by_directory "$HOME/.dvm" "dvm"
install_docker_client

# Personal Items
apt_install keepass2
apt_install spotify-client spotify

install_if_missing slack
install_if_missing insync

# Cleanup
echo "Cleaning up!"
sudo apt autoremove

# Generate an SSH key and instruct user to add it to GitHub/GitLab
generate_ssh "$USER_EMAIL"

echo "Install script finished! Restart your computer"
echo "Some changes may require at least a logout so the restart is a good idea"
