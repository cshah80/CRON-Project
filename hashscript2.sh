#!/bin/bash

# Define directories that have cron jobs
directories="/etc/cron.d:/etc/cron.hourly:/etc/cron.daily:/etc/cron.weekly:/etc/cron.monthly"

# directory where cron job hashes will be stored
HASH_DIRECTORY="/home/sysadmin/project4/crons/hashes"

# directory where cron job change alert files will be stored
CRON_ALERTS="/home/sysadmin/project4/crons/alerts"

# Create the hash and alert directories if they doesn't already exist
mkdir -p "$HASH_DIRECTORY"
mkdir -p "$CRON_ALERTS"

# Make file name with current date in name
current_date=$(date +"%Y-%m-%d")
current_hashes="CronJobHashes_${current_date}.txt"

# Define a filename for the file from the day before
previous_date=$(date -d "1 Day Ago" +"%Y-%m-%d")
previous_hashes="CronJobHashes_${previous_date}.txt"

# Define a file name for the file containing changes to hashes
change_alert="Cron_Alert_${current_date}.txt"

# Defining the path to the hash file with a date 1 day earlier
PREVIOUS_HASH_FILE="$HASH_DIRECTORY/$previous_hashes"

# Defining a path to the hash file with todays date
CURRENT_HASH_FILE="$HASH_DIRECTORY/$current_hashes"

# Defineing a path to the Alert file for changes in hashes
CHANGE_ALERT_FILE="$CRON_ALERTS/$change_alert"

# Delete existing current hash file to make room for new one
if [ -f "$CURRENT_HASH_FILE" ]; then
	rm "$CURRENT_HASH_FILE"
fi

# Generate the hash of all cron jobs in all cron directories
	IFS=':' read -ra dir_list <<< "$directories"
	for dir in "${dir_list[@]}"; do
		find "$dir" -type f -exec sha256sum {} \; | awk '{print $2, $1}' >> "$CURRENT_HASH_FILE"
	done

# Define output for any differences found in current and yesterdays hash file
diff_output=$(diff -u "$PREVIOUS_HASH_FILE" "$CURRENT_HASH_FILE")

# Split the hashes file into individual lines
IFS=$'\n' read -d '' -ra diff_lines <<< "$diff_output"

# Check if there is a change in the hashes from the day before
check_hash_change() {
    if [ -f "$PREVIOUS_HASH_FILE" ]; then
        diff -u "$PREVIOUS_HASH_FILE" "$CURRENT_HASH_FILE"
        if [ $? -eq 0 ]; then
            echo "No changes in cron job hashes."
	    echo "No Changes in Cron Jobs Detected" | mailx -s "Cron Jobs OK, Move Along" chiragshah2030@u.northwestern.edu
        else
           echo "Changes detected in cron job hashes!"
       		for line in "${diff_lines[@]}"; do
        		case $line in
	                ---*)   # File Header for first file
        	                echo "Yesterday's Hashes: $line"
                	        ;;
			+++*)	# File Header for second file
				echo "Today's Hashes: $line"
				;;
               		+*)     # Added line
                        	echo "Added line: $line"
                       		;;
                	-*)     # Deleted line
                        	echo "Deleted line: $line"
                        	;;
                       	*)      # Unchanged line for reference
               	        	echo "                  $line"
                        	;;
	      		esac
		done >> "$CHANGE_ALERT_FILE"
		echo "Change in Cron Jobs Detected" | mailx -s "Cron Jobs Changed, Shit Just Got Real!" chiragshah2030@u.northwestern.edu < "$CHANGE_ALERT_FILE"
	fi
    	else
        echo "No hash file from yesterday found."
        cp "$CURRENT_HASH_FILE" "$PREVIOUS_HASH_FILE"
    fi
}

# Run command to check for changes in cron job hashes from the day before
check_hash_change
