#!/bin/sh

IP="${FPGA_IP_ADDRESS=192.168.2.12}"
SRC="downloadEVFR.bit"
DST="EVCLIENT_A.bit"

for i
do
    echo "$i"
    case "$i" in
        [0-9]*) IP="$i" ;;
        [AB]) DST="EVCLIENT_$i.bit" ;;
        *.bit) SRC="$i" ;;
        *)  echo "Usage: $0 [IP_ADDRESS] [A|B] [filename.bit}" >&2 ; exit 1 ;;
    esac
done

set -x

test -r "$SRC"
set `wc -c "$SRC"`
size="$1"
tftp -v -m binary "$IP" -c put "$SRC" "$DST"
sleep 1
tftp -v -m binary "$IP" -c get "$DST" chk.bit
set +e
if cmp -n $size "$SRC" chk.bit
then
    echo "Flash write succeeded."
    rm chk.bit
else
    echo "Flash write may have failed!"
fi
