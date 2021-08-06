# Code42Info
Code42 Info EA Script\
\
Pulls several bits of information about a backup set to determine health of said set\
Credit: bpavlov post on JamfNation (Posted: 8/4/2020 at 2:57 PM CDT)\
Additional Credit: AdminIA post on JamfNation (Posted: 8/12/2020 at 1:20 PM CDT)\
https://www.jamf.com/jamf-nation/discussions/36403/code42-crashplan-extension-attributes-v8-2-2020\
Frankensteined by Francisco Perez\
\
Provides Code42 info below:\
\
Version:           ${Code42Version}\
App Status:        ${Code42AppStatus}\
Code42 User:       ${Code42UserStatus}\
Code 42 Org:       ${Code42Organization}\
Last Backup:       ${Code42LastBackup}\
Backup Name:       ${Code42BackupName}\
Backup Completion: ${Code42BackupPercentage}%\
Backup Size:       ${Code42BackupSize}\
Destination:       ${Code42BackupDestination}\
Backup Staleness:  ${BKFreshnessCheck} Days\
Backup Status:     ${BackupGrade}\
\
*This EA flips a separate pop-up menu EA which can be used to build smart groups. Jamf's current Regex parsing does not work with multi-line EAs.\
