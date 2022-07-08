I use this script as a *"remote control"* for **mpv**.
`[play] FILE...`, will start mpv, playing FILE, if **mpv**,
is already running, FILE will get added to the playlist queue.

For this thing to work add this to `~/.config/mpv/mpv.conf`:  
```text
input-ipc-server='/tmp/mp_pipe'
```

**mute** and **vol** will use `pactl` to communicate
with **pulseaudio**.

### synopsis

```text
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
```

### example

**i3wm** keybinings:  
```
set $W bindsym Mod4
set $M exec --no-startup-id mediacontrol

$W+minus                     $M speed -
$W+equal                     $M speed +

$W+bracketleft               $M prev 
$W+bracketright              $M next

$W+Shift+braceleft           $M seek -10
$W+Control+braceleft         $M seek -300
$W+Shift+Control+braceleft   $M seek -60

$W+Shift+braceright          $M seek +10
$W+Control+braceright        $M seek +300
$W+Shift+Control+braceright  $M seek +60

$W+slash                     $M toggle

$W+apostrophe                $M vol -2%
$W+backslash                 $M vol +2%

$W+Shift+quotedbl            $M vol mic -2%
$W+Shift+bar                 $M vol mic +2%

$W+period                    $M mute
$W+Shift+greater             $M mute mic

$W+0                         $M screenshot
```

