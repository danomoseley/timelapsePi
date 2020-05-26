#!/bin/bash

if [ -f /tmp/reboot.now ]; then
   /sbin/reboot
fi
