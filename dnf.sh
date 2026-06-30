#!/bin/sh

sudo dnf upgrade --refresh -y \
  && sudo dnf autoremove -y
