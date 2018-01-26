#!/bin/bash

#title       :cpu_load.sh [seconds]
#description :Collects cpu load data via SNMP.
#author      :Stephen Cathcart
#date        :20171110

clear

# Variables
readonly tick=5
readonly timestamp=`date "+%Y%m%d-%H%M%S"`
readonly cpu_load_file="./data/${timestamp}_cpu_load.txt"

# Get CPU load via laload SNMP call
function get_cpu_load {
  local cpu_load=`snmpwalk -v 2c -c allInfo -Oqv 17dcompv008 UCD-SNMP-MIB::laLoad.1`
  echo "Tick: " $SECONDS ", CPU Load: " $cpu_load
  echo $cpu_load >> $cpu_load_file
}

# Main script
if [ $# -ne 1 ]; then
  echo "Required args [seconds]"
  exit 1 # Exit with error code
else
  # Set duration of script
  readonly duration=$((SECONDS + $1))
  echo "Accessing MIB data every $tick seconds over $1 seconds"
  echo "CPU load data location: $cpu_load_file"
  mkdir -p data
  while [ $SECONDS -lt $duration ]; do
    # Get SNMP data once every every tick
    if (( $SECONDS % $tick == 0)); then
      get_cpu_load
      sleep $tick
    fi
  done
fi

echo "End"

exit 0 # Exit successful
