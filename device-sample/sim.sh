#!/bin/bash

COUNTER=1
DEVICE_PREFIX="$1"
NUM=$4

while [ $COUNTER -le $NUM ];
do
    if [ $COUNTER -lt 10 ]; then
        DEVICE_NAME="${DEVICE_PREFIX}0${COUNTER}"
    else
        DEVICE_NAME="${DEVICE_PREFIX}${COUNTER}"
    fi
    python migratable.py $DEVICE_NAME $2 $3 &
    COUNTER=$((COUNTER+1))
done

echo "Press 'q' to exit"
while true; do
read -rsn1 input
if [ "$input" = "q" ]; then
    killall -9 python
fi
done