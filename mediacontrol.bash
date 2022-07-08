#!/bin/bash

# SPDX-FileCopyrightText: 2018-2022, budRich <at budlabs>
# SPDX-License-Identifier: 0BSD

_lock=/tmp/mediacontrol_lock
while [[ -f $_lock ]]; do sleep .2 ; done
touch "$_lock"
trap 'rm "$_lock"' EXIT

: "${MPV_FIFO_FILE:=/tmp/mp_pipe}"

_name="mediacontrol"
_version="0.1"
_author="budRich"
_created="2018-09-03"
_updated="2022-07-07"

valid_commands=(
  vol mute
  toggle pause stop play
  next prev
  seek speed
  screenshot
)

default_command=toggle

[[ $* =~ (^|\s+)(-h|--help) ]] && {
cat << 'EOB' >&2
mediacontrol # default to toggle wihtout command
mediacontrol vol   [mic] [+|-]INT[%]
mediacontrol mute  [mic]
mediacontrol speed [+|-]
mediacontrol play  [FILE1|DIR FILE2...]
mediacontrol FILE1|DIR [FILE2 FILE3...]
mediacontrol [FILE2 FILE3...] <<< FILE1|DIR
mediacontrol next|prev|toggle|stop|pause|screenshot
mediacontrol -V|--version
mediacontrol -h|--help
EOB
exit
}

[[ $* =~ (^|\s+)(-V|--version) ]] && {
cat << EOB >&2
$_name - version: $_version
last update: $_updated
EOB
exit
}

[[ $BASHBUD_LOG ]] && {
  [[ -f $BASHBUD_LOG ]] || mkdir -p "${BASHBUD_LOG%/*}"
  exec 3>&2
  __stderr=3
  exec 2>> "$BASHBUD_LOG"
}

ERR(){ >&2 echo "${_name}:[WARNING]:" "$*"; }
ERM(){ >&2 echo "${_name}:" "$*"; }
ERX(){ >&2 echo "${_name}:[ERROR]:" "$*" && exit 1 ; }

# allow one file/directory on stdin, useful for:
# ls ~/Music | dmenu | mediacontrol
[[ ! -t 0 ]] && stdin=$(< /dev/stdin)
[[ -e $stdin ]] && set "$stdin" "$@"

lastarg=${!#} firstarg=${1:-$default_command}

# do this to be sure shift below doesn't shift away
# our files.
[[ -e $firstarg ]] && {
  set -- play "$firstarg" "${@:2}"
  firstarg=play
}

for command in "${valid_commands[@]}" invalid; do
  [[ $firstarg = "$command" ]] && break
done

shift

if [[ $command = invalid ]]; then
  ERX "arg1: '$1' , is not a valid command."

elif [[ $command = mute ]]; then
  if [[ $1 = mic ]]
    then pactl set-source-mute @DEFAULT_SOURCE@ toggle
    else pactl set-sink-mute   @DEFAULT_SINK@   toggle
  fi

  exit

elif [[ $command = vol ]]; then
  amount=$lastarg
  [[ $amount =~ [^-+0-9%] ]] && amount='+2'
  amount="${amount%\%}%"

  if [[ $1 = mic ]]
    then pactl set-source-volume @DEFAULT_SOURCE@ "$amount"
    else pactl set-sink-volume   @DEFAULT_SINK@   "$amount"
  fi

  exit

elif [[ $command = play && -e $1 ]]; then
  # passing file paths to play command, expand first
  # arg if it is a directory. Make sure files are supported.
  # if multiple files, create a playlist (is faster to load)
  [[ -d $1 ]] && set "${1%/}/"* "${@:2}"

  if (($# > 1)); then
    playlist_tmp=$(mktemp /tmp/XXXXXX.m3u8)
    echo '#EXTM3U' > "$playlist_tmp"
    for file; do
      [[ ! -f $file || ${file,,} =~ (png|docx|jpg|cue|log|m3u|m3u8)$ ]] && continue
      realpath "$file"
    done >> "$playlist_tmp"

    [[ $(wc -l < "$playlist_tmp") -lt 2 ]] \
      && ERX "none of the files are supported"

    set "$playlist_tmp"

  elif [[ ! -f $1 || $1 =~ (png|docx|jpg|cue|log)$ ]]; then
    ERX "file '$1' not supported"
  fi

  pidof mpv >/dev/null || {
    nohup env mpv "$@" > /dev/null 2>&1 &
    exit
  }

elif ! pidof mpv >/dev/null
  then ERX "mpv isn't running"

fi

[[ -S $MPV_FIFO_FILE ]] \
  || ERX "mpv socket: '$MPV_FIFO_FILE', doesn't exist"

mpv_msg(){ echo "$*" | socat - "$MPV_FIFO_FILE" > /dev/null ;}

case "$command" in
  toggle          ) mpv_msg "cycle pause"                                    ;;
  stop|screenshot ) mpv_msg "$command"                                       ;;
  next|prev       ) mpv_msg "playlist-$command"                              ;;
  pause           ) mpv_msg '{ "command": ["set_property", "pause", true] }' ;;

  speed           )
    arg=$lastarg ammount=1.1
    [[ $arg = "$command" ]] && arg=+
    [[ $arg = + ]] || ammount="1/$ammount"
    mpv_msg "multiply speed $ammount"
    ;;

  seek            )
    amount=$lastarg
    [[ $amount =~ ^[+-][0-9]*$ ]] || amount='+2'
    mpv_msg "seek $amount"
    ;;

  play           )
    (($#)) || {
      mpv_msg '{ "command": ["set_property", "pause", false] }'
      exit
    }

    if [[ $1 =~ m3u[8]?$ ]]
      then mpv_msg "loadlist $1 append-play"
      else mpv_msg "loadfile \"${1//\"/\\\"}\" append-play"
    fi
    ;;

  * ) exit ;;
esac
