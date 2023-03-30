#!/bin/bash

#
# Check if we have a Firefly configured
#

set -u

CFG_FILES=$@

FIREFLY_CFG=""
for f in $CFG_FILES
do
    FIREFLY_CFG=`grep -E '^#define *CFG_EVIO_FIREFLY_COUNT +[0-9]+ *$' $f | awk '{print $3}'`
    [[ ! -z "$FIREFLY_CFG" ]] && break
done

KICKER_DRIVER_CFG=""
for f in $CFG_FILES
do
    KICKER_DRIVER_CFG=`grep -E '^#define[ \t]*.*KICKER_DRIVER[ \t]*$' $f | awk '{print $2}'`
    [[ ! -z "$KICKER_DRIVER_CFG" ]] && break
done

if [[ $FIREFLY_CFG -gt 0 ]] && [[ -z "$KICKER_DRIVER_CFG" ]]; then
    echo "Y" | tr -d "\n"
else
    echo "N" | tr -d "\n"
fi
