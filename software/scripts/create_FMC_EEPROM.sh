#!/bin/sh
# Usage: ./create_FMC_EEPROM.sh serial_number1 [serial_number2 ... serial_numberN]
#   This will generate the relative eeprom_X.bin files, where X stand for the serial number
#   Note: the script requires pts_core available here https://github.com/neub/pts_core/
#         which path should be included in the PYTHONPATH environment variable through
#         the instructions below. Currently it's required Python 2.7 too.
set -ex

PTS_CORE_PATH="$HOME/Project/pts_core/tools"
if [ ! -d ${PTS_CORE_PATH} ]; then
    echo "${PTS_CORE_PATH} path doesn't seems to exist.\
Please read the note in the script."
    exit 1
fi

export PYTHONPATH="$PYTHONPATH=:$HOME/Project/pts_core/tools"
export FRU_VERBOSE=1

usage()
{
    echo "Usage: $0 ### [### ...]" >&2
    exit 1
}

if [ $# = 0 ]
then
    usage
fi
for sn in "$@"
do
    # Note: commented code in case EVRIO has multiple revisions
    # case "$sn" in
    #     00[12])          REV="0" ;;
    #     [0-9][0-9][0-9]) REV="A" ;;
    #     *)               usage ;;
    # esac
    REV="0"
    python2 fru-generator \
                        -o eeprom_${sn}.bin \
                        -v LBNL \
                        -n "EVRIO" \
                        -p "EVRIO Rev. ${REV}" \
                        -s "${sn}"
    fru-dump -i eeprom_$sn.bin -b -c -p -2 -v
done
