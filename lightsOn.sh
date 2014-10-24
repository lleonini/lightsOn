#!/bin/bash
# lightsOn.sh

# Copyright (c) 2013 iye.cba at gmail com
# url: https://github.com/iye/lightsOn
# Maintainer: Dylan Smith
# url: https://github.com/dyskette/lightsOn
# This script is licensed under GNU GPL version 2.0 or above

# Description: Bash script that prevents the screensaver and display power
# management (DPMS) to be activated when you are watching Flash or HTML5 Videos.
#
# It can detect mpv, mplayer, minitube, and VLC when they are fullscreen too.
# Also, screensaver can be prevented when certain specified programs are running.
# lightsOn.sh can work with any screensaver if xdotool is installed

# HOW TO USE: Start the script with the number of seconds you want the checks
# for fullscreen to be done. Example:
#
# "./lightsOn.sh 120 &" will Check every 120 seconds if any of the supported
# applications are fullscreen and delay screensaver and Power Management if so.
#
# You want the number of seconds to be ~10 seconds less than the time it takes
# your screensaver or Power Management to activate. If you don't pass an
# argument, the checks are done every X seconds. Where X is calculated based on
# your system sleep time, with a minimum of $default_sleep_delay.
#
# An optional array variable exists here to add the names of programs that will
# delay the screensaver if they're running. This can be useful if you want to
# maintain a view of the program from a distance, like a music playlist.
#
# If you use this feature, make sure you use the name of the binary of the
# program (which may exist, for instance, in /usr/bin).

# DEBUG=0 for no output
# DEBUG=1 for sleep prints
# DEBUG=2 for everything
DEBUG=2

# this is actually the minimum allowed dynamic delay.
# Also the default (if everything else fails)
default_sleep_delay=50

# Modify these variables if you want this script to detect if MPV, Mplayer,
# VLC, Minitube, or a web browser Flash/HTML5 Video.
mplayer_detection=1
mpv_detection=1
vlc_detection=1
firefox_flash_detection=1
firefox_html5_detection=1
chromium_flash_detection=1
chromium_html5_detection=1
chromium_pepper_flash_detection=1
chrome_pepper_flash_detection=1
chrome_html5_detection=1
opera_flash_detection=1
opera_html5_detection=1
epiphany_html5_detection=1
webkit_flash_detection=1
minitube_detection=0

# Names of programs which, when running, you wish to delay the screensaver.
delay_progs=() # For example ('ardour2' 'gmpc')

# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE

log() {
    if [ $DEBUG -eq 2 ]; then
        echo $@
    elif [ $DEBUG -eq 1 ]; then
        if [ "$(echo $@ | grep -c "sleeping for")" == "1" ]; then
            echo $@
        fi
    fi
}

# enumerate all the attached screens
displays=""
while read id
do
    displays="$displays $id"
done < <(xvinfo | sed -n 's/^screen #\([0-9]\+\)$/\1/p')

# Detect screensaver been used (xscreensaver, kscreensaver or none)
if [ `pgrep -l xscreensaver | grep -wc xscreensaver` -ge 1 ]; then
    screensaver=xscreensaver
    log "xscreensaver detected"
elif [ `pgrep -l kscreensaver | grep -wc kscreensaver` -ge 1 ]; then
    screensaver=kscreensaver
    log "kscreensaver detected"
elif [ `pgrep -l xautolock | grep -wc xautolock` -ge 1 ]; then
    screensaver=xautolock
    log "xautolock detected"
else
    screensaver=None
    log "No screensaver detected, but it could be gnome"
fi

checkDelayProgs()
{
    log "checkDelayProgs()"
    for prog in "${delay_progs[@]}"; do
        if [ `pgrep -lfc "$prog"` -ge 1 ]; then
            log "checkDelayProgs(): Delaying the screensaver because a program on the delay list, \"$prog\", is running..."
            delayScreensaver
            break
        fi
    done
}

checkFullscreen()
{
    log "checkFullscreen()"
    # loop through every display looking for a fullscreen window
    for display in $displays
    do
        #get id of active window and clean output
        activ_win_id=`DISPLAY=:0.${display} xprop -root _NET_CLIENT_LIST_STACKING | sed 's/.*\, //'` #previously used _NET_ACTIVE_WINDOW, but it didn't work with some flash players (eg. Twitch.tv) in firefox. Using sed because id lengths can vary.

        # Skip invalid window ids (commented as I could not reproduce a case
        # where invalid id was returned, plus if id invalid
        # isActivWinFullscreen will fail anyway.)
        #if [ "$activ_win_id" = "0x0" ]; then
        #     continue
        #fi

        # Check if Active Window (the foremost window) is in fullscreen state
        if [[ -n $activ_win_id ]]; then
            isActivWinFullscreen=`DISPLAY=:0.${display} xprop -id $activ_win_id | grep _NET_WM_STATE_FULLSCREEN`
            isActivWinAbove=`DISPLAY=:0.${display} xprop -id $activ_win_id | grep _NET_WM_STATE_ABOVE`
            log "checkFullscreen(): Display: $display isFullScreen: \"$isActivWinFullscreen\""
            log "checkFullscreen(): Display: $display isAbove: \"$isActivWinAbove\""
            if [[ "$isActivWinFullscreen" = *NET_WM_STATE_FULLSCREEN* || "$isActivWinAbove" = *NET_WM_STATE_ABOVE* ]];then
                log "checkFullscreen(): Fullscreen detected"
                isAppRunning
                var=$?
                if [[ $var -eq 1 ]];then
                    delayScreensaver
                    return
                fi
            # If no Fullscreen active => set dpms on
            else
                log "checkFullscreen(): NO fullscreen detected"
                xset dpms
            fi
        fi
    done
}

# check if active windows is mplayer, vlc or firefox
#TODO only window name in the variable activ_win_id, not whole line.
#Then change IFs to detect more specifically the apps "<vlc>" and if process name exist

isAppRunning()
{
    log "isAppRunning()"
    #Get title of active window
    activ_win_title=`xprop -id $activ_win_id | grep "WM_CLASS(STRING)"`

    # Check if user want to detect Video fullscreen on Firefox, modify variable firefox_flash_detection if you dont want Firefox detection
    if [ $firefox_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *unknown* || "$activ_win_title" = *plugin-container* ]];then
        # Check if plugin-container process is running
            flash_process=`pgrep -l plugin-containe | grep -wc plugin-containe`
            #(why was I using this line avobe? delete if pgrep -lc works ok)
            #flash_process=`pgrep -lc plugin-containe`
            if [[ $flash_process -ge 1 ]];then
                log "isFirefoxFlashRunning(): firefox flash fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect HTML Video fullscreen on Firefox, modify variable firefox_html5_detection if you dont want Firefox detection
    if [ $firefox_html5_detection == 1 ];then
        if [[ "$activ_win_title" = *Firefox* ]];then
        # Check if firefox process is actually running
            firefox_process=`pgrep -lfc "firefox"`
            if [[ $firefox_process -ge 1 ]];then
                log "isAppRunning(): firefox html5 fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect Video fullscreen on Chromium, modify variable chromium_flash_detection if you dont want Chromium detection
    if [ $chromium_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *exe* || "$activ_win_title" = *chromium* ]];then
        # Check if Chromium Flash process is running
            flash_process=`pgrep -lfc ".*chromium.*flashp.*"`
            if [[ $flash_process -ge 1 ]];then
                log "isAppRunning(): chromium flash fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect html5 fullscreen on Chromium, modify variable chromium_html5_detection if you dont want Chromium html5 detection.
    if [ $chromium_html5_detection == 1 ];then
        if [[ "$activ_win_title" = *chromium* ]];then
        # Check if Chromium html5 process is running
            chromium_process=`pgrep -lfc "chromium"`
            if [[ $chromium_process -ge 1 ]];then
                log "isAppRunning(): chromium html5 fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect flash fullscreen on Chromium, modify variable chromium_pepper_flash_detection if you dont want Chromium pepper flash detection.
    if [ $chromium_pepper_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *chromium* ]];then
        # Check if Chromium Flash process is running
            chrome_process=`pgrep -lfc "chromium-browser --type=ppapi "`
            if [[ $chrome_process -ge 1 ]];then
                log "isAppRunning(): chromium flash fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect flash fullscreen on Chrome, modify variable chrome_pepper_flash_detection if you dont want Chrome pepper flash detection.
    if [ $chrome_pepper_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *google-chrome* ]];then
        # Check if Chrome Flash process is running
            chrome_process=`pgrep -lfc "(c|C)hrome --type=ppapi "`
            if [[ $chrome_process -ge 1 ]];then
                log "isAppRunning(): chrome flash fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect html5 fullscreen on Chrome, modify variable chrome_html5_detection if you dont want Chrome html5 detection.
    if [ $chrome_html5_detection == 1 ];then
        if [[ "$activ_win_title" = *google-chrome* ]];then
        # Check if Chrome html5 process is running
            #chrome_process=`pgrep -lfc "(c|C)hrome --type=gpu-process "`
            # Sorry, I didn't see any gpu-process in my pc
            chrome_process=`pgrep -lfc "(c|C)hrome"`
            if [[ $chrome_process -ge 1 ]];then
                log "isAppRunning(): chrome html5 fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect Video fullscreen on Opera, modify variable opera_flash_detection
    if [ $opera_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *operapluginwrapper* ]];then
        # Check if Opera flash process is running
            flash_process=`pgrep -lfc operapluginwrapper-native`
            if [[ $flash_process -ge 1 ]];then
                log "isAppRunning(): opera flash fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect html5 fullscreen on Opera, modify variable chrome_html5_detection if you dont want Opera html5 detection.
    if [ $opera_html5_detection == 1 ];then
        if [[ "$activ_win_title" = *opera* ]];then
        # Check if Opera html5 process is running
            opera_process=`pgrep -lfc "opera"`
            if [[ $opera_process -ge 1 ]];then
                log "isAppRunning(): opera html5 fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect html5 fullscreen on Epiphany, modify variable epiphany_html5_detection if you dont want Epiphany html5 detection.
    if [ $epiphany_html5_detection == 1 ];then
        if [[ "$activ_win_title" = *epiphany* ]];then
        # Check if Epiphany html5 process is running
            epiphany_process=`pgrep -lfc "epiphany"`
            if [[ $epiphany_process -ge 1 ]];then
                log "isAppRunning(): epiphany html5 fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect Video fullscreen on WebKit, modify variable webkit_flash_detection if you dont want Webkit detection
    if [ $webkit_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *WebKitPluginProcess* ]];then
        # Check if WebKit Flash process is running
            flash_process=`pgrep -lfc ".*WebKitPluginProcess.*flashp.*"`
            if [[ $flash_process -ge 1 ]];then
                log "isAppRunning(): webkit flash fullscreen detected"
                return 1
            fi
        fi
    fi

    #check if user want to detect mplayer fullscreen, modify variable mplayer_detection
    if [ $mplayer_detection == 1 ];then
        if [[ "$activ_win_title" = *mplayer* || "$activ_win_title" = *MPlayer* ]];then
            #check if mplayer is running.
            #mplayer_process=`pgrep -l mplayer | grep -wc mplayer`
            mplayer_process=`pgrep -lc mplayer`
            if [ $mplayer_process -ge 1 ]; then
                log "isAppRunning(): mplayer fullscreen detected"
                return 1
            fi
        fi
    fi

    #check if user want to detect mpv fullscreen, modify variable mpv_detection
    if [ $mpv_detection == 1 ];then
        if [[ "$activ_win_title" = *mpv* ]];then
            #check if mpv is running.
            #mpv_process=`pgrep -l mpv | grep -wc mpv`
            mpv_process=`pgrep -lc mpv`
            if [ $mpv_process -ge 1 ]; then
                log "isAppRunning(): mpv fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect vlc fullscreen, modify variable vlc_detection
    if [ $vlc_detection == 1 ];then
        if [[ "$activ_win_title" = *vlc* ]];then
            #check if vlc is running.
            #vlc_process=`pgrep -l vlc | grep -wc vlc`
            vlc_process=`pgrep -lc vlc`
            if [ $vlc_process -ge 1 ]; then
                log "isAppRunning(): vlc fullscreen detected"
                return 1
            fi
        fi
    fi

    # Check if user want to detect minitube fullscreen, modify variable minitube_detection
    if [ $minitube_detection == 1 ];then
        if [[ "$activ_win_title" = *minitube* ]];then
            #check if minitube is running.
            #minitube_process=`pgrep -l minitube | grep -wc minitube`
            minitube_process=`pgrep -lc minitube`
            if [ $minitube_process -ge 1 ]; then
                log "isAppRunning(): minitube fullscreen detected"
                return 1
            fi
        fi
    fi

return 0
}


delayScreensaver()
{
    # reset inactivity time counter so screensaver is not started
    if [ "$screensaver" == "xscreensaver" ]; then
        log "delayScreensaver(): delaying xscreensaver..."
        xscreensaver-command -deactivate > /dev/null
    elif [ "$screensaver" == "kscreensaver" ]; then
        log "delayScreensaver(): delaying kscreensaver..."
        qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity > /dev/null
    elif [ "$screensaver" == "xautolock" ]; then
        log "delayScreensaver(): delaying xautolock..."
        xautolock -disable
        xautolock -enable
    else
        log "delayScreensaver(): delaying org.gnome.ScreenSaver or anything else..."
        dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call /org/gnome/ScreenSaver org.gnome.ScreenSaver.SimulateUserActivity
        if [ -f /usr/bin/xdg-screensaver ]; then
            log "delayScreensaver(): trying to delay with xdg-screensaver..."
            xdg-screensaver reset
        fi
        if [ -f /usr/bin/xdotool ]; then
            log "delayScreensaver(): trying to delay with xdotool..."
            xdotool key ctrl
        fi
    fi

    #Check if DPMS is on. If it is, deactivate. If it is not, do nothing.
    dpmsStatus=`xset -q | grep -ce 'DPMS is Enabled'`
    if [ $dpmsStatus == 1 ];then
        xset -dpms
        # moved to checkFullscreen().
        #xset dpms
    fi
}

_sleep()
{
    if [ $dynamicDelay -eq 0 ]; then
        log "sleeping for $delay"
        sleep $delay
    else
        if [ -f /sys/class/power_supply/AC/online ]; then
            if [ "$(cat /sys/class/power_supply/AC/online)" == "1" ]; then
                system_sleep_delay=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-display-ac 2>/dev/null)
            else
                system_sleep_delay=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-display-battery 2>/dev/null)
            fi
        fi
        if [ "$(echo $system_sleep_delay | egrep -c "^[0-9]+$")" == "1" ]; then
            if [ $system_sleep_delay -le $(($default_sleep_delay+5)) ]; then
                sleep_delay=$default_sleep_delay
            else
                sleep_delay=$(($system_sleep_delay-5))
            fi
        else
            sleep_delay=$default_sleep_delay
        fi
        log "sleeping for $sleep_delay (system idle timeout is $system_sleep_delay)"
        sleep $sleep_delay
    fi
}

delay=$1
dynamicDelay=0

# If argument empty, use dynamic delay.
if [ -z "$1" ];then
    dynamicDelay=1
    log "no delay specified, dynamicDelay=1"
fi

# If argument is not integer quit.
if [[ $1 = *[^0-9]* ]]; then
    echo "The Argument \"$1\" is not valid, not an integer"
    echo "Please use the time in seconds you want the checks to repeat."
    echo "You want it to be ~10 seconds less than the time it takes your screensaver or DPMS to activate"
    exit 1
fi

while true
do
    checkDelayProgs
    checkFullscreen
    _sleep $delay
done

exit 0
