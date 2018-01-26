#!/bin/bash

#title       :anomaly_detection.sh [seconds] [max_cpu_load] [max_memory] [max_network]
#description :Collects various data via SNMP and notifies anomalies via sendmail.
#author      :Stephen Cathcart
#date        :20171111

clear

# Readonly Variables
readonly tick=5
readonly timestamp=`date "+%Y%m%d-%H%M%S"`
readonly cpu_load_file="./data/${timestamp}_cpu_load.txt"
readonly cpu_utilisation_file="./data/${timestamp}_cpu_utilisation.txt"
readonly memory_usage_file="./data/${timestamp}_memory_usage.txt"
readonly bandwidth_in_usage_file="./data/${timestamp}_bandwidth_in_usage.txt"
readonly system_email="example@company.com"
readonly admin_email="example@newcastle.ac.uk"

# Bandwidth Variables
previous_if_in_octets=""
previous_bandwidth_walk=0

# Warning Variables
has_sent_cpu_email=false
has_sent_memory_email=false
has_sent_network_email=false

# Get CPU load via laload SNMP call
# Arguments
#   Warning limit
function get_cpu_load {
  local cpu_load=`snmpwalk -v 2c -c allInfo -Oqv 17dcompv008 UCD-SNMP-MIB::laLoad.1`
  echo $cpu_load >> $cpu_load_file
  printf "CPU Load %%: %.2f" $cpu_load
  # Send waring email if limit is hit
  if [ $(bc -l <<< "$cpu_load > $1") -eq 1 ]; then
    if [ "$has_sent_cpu_email" = false ]; then
      send_email "Anomaly detected: CPU load" "CPU load currently at $cpu_load"
      has_sent_cpu_email=true
    fi
  else
    has_sent_cpu_email=false
  fi
}

# Get CPU utilisation via processor SNMP call
function get_cpu_utilisation {
  local cpu_utilisation=`snmpwalk -v 2c -c allInfo -Oqv 17dcompv008 HOST-RESOURCES-MIB::hrProcessorLoad`
  echo $cpu_utilisation >> $cpu_utilisation_file
  printf ", CPU Utilisation %%: %.2f" $cpu_utilisation
}

# Get memory usage via storage SNMP calls
# Arguments
#   Warning limit
function get_memory_usage {
  local memTotalReal=`snmpwalk -v 2c -c allInfo -OqUv 17dcompv008 UCD-SNMP-MIB::memTotalReal.0`
  local memAvailReal=`snmpwalk -v 2c -c allInfo -OqUv 17dcompv008 UCD-SNMP-MIB::memAvailReal.0`
  local memBuffer=`snmpwalk -v 2c -c allInfo -OqUv 17dcompv008 UCD-SNMP-MIB::memBuffer.0`
  local memCached=`snmpwalk -v 2c -c allInfo -OqUv 17dcompv008 UCD-SNMP-MIB::memCached.0`
  
  local memRealUsed=$(bc -l <<< "$memTotalReal - $memAvailReal")
  local percentage=$(bc -l <<< "(($memRealUsed - $memBuffer - $memCached) / $memTotalReal) * 100")

  echo $percentage >> $memory_usage_file
  printf ", Memory %%: %.2f" $percentage
  # Send waring email if limit is hit
  if [ $(bc -l <<< "$percentage > $1") -eq 1 ]; then
    if [ "$has_sent_memory_email" = false ]; then
      send_email "Anomaly detected: Memory usage" "Memory usage currently at $percentage"
      has_sent_memory_email=true
    fi
  else
    has_sent_memory_email=false
  fi
}

# Get bandwidth in usage from the embedded Network Interface Card via SNMP calls
# Arguments
#   Warning limit
function get_bandwidth_in_usage {
  local if_in_octets=`snmpwalk -v 2c -c allInfo -Oqv 17dcompv008 ifInOctets.2`
  local if_speed=`snmpwalk -v 2c -c allInfo -Oqv 17dcompv008 ifSpeed.2`

  if [ -n "$previous_if_in_octets" ]; then
    local poll_period=$(bc -l <<< "$SECONDS - $previous_bandwidth_walk")
    local octets_difference=$(bc -l <<< "$if_in_octets - $previous_if_in_octets")
    local octets=$(bc -l <<< "$octets_difference * 8 * 100")
    local bps=$(bc -l <<< "$octets / ($poll_period * $if_speed)")
    local percentage=$(bc -l <<< "$bps * 100")
    echo $percentage >> $bandwidth_in_usage_file
    printf ", Bandwidth In %%: %.2f" $percentage
    # Send waring email if limit is hit
    if [ $(bc -l <<< "$percentage > $1") -eq 1 ]; then
      if [ "$has_sent_network_email" = false ]; then
        send_email "Anomaly detected: Bandwidth usage" "Bandwidth usage currently at $percentage"
        has_sent_network_email=true
      fi
    else
      has_sent_network_email=false
    fi
  fi
  previous_if_in_octets=$if_in_octets
  previous_bandwidth_walk=$SECONDS
}

# Send an email
# Arguments
#   Subject
#   Body
function send_email {
  (
    echo "From: $admin_email";
    echo "To: $admin_email";
    echo "Subject: $1";
    echo $2 ". Detected time " `date "+%Y%m%d-%H%M%S"`
  ) | sendmail -t
}

# Main script
if [ $# -ne 4 ]; then
  echo "Required args [seconds] [max_cpu_load] [max_memory] [max_network]"
  exit 1 # Exit with error code
else
  # Set duration of script
  readonly duration=$((SECONDS + $1))
  echo "Accessing MIB data every $tick seconds over $1 seconds"
  echo "CPU load data location: $cpu_load_file"
  echo "CPU utilisation data location: $cpu_utilisation_file"
  echo "Memory data location: $memory_usage_file"
  echo "Bandwidth In data location: $bandwidth_in_usage_file"
  echo "Warning limits [ CPU load: $2, Memory usage: $3, Network usage: $4 ]"
  mkdir -p data
  while [ $SECONDS -lt $duration ]; do
    # Get SNMP data once every tick
    if (( $SECONDS % $tick == 0)); then
      printf "Seconds: %s, " $SECONDS
      get_cpu_load $2
      get_cpu_utilisation
      get_memory_usage $3
      get_bandwidth_in_usage $4
      printf "\n"
      sleep $tick
    fi
  done
fi

echo "End"

exit 0 # Exit successful
