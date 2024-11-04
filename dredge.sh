#!/bin/bash
# Preamble 
NOCOLOR=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
DIV="------------------------------------------------------------------"
TICK="[$GREEN+$NOCOLOR] "
TICK_INPUT="$NOCOLOR[$YELLOW!$NOCOLOR] "
TICK_MOVE="[$GREEN~>$NOCOLOR]"
TICK_ERROR="$NOCOLOR[$RED!$NOCOLOR] "
SCRIPT_DIR="$(dirname "$0")"
WORDLIST=$(cat "${SCRIPT_DIR}/net.txt")

# ASCII art modified from: https://ascii.co.uk/art/fishing 
# and https://www.asciiart.eu/vehicles/boats
echo -e $BLUE"

            ____            _         
            |    \ ___ ___ _| |___ ___ 
            |  |  |  _| -_| . | . | -_|
            |____/|_| |___|___|_  |___|
                              |___|    
           __            
           \ \___     .__ 
         .-''''___\..--'/ 
     .__.|-'''''.... ' / 
     |\_______________/_
~^~^~|~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^
     |
     |                                         $GREEN}-<#(\'c $BLUE
     |
     |
     | $GREEN                   }-<#(\'c                           <\')\"={$BLUE
     |
     |      $GREEN><>                        <\')\"={$BLUE
     |                                                $GREEN<><$BLUE
     |        $GREEN     }<(\'>             }<(\'>$BLUE
     J$GREEN<53CR3T5>{$BLUE



------------------------------------------------------------------------
$GREEN          Dredging up secrets from the depths of the file system...$NOCOLOR
"

dependency_check(){
if ! which grep find xargs sed mkdir cut &>/dev/null; then
    echo $TICK_ERROR "Error: System does not have required utilities..."
    echo $TICK_ERROR "Ensure the following utilities are on the system and in your path:"
    echo $TICK_ERROR "grep, find, xargs, sed, mkdir, cut"
    exit 1
fi
}

if ! test -d ./logs/; then
    LOG_LOCATION=./logs/logs_baseline/
    echo -e $TICK"Detected first time run!" $NOCOLOR
    mkdir -p $LOG_LOCATION 
    first_run=true
else
    LOG_LOCATION=./logs/logs_new/
    first_run=false
    mkdir -p ./logs/logs_new/
fi

dependency_check

# Initiates the search process. This will find all instanes of each word in $WORDLIST and log them to the ./logs directory
find_scary(){
	echo -e $TICK"Wordlist loaded!$NOCOLOR"
    for i in $WORDLIST
    do
        grep_term=$i
	echo -n $TICK"$(date +%H:%M) - Starting search for $BLUE$grep_term$NOCOLOR: "$NOCOLOR
	# Behold, the worlds most cursed search pipeline
        find $location -type f -not -path "*/dredge/*" -not -name "*.html" -not -name "*.png" -not -name "*.jpg" -not -name "*.js" -not -name "*.css" -not -type d -print0 2>/dev/null | xargs -0 grep -A1 -D skip  -P  -I "$grep_term" --color=always 2>/dev/null | grep -A1 $grep_term| cut -b 1-400 > ./"$LOG_LOCATION"/"$grep_term".log

        if [ ! -s  "./"$LOG_LOCATION"/"$grep_term".log" ]; then
            rm "$LOG_LOCATION$grep_term".log
            echo ""
        else 
            word_count=$(cat ./"$LOG_LOCATION"/"$grep_term".log | grep "$grep_term" | wc -l)
	    echo -n $RED"FOUND ($word_count)"$NOCOLOR
            echo " Logged to $GREEN$LOG_LOCATION"$NOCOLOR
        fi
    done

}

# Rotates logs from ./logs/logs_baseline to ./logs/logs_baseline/
# This will overwrite your baseline log files!
log_rotate(){
    if ! $first_run; then
        echo -e $TICK$BLUE"Rotating logs.$GREEN logs_new$BLUE will be converted to$GREEN logs_baseline" $NOCOLOR
        mv ./logs/logs_new/* ./logs/logs_baseline/
        echo -e $TICK$BLUE"Logs rotated. Exiting..." $NOCOLOR
        exit 0
    fi
}

# Finds kubeconfig files around the system and puts them in ./kubeconfigs/ for futher processing
# Dredge marks each config file pulled with the directory where it came from with # DREDGE
find_kubeconfig(){
    if ! test -d ./kubeconfigs/; then
        KUBE_LOCATION=./kubeconfigs/
        echo -e $TICK"Detected first time running kubernetes module. Creating kubeconfig directory$GREEN $KUBE_LOCATION" $NOCOLOR
        mkdir -p $KUBE_LOCATION 
    else 
        KUBE_LOCATION=./kubeconfigs/
    fi
    echo  $TICK"$(date +%H:%M) - Starting search for kubeconfig files. Any files located will be copied to $GREEN$KUBE_LOCATION "$NOCOLOR
	# Behold, the worlds second most cursed search pipeline
	k8s=$(find $location -type f -not -path "*/dredge/*" -not -name "*.html" -not -name "*.png" -not -name "*.jpg" -not -name "*.js" -not -name "*.css" -not -type d -print0 2>/dev/null| xargs -0 grep -Iil "kind: config$" --color=never 2>/dev/null)
	if [[ -z $k8s ]];then
		echo $TICK"No kubeconfig files found in $location"
	else
	    while IFS= read -r line
	        do
            	    echo $TICK$RED"Kubeconfig Found at: $GREEN$line" $NOCOLOR
		    k8s_fixed=$(echo "line: \"$line\"")
            	    kube_filename=$(echo "$line" | awk -F'/' '{print $NF}')
            	    cp "$line" $KUBE_LOCATION
            	    sed -i "1s|^|# DREDGE: kubeconfig found in '$line'\n|" $KUBE_LOCATION/"$kube_filename"
	    done <<< "$k8s"
	fi
}


# Ensure the location is set first. 
while getopts ":l:" flag
do
  case "${flag}" in
    l) location=${OPTARG}
       ;;

  esac
done

OPTIND=1

# Handle the rest of the arguments 
while getopts "k s r :l:" flag
do
    case "${flag}" in
    l) location=${OPTARG}
       ;;
    r) r=${OPTARG}
    log_rotate
    ;;
    k) k=${OPTARG}
    find_kubeconfig $location
    ;;
    s) s=${OPTARG}
    echo $TICK"Location to start scan from: $GREEN$location" $NOCOLOR
    find_scary 
    ;;
    esac
done
