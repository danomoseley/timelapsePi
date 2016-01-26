#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

rsync -a --bwlimit=$RSYNC_BWLIMIT $DIR/archive/ $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/archive

