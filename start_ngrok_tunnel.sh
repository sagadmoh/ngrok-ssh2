#!/bin/bash

USER=$(whoami)
UNPACK="unzip -o"

if [[ -z "$NGROK_TOKEN" ]]; then
  echo "Please set 'NGROK_TOKEN'"
  exit 1
fi

echo "### Prep for remote login and install ngrok ###"

case $(uname) in
    Darwin)
        PKG="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip"
        ;;
    Linux)
        # By default, the Actions runner user lacks a .ssh directory and also
        # has a home directory with permissions 777, and sshd will refuse to
        # allow an incoming connection in that state.
        chmod 755 "$HOME"
        mkdir "$HOME"/.ssh
        #sudo useradd -m saHOST
        #sudo adduser saHOST sudo
        #echo 'saHOST:123qwe' | sudo chpasswd
        #su saHOST
        #sudo sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd
        #mkdir -p /var/run/sshd
        #echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
        
        PKG="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
        UNPACK="tar xzvf"
        ;;
    *_NT-*)
        # I wasn't able to get remote login working on Windows using the public key
        # approach we do below on macOS/Linux, so we settle for having to enter a
        # password.
        if [[ -z "$USER_PASS" ]]; then
            echo "Please set 'USER_PASS' for user: $USER"
            exit 1
        fi
        net user "$USER" "$USER_PASS"
        PKG="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
        exe=.exe
        ;;
esac

if [[ $(uname) = "Darwin" || $(uname) = "Linux" ]]; then
    # Install a public key so we can login via SSH without a password.
    if [[ -z "$SSH_PUBLIC_KEY" ]]; then
        echo "Please set 'SSH_PUBLIC_KEY'"
        exit 1
    fi
    chmod 700 "$HOME"/.ssh
    echo "$SSH_PUBLIC_KEY" >> "$HOME"/.ssh/authorized_keys
    chmod 600 "$HOME"/.ssh/authorized_keys
    IDENTITY="-i ~\/.ssh\/ngrok"
fi

curl -o ngrok.zip "$PKG"
$UNPACK ngrok.zip

echo "### Start ngrok proxy for 22 port ###"

rm -f .ngrok.log
./ngrok$exe authtoken "$NGROK_TOKEN"
./ngrok$exe tcp 22 --log ".ngrok.log" &

sleep 10
HAS_ERRORS=$(grep "command failed" < .ngrok.log)

if [[ -z "$HAS_ERRORS" ]]; then
  echo "=========================================="
  cat  .ngrok.log
  echo "=========================================="
  echo "To connect: $(grep -o -E "tcp://(.+)" < .ngrok.log | sed "s/tcp:\/\//ssh $IDENTITY $USER@/" | sed "s/:/ -p /")"
  echo "=========================================="
else
  echo "$HAS_ERRORS"
  exit 4
fi
