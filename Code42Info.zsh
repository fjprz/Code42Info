#!/bin/zsh
##################################################################
# Code42 Information Extension Attribute
##################################################################
# Pulls several bits of information about a backup set to determine health of said set
# Credit: bpavlov post on JamfNation (Posted: 8/4/2020 at 2:57 PM CDT)
# Additional Credit: AdminIA post on JamfNation (Posted: 8/12/2020 at 1:20 PM CDT)
# https://www.jamf.com/jamf-nation/discussions/36403/code42-crashplan-extension-attributes-v8-2-2020
# Frankensteined by Francisco Perez

# Import zsh date mod
zmodload zsh/datetime


##################################################################
# API Variables
##################################################################
# API Auth
apiURL="server.jamfcloud.com"
apiAuth=$(openssl enc -base64 -d <<< "[ENCRYPTEDCREDS]")

#API Connection - Get Registered User for computer in Jamf
serial=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')
location_response=$(curl -k -H "accept: application/xml" -u "$apiAuth" https://$apiURL:8443/JSSResource/computers/serialnumber/${serial}/subset/location)
registeredUser=$(echo $location_response | /usr/bin/awk -F'<username>|</username>' '{print $2}' | tr "A-Z" "a-z")
echo "regUser is $registeredUser"

computerName="$(echo $2 | awk '{print tolower($0)}')"
echo Computer name: $computerName


##################################################################
# Code42 EA Variables
##################################################################
# Code42 Application Paths
oldCode42Path="/Applications/CrashPlan.app"
newCode42Path="/Applications/Code42.app"

# Sets value of Code42 Application Log
Code42AppLog="/Library/Logs/CrashPlan/app.log"

# Sets location of all Code42 History Logs
Code42Logs=$(/bin/ls /Library/Logs/CrashPlan/history.log*)

#If value is 0, no user is logged in to Code42
Code42LoggedIn="$(/usr/bin/awk '/USER/{getline; gsub("\,",""); print $1; exit }' $Code42AppLog)"

# Gets Code42 username
Code42User="$(/usr/bin/awk '/USER/{getline; gsub("\,",""); print $2; exit }' $Code42AppLog)"

# get first part of code42 username, if it is the same as the computer name,
# then it is a machine account, set the code42user to the computer's registerUser
# for Code42 status purposes

checkCode42User="$(echo $Code42User | cut -f1,2 -d- | awk '{print tolower($0)}')"
if [ "$checkCode42User" = "$computerName" ]; then
  echo "Using machine account: $Code42User"
  Code42User="$registeredUser"
fi

# Checks if Code42 Client is Running
oldCode42Running="$(/usr/bin/pgrep "CrashPlan")"
newCode42Running="$(/usr/bin/pgrep "Code42")"


##################################################################
# Code42 Install Check
##################################################################
# Check if Code42 is installed before anything else

if [[ ! -d "$oldCode42Path" ]]; then
   echo "Old version not installed"
else
   Code42Path="$oldCode42Path"
fi

if [[ ! -d "$newCode42Path" ]]; then
  echo "New version not installed"
else
  Code42Path="$newCode42Path"
fi

if [[ ! -d "$Code42Path" ]]; then
    echo "<result>Not Installed</result>"
    exit 0
else
    Code42Version="$(/usr/bin/defaults read "$Code42Path"/Contents/Info CFBundleShortVersionString)"
fi


##################################################################
# Code42 App/User Status
##################################################################
# Reports Code42 App Status

if [[ -n "${oldCode42Running}" ]] || [[ -n "${newCode42Running}" ]]; then
    Code42AppStatus="On"
else
    Code42AppStatus="Off"
fi

# Reports Code42 User Status
if [[ "${Code42LoggedIn}" -eq 0 ]]
then
    Code42UserStatus="Not Logged In"
else
    Code42UserStatus="${Code42User}"
fi


##################################################################
# Code42 Last Backup
##################################################################
# Runs a loop to check Code42 history logs for the date and time of most recent Completed Backup
# If found, converts the date format, and reports it.
# If no completed backup is found, it goes to a previous log.
# If no completed backup is found, it defaults to 1901-01-01 00:00:01

for LINE in $Code42Logs; do
    Code42Date=$(/usr/bin/awk '/Completed\ backup/{print $2, $3}' $LINE | /usr/bin/tail -n1)

    if [ -z "$Code42Date" ]; then
        Code42LastBackup="1901-01-01"
        continue
    else
        Code42LastBackup=$(/bin/date -j -f "%m/%d/%y %l:%M%p" "$Code42Date" "+%Y-%m-%d")
        break
    fi
done


##################################################################
# Code42 Last Backup
##################################################################
# Checks app.log for Backup Set Name and reports it

if [ -f "$Code42AppLog" ]; then
    Code42BackupName="$(/usr/bin/awk -F,  '/COMPUTERS/{getline; gsub(/^[ \t]+|[ \t]+$/,"",$2);  print $2}' "$Code42AppLog")"

    if [ "$Code42BackupName" = "" ]; then
        Code42BackupName="No Backup Name Found"
    fi
else
    Code42BackupName="No Backup Name Found"
fi


##################################################################
# Code42 Backup Percentage
##################################################################
# Checks app.log for Backup Percentage and reports it

if [ -f "$Code42AppLog" ]; then
    Code42BackupPercentage="$(/usr/bin/awk -F\  '/[0-9]\% /{printf "%0.2f\n", $3}' "$Code42AppLog")"

    if [ "$Code42BackupPercentage" = "" ]; then
        Code42BackupPercentage="0"
    fi

else
    Code42BackupPercentage="0"
fi


##################################################################
# Code42 Backup Destination
##################################################################
# Checks app.log for Backup Destination and reports it

if [ -f "$Code42AppLog" ]; then
    Code42BackupDestination="$(/usr/bin/awk -F,\  '/ Code42\ Cloud/{print $2}' "$Code42AppLog" | tail -1)"

    if [ "$Code42BackupDestination" = "" ]; then
        Code42BackupDestination="Not Setup"
    fi

else
    Code42BackupDestination="Not Code42 Cloud"
fi


##################################################################
# Code42 Backup Size
##################################################################
# Checks app.log for Backup Size and reports it

if [ -f "$Code42AppLog" ]; then
    Code42BackupSize="$(/usr/bin/awk -F=\  '/totalSize                      =\ /{print $2}' /Library/Logs/CrashPlan/app.log)"

        if [ "$Code42BackupSize" = "" ]; then
            Code42BackupSize="No Backup"
        fi

else
    Code42BackupSize="N/A"
fi


##################################################################
# Code42 Backup Freshness Check
##################################################################
# Checks app.log for Last Backup Date, compares it with today's date and and reports difference

if [ "$Code42Date" != "" ]; then
  Code42LBKDate=$(/bin/date -j -f "%m/%d/%y %l:%M%p" "$Code42Date" "+%Y-%m-%d")
  DateToday=$(/bin/date +"%Y-%m-%d")
  BKFreshnessCheck=$(( ( $(strftime -r %Y-%m-%d $DateToday) - $(strftime -r %Y-%m-%d $Code42LBKDate) ) / 86400 ))
else
  BKFreshnessCheck="999"
fi


##################################################################
# Code42 Organizational Unit
##################################################################
# Checks app.log for Org Unit and reports it

if [ -f "$Code42AppLog" ]; then
    Code42Organization="$(/usr/bin/awk -F, '/USERS/{getline; gsub(/^[ \t]+|[ \t]+$/,"",$5); print $5}' "$Code42AppLog" | /usr/bin/cut -d '-' -f 2)"

      if [ "$Code42Organization" = "" ]; then
        Code42Organization="No Org Info"
      fi

else
    Code42Organization="N/A"
fi


##################################################################
# Backup Grade
##################################################################
# Backups are verified GOOD if:
# * The user should have a backup set in the cloud.
# * If the Client is Connecting Successfully.
# * If the Selected Backup Size matches selected Files. (Unable to determine w/ script)
# * If the Used Storage is comparable with selected Backup size. (DU Command causes script to prompt PPPC warnings/takes too long)
# * If the Restorable Files includes files in the selected backup folders. (Unable to determine w/ script)
# * If the Percent Complete is over 97%.
# * Make sure logged in user is same as


if [[ "$registeredUser" != "$Code42UserStatus" ]]; then
   Code42UserStatus+=" (mismatch)"
fi

if [[ "$registeredUser" == "$Code42UserStatus" && "$Code42BackupDestination" == "Code42 Cloud" ]] && [[ $BKFreshnessCheck -le 3 && $Code42BackupPercentage -ge 97 ]]; then
    BackupGrade="Good"
else
    BackupGrade="Bad"
fi

#Flips Code42 Backup Status EA between Good and Bad
curl -k -s -u "$apiAuth" -X "PUT" "https://$apiURL:8443/JSSResource/computers/serialnumber/${serial}/subset/extension_attributes" -H "Content-Type: application/xml" -H "Accept: application/xml" -d "<computer><extension_attributes><extension_attribute><id>[ID Number]</id><name>Code42 Backup Status</name><type>String</type><value>$BackupGrade</value></extension_attribute></extension_attributes></computer>"


##################################################################
# Output
##################################################################
echo "<result>
Version:           ${Code42Version}
App Status:        ${Code42AppStatus}
Code42 User:       ${Code42UserStatus}
Code 42 Org:       ${Code42Organization}
Last Backup:       ${Code42LastBackup}
Backup Name:       ${Code42BackupName}
Backup Completion: ${Code42BackupPercentage}%
Backup Size:       ${Code42BackupSize}
Destination:       ${Code42BackupDestination}
Backup Staleness:  ${BKFreshnessCheck} Days
Backup Status:     ${BackupGrade}
</result>"

exit 0
