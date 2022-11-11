#!/bin/bash
python device.py dev01 $1 &
python device.py dev02 $1 &

echo "Press 'q' to exit"
while true; do
read -rsn1 input
if [ "$input" = "q" ]; then
    killall -9 python
fi
done