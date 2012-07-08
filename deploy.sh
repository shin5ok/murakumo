#!/bin/sh

sudo rsync -axv --delete -H --exclude ".git" --exclude "deploy.sh" /home/kawano/murakumo/ /home/smc/murakumo/
sudo chown -R root.root /home/smc/murakumo/
