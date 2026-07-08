#!/bin/bash

DISPLAY_OLD=$(echo $DISPLAY)
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [[ "$DISPLAY_OLD" == "" ]]; then
    echo -e "Error: The DISPLAY environment variable is missing. Enter \nExample: DISPLAY=:0 $SCRIPT_DIR/Install_bash_WebDesktopGL.sh"
    exit 1
fi

function Install_bash_WebDesktopGL() {

if ! command -v apt-get >/dev/null 2>&1; then
sudo pacman -S cmake build-essential libx11-dev libx11-xcb-dev libxcb-glx0-dev libxcb-keysyms1-dev libgl1-mesa-dev libxtst-dev libjpeg-turbo*-dev libjpeg-turbo* libglu1-mesa-dev libxext-dev libxi-dev libxmu-dev ocl-icd-opencl-dev opencl-headers libturbojpeg-dev xserver-xorg-video-fbdev xserver-xorg-video-dummy x11-utils libxdo3 xclip # imagemagick ffmpeg
else
sudo apt-get install cmake build-essential libx11-dev libx11-xcb-dev libxcb-glx0-dev libxcb-keysyms1-dev libgl1-mesa-dev libxtst-dev libjpeg-turbo*-dev libjpeg-turbo* libglu1-mesa-dev libxext-dev libxi-dev libxmu-dev ocl-icd-opencl-dev opencl-headers libturbojpeg-dev xserver-xorg-video-fbdev xserver-xorg-video-dummy x11-utils libxdo3 xclip # imagemagick ffmpeg
fi

SCRIPT_DIR=$1

rm -rf "/tmp/virtualgl_main_build"
mkdir "/tmp/virtualgl_main_build" && cd "/tmp/virtualgl_main_build"
cmake -S "$SCRIPT_DIR"/virtualgl-main -B "/tmp/virtualgl_main_build" -DCMAKE_BUILD_PARALLEL_LEVEL=$(nproc) && \
# rm -rf "$SCRIPT_DIR"/virtualgl-main/build
# mkdir "$SCRIPT_DIR"/virtualgl-main/build && cd "$SCRIPT_DIR"/virtualgl-main/build
# cmake .. -DCMAKE_BUILD_PARALLEL_LEVEL=$(nproc) && \
make -j$(nproc) && \
make install && \

echo "FINISH VirtualGL"

cd "$SCRIPT_DIR"

tar -xf "$(ls "$SCRIPT_DIR"/*chromium* | grep .tar)" && echo "FINISH chromium" &&

# Compilation
if  gcc -o "$SCRIPT_DIR/xdotool_xseticon" "$SCRIPT_DIR/Xdotool_xseticon.c" -lX11 2>/dev/null; then
    echo "Compilation $SCRIPT_DIR/xdotool_xseticon"
    #rm -f "$SCRIPT_DIR/xdotool_xseticon.c"
    exit 0
else
    echo "Error compiling $SCRIPT_DIR/Xdotool_xseticon.c: check gcc and X11-dev (sudo apt install libx11-dev or sudo pacman -S libx11)"
    #rm -f "$SCRIPT_DIR/xdotool_xseticon.c"
    exit 1
fi

}

if ! command -v konsole >/dev/null 2>&1; then
    echo "Error: Install konsole (sudo apt install konsole or sudo pacman -S konsole)"
    Install_bash_WebDesktopGL "$SCRIPT_DIR"
    else
    nohup konsole --hold -e bash -c "$(declare -f Install_bash_WebDesktopGL); Install_bash_WebDesktopGL \"$SCRIPT_DIR\"" /dev/null 2>&1 &
fi
