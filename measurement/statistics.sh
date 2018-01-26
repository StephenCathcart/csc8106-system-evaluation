#!/bin/bash

#title       :statistics.sh [file] [cp95] [cp99]
#description :Calculate various statistics for measurements.
#author      :Stephen Cathcart
#date        :20171109

clear

# Variables
measurements=()
mean=0
variance=0
standard_deviationd=0
confidence_interval_95=""
confidence_interval_99=""

# Read measurements from file
# Arguments:
#   File
function read_measurements {
  local i=0
  while read line; do
    measurements[$i]="$line"
    let i++
  done < $1
}

# Calculate the mean
function mean {
  for measurement in ${measurements[@]}; do
    mean=$(bc -l <<< "$mean + $measurement")
  done
  mean=$(bc -l <<< "$mean / ${#measurements[@]}")
}

# Calculate the variance
function variance {
  for measurement in ${measurements[@]}; do
    variance=$(bc -l <<< "$variance + ($measurement - $mean)^2")
  done
  variance=$(bc -l <<< "$variance / (${#measurements[@]} - 1)")
}

# Calculate the standard deviation
function standard_deviation {
  standard_deviation=$(bc -l <<< "sqrt($variance)")
}

# Calculate the confidence interval with given Cp
# Arguments:
#   Cp
function confidence_interval {
  local temp=$(bc -l <<< "($1 * $standard_deviation) / sqrt(${#measurements[@]})")
  local confidence_interval_lower=$(bc -l <<< "$mean - $temp")
  local confidence_interval_upper=$(bc -l <<< "$mean + $temp")
  confidence_interval=$(printf "[%.2f, %.2f]" $confidence_interval_lower $confidence_interval_upper)
}

# Main script
if [ $# -ne 3 ]; then
  echo "Required args [file] [cp95] [cp99]"
  exit 1 # Exit with error code
else
  read_measurements $1
  mean
  variance
  standard_deviation
  confidence_interval $2
  confidence_interval_95=$confidence_interval
  confidence_interval $3
  confidence_interval_99=$confidence_interval
fi

# Console outputs
printf "Measurements #: %s\n" ${#measurements[@]}
printf "Mean: %.2f\n" $mean
printf "Variance: %.2f\n" $variance
printf "Standard deviation: %.2f\n" $standard_deviation
printf "95%% confidence interval: %s\n" "$confidence_interval_95"
printf "99%% confidence interval: %s\n" "$confidence_interval_99"

exit 0 # Exit successful
