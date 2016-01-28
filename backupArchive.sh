#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
source $DIR/config.cfg

set +e

rsync -a --bwlimit=$RSYNC_BWLIMIT $DIR/archive/ $REMOTE_SERVER_HOST:$REMOTE_SERVER_PATH/archive

if [ -v REMOTE_BACKUP_SERVER_HOST ]; then
    rsync -a --bwlimit=$RSYNC_BWLIMIT $DIR/archive/ $REMOTE_BACKUP_SERVER_HOST:$REMOTE_BACKUP_SERVER_PATH/archive
fi
