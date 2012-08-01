#!/bin/sh
sudo rsync -axv --delete -H --exclude ".git" --exclude "deploy.sh" --exclude "*.swp" $HOME/murakumo/ /home/smc/murakumo/
sudo chown -R root.root /home/smc/murakumo/
