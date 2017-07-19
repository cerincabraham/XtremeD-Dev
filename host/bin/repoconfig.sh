#!/bin/bash
# store per-repo settings and variables in here
# then use:
# source repoconfig.sh
# to import them to different scripts

cpu=`uname -m`

if [ -z "$HOME" ] || [ "$HOME" == "/" ]; then
  HOME=~root
fi

DEFAULT_REPO="cerincabraham/XtremeD-Dev"
DEV_REPO="cerincabraham/XtremeD-Dev"
TESTKIT_REPO="cerincabraham/XtremeD-Dev"
TESTKITDEV_REPO="cerincabraham/XtremeD-Dev"

CONFIG_PROPS="${HOME}/3dPrinters/config.properties"

PHOTOCENTRIC_PORTNO=9091
PHOTOCENTRIC_PASSWD=xtreme4630
