#!/bin/bash

source "$2"
quantity=${#arr_txt[@]}
echo "Number of elements: $quantity"
#icon_text="${arr_txt[0]}"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
while true; do
    pid=$(pgrep "$1")

    if [[ "$pid" != "" ]]; then

        count=0;
        while true; do

            DISPLAY=$(ps -u $(id -u) -o pid= | xargs -I{} cat /proc/{}/environ 2>/dev/null |  tr '\0' '\n' | grep -m1 '^DISPLAY=' | cut -d'=' -f2-)

            if [ -n "$DISPLAY" ]; then
                echo "DISPLAY=$DISPLAY"
                break
            fi

            ((count += 1))

            if (( $count == 6  )); then
                echo "DISPLAY not detected"
                #exit 0
                continue
            fi

            sleep 5
        done

        window_id_pid="$(DISPLAY=$DISPLAY "$SCRIPT_DIR/xdotool_xseticon" search --name "$1")";
        if [ "$?" != "0" ]; then
            sleep 2;
            continue
        fi

        if [[ $quantity == "1" ]]; then
            DISPLAY=$DISPLAY "$SCRIPT_DIR/xdotool_xseticon" xseticon "$window_id_pid" ${arr_txt[$icon_text]}
            echo -e "The number of elements is 1, so it's set only once. /nIf you want to constantly update the image, use an array of 2 identical elements."
            exit 0
        fi

        flag=true
        while $flag; do
            for ((icon_text=0; icon_text<$quantity; icon_text++)); do

                DISPLAY=$DISPLAY "$SCRIPT_DIR/xdotool_xseticon" xseticon "$window_id_pid" ${arr_txt[$icon_text]}
                if [ "$?" != "0" ]; then
                    sleep 2;
                    flag=false
                    break
                fi
                sleep 0.05;

            done
        done

    else
        echo "Error"
        sleep 1;
    fi
done
