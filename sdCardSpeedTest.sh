#!/bin/bash
#
# COMMENTS:
#   A very handy script to measure the read/write BW of the sd-card
# (internal/external) of your android phone.
#
# USAGE:
#  sdCardSpeedTest.sh <sdCardLocation>
#   <sdCardLocation>    The location where your sdcard can be found
#                       in your phone. Eg: /mnt/sdcard
#



function fatal() {
    local msg=$1
    echo "**FATAL** $msg"
    exit 1
}


function bwTest() {
    local cacheFile=$1
    local numTests=$2
    local blkSize=$3
    local blkCnt=$4
    local IF=$5
    local OF=$6
    # disable caching
    echo "echo 1 > $cacheFile"
    # actual test
    for i in `seq 1 $numTests`; do
        echo "dd if=$IF of=$OF bs=$blkSize count=$blkCnt 2>&1 | grep bytes"
    done
    # restore original cache value
    echo "echo 0 > $cacheFile"
}

function runBwTest() {
    local pcScript=$1
    local adbScript=$2
    local log=$3
    $ADB push $pcScript $adbScript &>/dev/null
    $ADB shell chmod +x $adbScript
    $ADB shell $adbScript | tee $log
}

function evalBW() {
    local log=$1
    sed -e 's/(//' $log | awk 'BEGIN{bw=0;num=0} {bw+=$7;num++} END{print bw/1048576/num " MBps"}'
}

function clean() {
    local adbFiles=$1
    local pcFiles=$2
    $ADB shell rm $adbFiles
    rm $pcFiles
}




### MAIN SCRIPT ###
export PATH=.:$PATH
# constants
OS_TYPE=`uname -o`
if [ "$OS_TYPE" = "GNU/Linux" ]; then
    ADB=./adb-linux
elif [ "$OS_TYPE" = "Cygwin" ]; then
    ADB=./adb-windows.exe
else
    fatal "Currently, this script is supported only for 'Linux' and 'Cygwin'!"
fi
CACHE=/proc/sys/vm/drop_caches
BLK_SIZ=100000
BLK_CNT=1000
NUM_RUNS=6
WR_SCRIPT=sd-wr-speed.sh
WR_TST_SH=/data/local/sd-wr-speed.sh
WR_LOG=sd-wr-speed.log
RD_SCRIPT=sd-rd-speed.sh
RD_TST_SH=/data/local/sd-rd-speed.sh
RD_LOG=sd-rd-speed.log

# user inputs and derivatives
sdcard=$1
if [ "$sdcard" = "" ]; then
    fatal "USAGE: ./sdCardSpeedTest.sh <sdcardLocation>"
fi
TST_FILE=$sdcard/empty.file


# caution
echo "NOTE: Test might take about 5-10 min depending on your sd-card speed!"
echo "      Please be patient during this time..."
echo



# write test
echo "Evaluating write-BW..."
bwTest $CACHE $NUM_RUNS $BLK_SIZ $BLK_CNT /dev/zero $TST_FILE > $WR_SCRIPT
runBwTest $WR_SCRIPT $WR_TST_SH $WR_LOG
echo -n "Write BandWidth: "
evalBW $WR_LOG
echo

# read test
echo "Evaluating read-BW..."
bwTest $CACHE $NUM_RUNS $BLK_SIZ $BLK_CNT $TST_FILE /dev/null > $RD_SCRIPT
runBwTest $RD_SCRIPT $RD_TST_SH $RD_LOG
echo -n "Read BandWidth: "
evalBW $RD_LOG
echo

# clean-up
echo "Cleaning up all the temporary files..."
clean "$WR_TST_SH $RD_TST_SH $TST_FILE" "$WR_SCRIPT $RD_SCRIPT $WR_LOG $RD_LOG"
