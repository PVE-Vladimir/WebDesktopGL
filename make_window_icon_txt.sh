#!/bin/bash

check_deps() {
    local missing_packages=()

    if ! command -v convert >/dev/null 2>&1; then
        missing_packages+=("ImageMagick (sudo apt install imagemagick or sudo pacman -S imagemagick)")
    fi

    if ! command -v ffmpeg >/dev/null 2>&1; then
        missing_packages+=("FFmpeg (sudo apt install ffmpeg or sudo pacman -S ffmpeg)")
    fi

    if [ ${#missing_packages[@]} -gt 0 ]; then
        for package in "${missing_packages[@]}"; do
            echo "Error: Install $package"
        done
        exit 1
    fi
}

check_deps

flag_dir="0"
flag_alpha_channel="0"
flag_frame="20"
flag_frame_true="0"
flag_webp="0"
flag_mp4="0"
flag_mov="0"
declare -a arr_txt

process_png_files_in_directory() {
    local output_dir=$1
    flag_dir="1"
    # Processing all PNG files
    for png_file in "$output_dir"/*.png; do
        if [[ -f "$png_file" ]]; then
            local png_name=$(echo "$png_file" | sed 's/.png//')
            make_window_icon_txt "$png_name"
        fi
    done
    flag_dir="0"
    declare -p arr_txt > "$output_dir/$(basename "$output_dir").txt"
    arr_txt=();
}

process_gif_files_in_directory() {
    local output_dir="$1"
    local frame=$flag_frame

    if [[ "$flag_webp" == "1" ]]; then
        ffmpeg -y -framerate "$frame" -pattern_type glob -i "$output_dir/*.png" -loop 0 -quality 100 "$output_dir/$(basename "$output_dir")_frame_$frame.webp"
        #The .apng format is too rare, but it is possible to use it
        #ffmpeg -y -framerate "$frame" -pattern_type glob -i "$output_dir/*.png" -plays 0 "$output_dir/$(basename "$output_dir")_frame_$frame.apng"
    elif [[ "$flag_mp4" == "1" ]]; then
        ffmpeg -y -framerate "$frame" -pattern_type glob -i "$output_dir/*.png" \
        -c:v libx265 \
        -crf 12 \
        -preset veryslow \
        -pix_fmt yuv444p \
        -x265-params "keyint=1:scenecut=0" \
        -movflags +faststart \
        "$output_dir/$(basename "$output_dir")_frame_$frame.mp4"
    elif [[ "$flag_mov" == "1" ]]; then
        ffmpeg -y -framerate "$frame" -pattern_type glob -i "$output_dir/*.png" \
        -c:v prores_ks -profile:v 4444 \
        "$output_dir/$(basename "$output_dir")_frame_$frame.mov"
    else
        ffmpeg -y -framerate "$frame" -pattern_type glob -i "$output_dir/*.png" \
        -filter_complex "[0:v] split [a][b];[a] palettegen [p];[b][p] paletteuse" -loop 0 \
        "${output_dir}/$(basename "$output_dir")_frame_$frame.gif"
    fi
}

make_icon_gif() {
    local output_dir=$1
    local type=$2
    mkdir -p "$output_dir"

    if [[ "$type" == "gif" ]]; then
        ffmpeg -i "$output_dir.gif" "$output_dir/frame_%08d.png"
    elif [[ "$type" == "webp" ]]; then
        convert "$output_dir.webp" \
        -background none \
        -virtual-pixel transparent \
        -filter point -depth 8 -define png:color-type=6 \
        -distort SRT "0,0 1 0 %[fx:page.x],%[fx:page.y]" \
        -extent "$(identify -format "%[page]" "$output_dir.webp[0]")" \
        "$output_dir/frame_%08d.png"
    elif [[ "$type" == "mp4" ]]; then
        ffmpeg -i "$output_dir.mp4" -vf "format=rgb32,scale=trunc(iw/2)*2:trunc(ih/2)*2" -q:v 0 -vsync vfr "$output_dir/frame_%08d.png"
    elif [[ "$type" == "mov" ]]; then
        ffmpeg -i "$output_dir.mov" -vf "format=rgb32,scale=trunc(iw/2)*2:trunc(ih/2)*2" -q:v 0 -vsync vfr "$output_dir/frame_%08d.png"
    fi
    process_png_files_in_directory "$output_dir"
    echo "Frames extracted to '$output_dir/'"
}

make_window_icon_txt() {
    local PNG_DIR=$1

    # Replace with the path to your PNG file
    input_png="$PNG_DIR.png"

    # Get the width and height
    width=$(identify -format "%w" "$input_png")
    height=$(identify -format "%h" "$input_png")

    # -alpha on -channel RGBA may not be needed
    argb_pixels=$( convert "$input_png" -alpha on -channel RGBA rgba:- | od -t x1 -v -An | tr -d '\n' | sed 's/ //g' | sed 's/*//g' | fold -w8 | awk '{
        # Extract bytes: rr gg bb aa (in hex for RGBA)
        rr = substr($0, 1, 2);
        gg = substr($0, 3, 2);
        bb = substr($0, 5, 2);
        aa = substr($0, 7, 2);
        # Convert to ARGB: aa rr gg bb
        pixel = "0x" aa rr gg bb;
        if (NR > 1) printf " %s", pixel;
        else printf "%s", pixel;
    } END { printf "\n" }' | tr -d '\n')

    # If necessary, form a full array with commas: [width, height, pixels...] and in argb_pixels if (NR > 1) printf ", %s", pixel;
    array="${width} ${height} ${argb_pixels}"

    if [[ "$flag_alpha_channel" == "1" ]]; then
        array=$(echo "$array" | sed 's/0xffffffff/0x00000000/g' \
        | sed 's/0xfffafeff/0x00000000/g' | sed 's/0xfffefaff/0x00000000/g'\
        | sed 's/0xfff2fefe/0x00000000/g' | sed 's/0xffe9fefe/0x00000000/g' )
        if [[ "$flag_dir" == "1" ]]; then
            mkdir -p "$output_dir/$(basename "$output_dir")_alpha_channel"
            make_window_icon_png "$output_dir/$(basename "$output_dir")_alpha_channel/$(basename "$PNG_DIR")_alpha_channel.png" $array
        else
            make_window_icon_png "${PNG_DIR}_alpha_channel.png" $array
        fi
    fi

    if [[ "$flag_dir" == "1" ]]; then
        arr_txt+=("$array")
    else
        echo "declare -a arr_txt=([0]=\"$array\")" > "$PNG_DIR.txt"
        echo "$array";
    fi
}

make_window_icon_png() {
    local PNG_DIR=$1
    local width=$2
    local height=$3
    shift 3
    local array=("$@")

    for ((i=0; i<${#array[@]}; i++)); do
        hex=${array[i]#0x}
        A=${hex:0:2}
        R=${hex:2:2}
        G=${hex:4:2}
        B=${hex:6:2}
        printf '%b' "\x$R\x$G\x$B\x$A"
    done | convert -size "${width}x$height" -depth 8 -define png:color-type=6 rgba:- "$PNG_DIR"
#     | convert -size "${width}x$height" -depth 8 rgba:- \
#         -filter Gaussian -define filter:support=5 -blur 0x1 \
#         "$PNG_DIR"
#     | convert -size "${width}x$height" -depth 8 -define png:color-type=6 rgba:- "$PNG_DIR"
#     | convert -size "${width}x$height" -define png:transparency-palette=1 -colors 256 -depth 8 rgba:- "$PNG_DIR"
}

make_window_txt_icon() {
source "$1.txt"
local PNG_DIR=$1
local output_dir=$1
quantity=${#arr_txt[@]}
dir_alpha_channel="${PNG_DIR}_alpha_channel_txt.png"
dir_txt="${PNG_DIR}_txt.png"

if [[ "$flag_alpha_channel" == "1" ]]; then
    mkdir -p "${output_dir}_alpha_channel_txt"
    dir_alpha_channel="${output_dir}_alpha_channel_txt/$(basename "$PNG_DIR")_0_alpha_channel_txt.png"
elif [[ "$flag_frame_true" == "1" ]]; then
    mkdir -p "${output_dir}_txt"
    dir_txt="${output_dir}_txt/$(basename "$PNG_DIR")_${icon_text}_txt.png"
fi

if [[ $quantity == "1" ]]; then
    if [[ "$flag_alpha_channel" == "1" ]]; then
        array=$(echo "${arr_txt[0]}" | sed 's/0xffffffff/0x00000000/g' \
        | sed 's/0xfffafeff/0x00000000/g' | sed 's/0xfffefaff/0x00000000/g'\
        | sed 's/0xfff2fefe/0x00000000/g' | sed 's/0xffe9fefe/0x00000000/g' )
        make_window_icon_png "$dir_alpha_channel" $array
    else
        array=$(echo "${arr_txt[0]}")
        make_window_icon_png "$dir_txt" $array
    fi
else
    for ((icon_text=0; icon_text<$quantity; icon_text++)); do
    if [[ "$flag_alpha_channel" == "1" ]]; then
        array=$(echo "${arr_txt[$icon_text]}" | sed 's/0xffffffff/0x00000000/g' \
        | sed 's/0xfffafeff/0x00000000/g' | sed 's/0xfffefaff/0x00000000/g'\
        | sed 's/0xfff2fefe/0x00000000/g' | sed 's/0xffe9fefe/0x00000000/g' )
        mkdir -p "${output_dir}_alpha_channel_txt"
        make_window_icon_png "${output_dir}_alpha_channel_txt/$(basename "$PNG_DIR")_$(printf "%08d" $icon_text)_alpha_channel_txt.png" $array
    else
        array=$(echo "${arr_txt[$icon_text]}")
        mkdir -p "${output_dir}_txt"
        make_window_icon_png "${output_dir}_txt/$(basename "$PNG_DIR")_$(printf "%08d" $icon_text)_txt.png" $array
    fi
    done
fi
arr_txt=();
}

for item_DIR_in in "$@"; do

    if [ "$item_DIR_in" -eq "$item_DIR_in" ] 2>/dev/null; then
        flag_frame="$item_DIR_in";
        flag_frame_true="1"
    elif [[ "$item_DIR_in" == "webp" ]]; then
        flag_webp="1"
    elif [[ "$item_DIR_in" == "mp4" ]]; then
        flag_mp4="1"
    elif [[ "$item_DIR_in" == "mov" ]]; then
        flag_mov="1"
    elif [[ "$item_DIR_in" == "gif" ]]; then
        echo "gif by default"
    elif [[ "$item_DIR_in" == "alpha" ]]; then
        flag_alpha_channel="1";
    elif [ -d "$item_DIR_in" ]; then
        process_png_files_in_directory "$item_DIR_in" ;
        if [[ "$flag_alpha_channel" == "1" ]]; then
            process_gif_files_in_directory "$item_DIR_in/$(basename "$item_DIR_in")_alpha_channel" ;
        else
            process_gif_files_in_directory "$item_DIR_in" ;
        fi
        flag_alpha_channel="0";
        flag_frame="20";
        flag_frame_true="0"
        flag_webp="0"
        flag_mp4="0"
        flag_mov="0"
    elif [[ "$item_DIR_in" == *.png ]]; then
        PNG_DIR_out=$(echo "$item_DIR_in" | sed 's/.png//')
        make_window_icon_txt "$PNG_DIR_out" ;
        flag_alpha_channel="0";
        flag_frame="20";
        flag_frame_true="0"
        flag_webp="0"
        flag_mp4="0"
        flag_mov="0"
     elif [[ "$item_DIR_in" == *.gif || "$item_DIR_in" == *.webp || "$item_DIR_in" == *.mp4 || "$item_DIR_in" == *.mov ]]; then
        ext="${item_DIR_in##*.}"
        GIF_DIR_out=$(echo "$item_DIR_in" | sed "s/.$ext//")
        make_icon_gif "$GIF_DIR_out" "$ext" ;
        if [[ "$flag_alpha_channel" == "1" ]]; then
            process_gif_files_in_directory "$GIF_DIR_out/$(basename "$GIF_DIR_out")_alpha_channel" ;
        elif [[ "$flag_frame_true" == "1" ]]; then
            process_gif_files_in_directory "$GIF_DIR_out" ;
        fi
        flag_alpha_channel="0";
        flag_frame="20";
        flag_frame_true="0"
        flag_webp="0"
        flag_mp4="0"
        flag_mov="0"
    elif [[ "$item_DIR_in" == *.txt ]]; then
        ext="${item_DIR_in##*.}"
        GIF_DIR_out=$(echo "$item_DIR_in" | sed "s/.$ext//")
        make_window_txt_icon "$GIF_DIR_out"
        if [[ "$flag_alpha_channel" == "1" ]]; then
            process_gif_files_in_directory "${GIF_DIR_out}_alpha_channel_txt" ;
        elif [[ "$flag_frame_true" == "1" ]]; then
            process_gif_files_in_directory "${GIF_DIR_out}_txt" ;
        fi
        flag_alpha_channel="0";
        flag_frame="20";
        flag_frame_true="0"
        flag_webp="0"
        flag_mp4="0"
        flag_mov="0"
    else
        echo "Unsupported file type: $item_DIR_in" >&2
        flag_alpha_channel="0";
        flag_frame="20";
        flag_frame_true="0"
        flag_webp="0"
        flag_mp4="0"
        flag_mov="0"
    fi

done
