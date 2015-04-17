#!/bin/bash
# -*- coding: UTF8 -*-
# ---------------------------------------------
# @author:  Guillaume Seren
# @since:   14/04/2015
# source:   https://github.com/GuillaumeSeren/videoEncoder
# file:     videoEncoder.sh
# Licence:  GPLv3
#
# This script wrap-up some of my preset to easy encode HTML5 video,
# using avconv.
# ---------------------------------------------

# Error Codes {{{1
# 0 - Ok
# 1 - Error in cmd / options.
# 2 - Missing dependencies.

# Default variables {{{1
# DEPENDENCIES
dependencies='avconv bc'
# Flags :
flag_getOpts=false
# Video source
filename=false
# By default we use the filename to the html5 video
aVideoFormat='webm m4v ogv'
# To change size
sVideoSize=false
# To cut
iVideoLength=false
# Snapshot
iVideoSnapshot=false
# Default demo length
iVideoLengthDemo=false
iVideoLengthDemoDefault=4
# Wana specify bitrate
sVideoBitrate=false
# videoMode : demo / full / demo+full
sVideoMode='demo+full'
# How to spell the demo / full in filename
sFull="full"
sDemo="demo"
sPoster="poster"
# Watermark setting
flag_watermark=false
sWatermark=false
sWatermarkMsg=false
sWatermarkMsgArg=false
# Concurrent level
iThreadConcurrent=false
sThreadConcurrent=false
sThreadConcurrentDefault='auto'
# BitRate
sBitrate=false
# var :
NOW=$(date +"%Y-%m-%d")
# Set to something efficient :
# 2014/06/14-53aad53c
# AAAA/MM/DD-Timestamp converted to hex
NOW="${NOW}-$(printf '%x\n' "$(date +"%s")")"
# Demo / Full
sTypeFull='full'
sTypeDemo='demo'
# We NEED a param the codec
sCodecWebm='webm'
sCodecM4v='m4v'
sCodecOgv='ogv'
# Log path
logPath=$(pwd)
# Log file
logFile="${logPath}/videoEncoder.log"

# FUNCTION USAGE() {{{1
# Return the help.
function usage()
{
cat << DOC

usage: $0 options

This script manage the encoding process, using avconv.
By default (see options below) this script will encode a given video,
to the HTML5 format.


OPTIONS:
    -> Required Param :
        -f  Filename. (no path allowed)
    -> Additionnal Param :
        -h  Show this message.
        -V  Activate verbose mode.
        -d  Size of the video output, ex '1980x1080'.
        -t  Length of the video in second.
        -s  Snapshot time.
        -b  Set the given value to constant bitrate.
        -w  Watermark default is 'name-mode-codec'.
        -W  Watermark text require (-w flag).
        -c  Set concurrent threads level:
            0        : auto (Default).
            1-99     : Range allowed.
        -m  Set a specific mode :
            demo     : demo (3s)
            full     : full (Default)
            demo+full: demo + full

Sample clean:
    $0 -f movie.avi

Sample dirty:
    $0 -f small.mp4 -d '1980x1080' -s 3:6.438000 -t 60 -w 'HTML5' -c 64
DOC
}
#------------------------------------------------

# FUNCTION createlogFile() {{{1
function getCreateLogFile() {
    # Touch the file
    if [ ! -f "$logFile" ]; then
        earlyLog="Creation log file: $logFile"
        touch "$logFile"
    fi
    # If the file is still no variable
    if [ ! -w "$logFile" ]; then
        echo "The log file is not writeable, please check permissions."
        exit 2
    fi
    echo "$earlyLog"
}
# FUNCTION addLog() {{{1
function addLog() {
    dateNow="$(date +"%Y%m%d-%H:%M:%S")"
    # We need to check if the file is available
    if [[ ! -w "$logFile" ]]; then
        earlyLog="$(createLogFile)"
    fi
    # Do we have some early log to catch
    if [[ -n "$earlyLog" && "$earlyLog" != "" ]]; then
        echo "$dateNow $idScriptCall $earlyLog" >> "$logFile" 2>&1
        # Clear earlyLog after displaying it
        unset earlyLog
    fi
    # test if it is writeable
    # Export the create / open / check file outside
    if [[ -n "$1" && "$1" != "" ]]; then
        echo "$dateNow $idScriptCall $1" >> "$logFile" 2>&1
    fi
}

# FUNCTION checkDependencies() {{{1
# Test if needed dependencies are available.
function checkDependencies()
{
    deps_ok='YES'
    for dep in $1
    do
        if  ! which "$dep" &>/dev/null;  then
            echo "This script requires "$dep" to run but it is not installed"
            deps_ok='NO'
        fi
    done
    if [[ "$deps_ok" == "NO" ]]; then
        echo "This script need : $1"
        echo "Please install them, before using this script !"
        exit 2
    else
        return 0
    fi
}

# FUNCTION getName() {{{1
# Return the filename without extension
function getName
{
    # if not empty
    if [[ -n "$1" ]]; then
        # Try to cut the name with regex
        if [[ "$1" =~ ^(.*+)\.(.*+)$ ]]; then
            local name=${BASH_REMATCH[1]}
            echo $name
        fi
    fi
}

# FUNCTION getTimeHuman() {{{1
# Return second to human readable format.
function getTimeHuman
{
    # If a param is given we just encode to this default timing
    # Do not mess with 0 sec video length
    if [[ -n "$1" && "$1" != "false" && $1 =~ ^[0-9]+.?[0-9]+? ]]; then
        # The input is in sec.micro
        # We may not need days
        # We just count the sec
        local hour=$(echo "($1 / 3600) " | bc)
        local minut=$(echo "($1 / 60) - ($hour * 60)" | bc)
        local second=$(echo "($1 - ($minut * 60) - ($hour * 3600))" | bc)
        local timeHuman=$hour":"$minut:$second
    else
        # If the param given is not decimal take default
        local timeHuman=$iVideoLengthDemoDefault
    fi
    echo $timeHuman
}

# FUNCTION setWatermark() {{{1
# Set the watermark to add in the video.
function setWatermark
{
    if [[ -n "$sWatermarkMsgArg" && "$sWatermarkMsgArg" != "false" ]]; then
        # If user ask for a watermark
        local sWatermarkMsg="$sWatermarkMsgArg"
    else
        local sWatermarkMsg="$2-$3-$4"
    fi
    if [[ -n "$1" && "$1" != "false" ]]; then
        local sWatermark="-vf drawtext=fontfile='/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf':"
        local sWatermark=$sWatermark"text=$sWatermarkMsg:x=(main_w-text_w)/2:y=(main_h-text_h)/2:"
        local sWatermark=$sWatermark"fontsize=30:box=1:boxcolor=black@0.4:fontcolor=white"
    else
        local sWatermark=''
    fi
    echo "$sWatermark"
}

# FUNCTION setVideoDuration() {{{1
function setVideoDuration
{
    # You need the filename
    local fVideoDuration=$(avprobe -show_format -v quiet "$1" | sed -n 's/duration=//p')
    # Add A 0 behind
    local fVideoDuration=$(getTimeHuman "$fVideoDuration")
    echo "$fVideoDuration"
}

# FUNCTION setSize() {{{1
function setSize
{
    # If a param is given we just encode to this default size
    if [[ -n "$1" && "$1" != "false" ]]; then
        local sVideoSize="-s $1"
    else
        local sVideoSize=""
    fi
    echo "$sVideoSize"
}

# FUNCTION setLenght() {{{1
function setLength
{
    # If a param is given we just encode to this default length
    if [[ -n "$1" && "$1" != "false" ]]; then
        local sVideoLength="-t $1"
    else
        local sVideoLength="-t $iVideoLengthDemoDefault"
    fi
    echo "$sVideoLength"
}

# FUNCTION setSnapshotTime() {{{1
function setSnapshotTime
{
    # If a param is given we just encode to this default length
    # Add conversion to a 00:00:00.000 format
    if [[ -n "$1" && "$1" != "false" ]]; then
        local sSnapshotTime="-ss $1"
    else
        local sSnapshotTime="-ss $iVideoLengthDemoDefault"
    fi
    echo "$sSnapshotTime"
}

# FUNCTION setMode() {{{1
function setMode
{
    # If a param is not given we just encode to this default mode demo+full
    # We need to validate that the mode is ok
    if [[ -n "$1" && "$1" != "false" ]]; then
        local sVideoMode="$1"
    else
        # The mode is unknown exit now !
        echo "The mode $1 is unknown"
        exit 3
    fi
    echo "$sVideoMode"
}

# FUNCTION setBitrate() {{{1
function setBitrate
{
    # If a param is given we just encode to this default bitrate
    if [[ -n "$1" && "$1" != "false" ]]; then
        local sVideoBitrate="-b:v $1"
    else
        local sVideoBitrate=""
    fi
    echo "$sVideoBitrate"
}

# FUNCTION setPoster() {{{1
function setPoster
{
    # Warning the default size may be after the end
    local sPosterPng="avconv -i $filename $sSnapshotTime -f image2 -vframes 1 $namePoster.png"
    echo "$sPosterPng"
}

# FUNCTION setThreads() {{{1
# Detect the amount of threads
function setThreads
{
    if [[ -n "$1" && "$1" != "false" && "$1" =~ ^[0-9][0-9]? && "$1" != "0" && "$1" -le "99" ]]; then
        sVideoThreads="-threads $1"
    else
        sVideoThreads="-threads $sThreadConcurrentDefault"
    fi
    echo "$sVideoThreads"
}

# FUNCTION setCodecArgs() {{{1
function setCodecArgs
{
    if [[ "$1" == "$sCodecWebm" ]]; then
        sCodecWebmVideo='-vcodec libvpx'
        sCodecWebmAudio='-acodec libvorbis'
        sCodecArg="$sCodecWebmVideo $sCodecWebmAudio"
    elif [[ "$1" == "$sCodecM4v" ]]; then
        # http://www.cyberciti.biz/faq/linux-convert-avi-file-to-apple-ipod-iphone-mp4-m4v-format/
        # New encoder param support watermark !
        sCodecM4vVideo='-vcodec mpeg4'
        sCodecM4vAudio='-acodec aac -strict experimental'
        sCodecArg="$sCodecM4vVideo $sCodecM4vAudio"
    elif [[ "$1" == "$sCodecOgv" ]]; then
        sCodecOgvVideo='-vcodec libtheora'
        sCodecOgvAudio='-acodec libvorbis'
        sCodecArg="$sCodecOgvVideo $sCodecOgvAudio"
    fi
    echo "$sCodecArg"
}

# FUNCITON setVideoArgs() {{{1
function setVideoArgs
{
    # $1: name
    # $2: type
    # $3: codec
    # ------------------------------------------------
    if [[ "$2" == "$sTypeFull" ]]; then
        # move to setVideoArgs
        sVideoArgs="$1 $sBitrate $sThreadConcurrent $sVideoSize $sWatermark"
    elif [[ "$2" == "$sTypeDemo" ]]; then
        # also setvideoargs switch on type (demo / full / poster)
        sVideoArgs="$1 $sThreadConcurrent $sVideoSize $sWatermark $sVideoLength"
    fi
    echo "$sVideoArgs"
}

# FUNCTION setEncoder() {{{1
function setEncoder
{
    if [[ "$1" == "$sCodecWebm" ]]; then
        #@TODO: Refactor this process in a external function.
        sCodecArg=$(     setCodecArgs "$sCodecWebm")
        sWatermark=$(    setWatermark "${flag_watermark}" "${name}"      "${sTypeFull}" "${sCodecWebm}")
        sVideoArgs=$(    setVideoArgs "${filename}"       "${sTypeFull}" "${sCodecWebm}")
        sWatermark=$(    setWatermark "${flag_watermark}" "${name}"      "${sTypeDemo}" "${sCodecWebm}")
        sVideoArgsDemo=$(setVideoArgs "${filename}"       "${sTypeDemo}" "${sCodecWebm}")
        sEncodeWebm="    avconv -i    ${sVideoArgs}     ${sCodecArg} ${nameFull}.${sCodecWebm}"
        sEncodeWebmDemo="avconv -i    ${sVideoArgsDemo} ${sCodecArg} ${nameDemo}.${sCodecWebm}"
        echo "avconv call: $sEncodeWebm"
        $sEncodeWebm
        if [[ "$sVideoMode" == "demo" || "$sVideoMode" == "demo+full" ]]; then
            echo "avconv call: $sEncodeWebmDemo"
            $sEncodeWebmDemo
        fi

    elif [[ "$1" == "$sCodecM4v" ]]; then
        sCodecArg=$(     setCodecArgs "${sCodecM4v}")
        sWatermark=$(    setWatermark "${flag_watermark}" "${name}"      "${sTypeFull}" "${sCodecM4v}")
        sVideoArgs=$(    setVideoArgs "${filename}"       "${sTypeFull}" "${sCodecM4v}")
        sWatermark=$(    setWatermark "${flag_watermark}" "${name}"      "${sTypeDemo}" "${sCodecM4v}")
        sVideoArgsDemo=$(setVideoArgs "${filename}"       "${sTypeDemo}" "${sCodecM4v}")
        sEncodeM4v="     avconv -i    ${sVideoArgs}     ${sCodecArg} ${nameFull}.${sCodecM4v}"
        sEncodeM4vDemo=" avconv -i    ${sVideoArgsDemo} ${sCodecArg} ${nameDemo}.${sCodecM4v}"
        echo "avconv call: $sEncodeM4v"
        $sEncodeM4v
        if [[ "$sVideoMode" == "demo" || "$sVideoMode" == "demo+full" ]]; then
            echo "avconv call: $sEncodeM4vDemo"
            $sEncodeM4vDemo
        fi
    elif [[ "$1" == "$sCodecOgv" ]]; then
        sCodecArg=$(     setCodecArgs "${sCodecOgv}")
        sWatermark=$(    setWatermark "${flag_watermark}" "${name}"      "${sTypeFull}" "${sCodecOgv}")
        sVideoArgs=$(    setVideoArgs "${filename}"       "${sTypeFull}" "${sCodecOgv}")
        sWatermark=$(    setWatermark "${flag_watermark}" "${name}"      "${sTypeDemo}" "${sCodecOgv}")
        sVideoArgsDemo=$(setVideoArgs "${filename}"       "${sTypeDemo}" "${sCodecOgv}")
        sEncodeOgv="     avconv -i    $sVideoArgs     $sCodecArg $nameFull.$sCodecOgv"
        sEncodeOgvDemo=" avconv -i    $sVideoArgsDemo $sCodecArg $nameDemo.$sCodecOgv"
        echo "avconv call: $sEncodeOgv"
        $sEncodeOgv
        if [[ "$sVideoMode" == "demo" || "$sVideoMode" == "demo+full" ]]; then
            echo "avconv call: $sEncodeOgvDemo"
            $sEncodeOgvDemo
        fi
    fi
}

# FUNCTION main() {{{1
# Centralize main process.
function main()
{
    # Use the PID:
    idScriptCall="$$"
    addLog "test log"
    addLog "test cmd $(ls ~/)"

    # Dependencies check
    checkDependencies "$dependencies"
    # Generate name
    name=$(getName "$filename")

    # Get the duration
    fVideoDuration=$(setVideoDuration "$filename")
    # iVideoLengthDemoDefault="$fVideoDuration"

    # Generate names for output files
    namePoster="${name}-${NOW}-${sPoster}"
    nameFull="${name}-${NOW}-${sFull}"
    nameDemo="${name}-${NOW}-${sDemo}"

    #@TODO: Maybe add a specific param for snapshot time
    #       now it is end of demo, would be better around 10%.
    sSnapshotTime=$(setSnapshotTime "$iVideoLength")
    # Video size
    sVideoSize=$(setSize "$sVideoSize")
    # Video Lenght
    sVideoLength=$(setLength "$iVideoLength")
    # Video Mode
    sVideoMode=$(setMode "$sVideoMode")
    # Video bitrate
    sBitrate=$(setBitrate "$sBitrate")
    # Thread number
    sThreadConcurrent=$(setThreads "$iThreadConcurrent")
    # Generate poster
    setPoster
    # Run loop
    for codec in $aVideoFormat
    do
       setEncoder "$codec"
    done
}

# GETOPTS {{{1
while getopts "f:m:t:s:d:c:b:W:wvh" OPTION
do
    # Set the getopts detection flag to true.
    flag_getOpts=true
    case $OPTION in
        h)
            # Do not panic user ask for help
            # Say him to RTFM ;)
            usage
            # Help is not an error
            exit 0
            ;;
        v)
            flag_verbose=true
            echo 'Verbose Mode activated'
            ;;
        f)
            filename=$OPTARG
            ;;
        d)
            sVideoSize=$OPTARG
            ;;
        t)
            iVideoLength=$OPTARG
            ;;
        s)
            iVideoSnapshot=$OPTARG
            ;;
        b)
            sBitrate=$OPTARG
            ;;
        w)
            flag_watermark=true
            ;;
        W)
            sWatermarkMsgArg=$OPTARG
            ;;
        c)
            iThreadConcurrent=$OPTARG
            ;;
        m)
            sVideoMode=$OPTARG
            ;;
    esac
done
# ERROR HANDLER :
if [[ $flag_getOpts != true ]]; then
    echo 'You have to give an argument !'
    usage
    exit 1
fi

# Launch the main process {{{1
main
