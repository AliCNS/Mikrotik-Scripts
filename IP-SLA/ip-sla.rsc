#Script creates variable storage in /ip proxy access for an ipsla instance. 
# User set Variables
#Variable represents the name of the ipsla instance (recommended to name them: ipsla1, ipsla2...ipslaN)
:local ipslaName ipsla1;
#IP to ping
:local target "4.2.2.2";
#Size of pings to send
:local size "1200";
#Variable represents total number of ping records to keep
:local livesKept 100;
:local probeInterval "10s";
#Analyze Interval should be a multiple of the probe interval
:local analyzeInterval "4m";
#Number of previous statistics to calculate loss/latency averages on
:local checkNumStats 100;
#Threshold for when latency will cause monitor to be down status
:local latencyThreshold 500;
#Threshold for when packet loss will cause monitor to be down status (this_variable is a percentage)
:local lossThreshold 15;

#Add proxy rules for storing ping statistics
#Add record with comment stating rules
/ip proxy access add action=allow comment="9999 - Flag for ping timed out.     For \"Current Index\" record: dst-port is current index, dst-host is total number of records           For standard records:  dst-port column is latency, dst-host column is number"
:for i from=0 to=$livesKept do=\
{ 
    :if (i=0) do={ /ip proxy access add action=allow disabled=no dst-port=1 dst-host="$livesKept" comment="Current Index - $ipslaName";}\
    else=\
    {
        /ip proxy access \
        add action=allow disabled=no dst-port=0 dst-host="$i" method=$ipslaName;
    };
};

#Add scheduling for probe and analyze scripts
/system scheduler
add comment="Run every X seconds" disabled=no interval=$probeInterval name=\
    ($ipslaName."_probe") on-event=($ipslaName."_probe") policy=\
    ftp,reboot,read,write,policy,test,winbox,password,sniff,sensitive,api \
    start-time=startup
add comment="Should run on an interval that is a multiple of $ipslaName _probe interv\
    al (Recommended to multiply by the \"checkNumStats\" variable in the analyze\
    \_script)" disabled=no interval=$analyzeInterval name=($ipslaName."_analyze") \
    on-event=($ipslaName."_analyze") policy=\
    ftp,reboot,read,write,policy,test,winbox,password,sniff,sensitive,api \
    start-time=startup

#Add probe script
/system script
add name=($ipslaName."_probe") policy=ftp,reboot,read,write,policy,test,winbox,password,sniff,sensitive,api source="# Variables - $ipslaName\
    \n:global $ipslaName;\
    \n:local name $ipslaName;\
    \n:local response  -1;\
    \n:local target $target;\
    \n:local pingSize $size;\
    \n\
    \n#Variables derived from stored settings\
    \n:global floodpingisbusy;\
    \n:local currentIndex;\
    \n:local livesKept;\
    \n:local currentStat;\
    \n\
    \n#Check if floodping is being used and delay if so\r\
    \n:while (\$floodpingisbusy) do={ /delay delay-time=1 };\r\
    \n\r\
    \n#Mark floodping as used before using\r\
    \n:set floodpingisbusy value=true;\r\
    \n#Ping target and gather latest statistic\r\
    \n/tool flood-ping \$target count=1 size=\$pingSize do=\\\r\
    \n{\r\
    \n    :set response \$\"avg-rtt\";\r\
    \n};\r\
    \n#reset floodpingisbusy so other processes can use it again\r\
    \n:set floodpingisbusy value=false;\r\
    \n\r\
    \n#Get stored Index\r\
    \n:set currentIndex [/ip proxy access get [find comment=\"Current Index - \$name\"] dst-port]; \
    \n:set currentStat [/ip proxy access find (method=\"\$name\" and dst-host=\"\$currentIndex\")];\
    \n:set livesKept [/ip proxy access get [find comment=\"Current Index - \$name\"] dst-host]; \
    \n\
    \n#Check if no response\
    \n:if (\$response = 0) do=\\\
    \n{\
    \n    /ip proxy access set \$currentStat dst-port=9999 dst-address=\$target;\
    \n} \\\
    \nelse=\\\
    \n{\
    \n    /ip proxy access set \$currentStat dst-port=\$response dst-address=\$target;\
    \n};\
    \n\
    \n#Increment index to next (set back to start if at end)\
    \n:if (\$currentIndex>=\$livesKept) do=\\\
    \n{\
    \n    :set currentIndex 1;\
    \n} else=\\\
    \n{\
    \n    :set currentIndex (\$currentIndex+1);\
    \n};\
    \n\
    \n/ip proxy access set [/ip proxy access find comment=\"Current Index - \$name\"] dst-port=\$currentIndex"

#Add analyze script
/system script
add name=($ipslaName."_analyze") policy=\
   ftp,reboot,read,write,policy,test,winbox,password,sniff,sensitive,api \
   source=("\
   \n#User set variables\
   \n#Variable for storing up/down status of ipsla (if this variable is edited, make sure to edit checks at the end of this script)\
   \n:global $ipslaName\
   \n## Global variable for viewing current packet loss\
   \n:global ".$ipslaName."PacketLossPercent\
   \n##Global variable for viewing current average latency\
   \n:global ".$ipslaName."AverageLatency\
   \n##Name (must match the name used in createStorageVariables script\
   \n:local ipslaName $ipslaName;\
   \n#Number of previous statistics to calculate loss/latency averages on\
   \n:local checkNumStats $checkNumStats;\
   \n#Threshold for when latency will cause monitor to be down status\
   \n:local latencyThreshold $latencyThreshold;\
   \n#Threshold for when packet loss will cause monitor to be down status (this\
   \_variable is a percentage)\
   \n:local lossThreshold $lossThreshold;\
   \n\
   \n#Variables derived from stored settings\
   \n:local livesKept [/ip proxy access get [find comment=\"Current Index - \$i\
   pslaName\"] dst-host]; \
   \n:local currentStatLatency;\
   \n:local currentIndex [/ip proxy access get [find comment=\"Current Index - \
   \$ipslaName\"] dst-port];\
   \n#Decrease current index by one since current index is pending update but c\
   urrentindex-1 is the most recently updated\
   \n:if (\$currentIndex=1) do=\\\
   \n{ \
   \n    :set currentIndex (\$livesKept); \
   \n} else=\\\
   \n{ \
   \n    :set currentIndex (\$currentIndex-1); \
   \n};\
   \n:local startIndex \$currentIndex;\
   \n:local totalLatency 0;\
   \n:local avgLatency;\
   \n:local percentLoss;\
   \n:local received 0;\
   \n:local lost 0;\
   \n:local polledIp;\
   \n\
   \n#Go through loop as many times as necessary to gather each statistic that \
   will be calucalted upon\
   \n:for i from=1 to=(\$checkNumStats) do=\\\
   \n{\
   \n#### Store latency of current statistic\
   \n    :set currentStatLatency [/ip proxy access get [find (method=\"\$ipslaN\
   ame\" and dst-host=\"\$currentIndex\")] dst-port]; \
   \n#### Check if value is flagged with 9999 (ping timed out)\
   \n    :if (\$currentStatLatency=9999) do={:set lost (\$lost+1);} else=\\\
   \n    {\
   \n######## If not timed out, add latency to total\
   \n#        :put \$currentStatLatency\
   \n        :set received (\$received+1);\
   \n        :set totalLatency (\$totalLatency+\$currentStatLatency);\
   \n    };\
   \n####Check if index is at the end of the statistic list, reset to beginning\
   \_if necessary\
   \n    :if (\$currentIndex=1) do=\\\
   \n    { \
   \n        :set currentIndex (\$livesKept); \
   \n    } else=\\\
   \n    { \
   \n        :set currentIndex (\$currentIndex-1); \
   \n    };\
   \n};\
   \n:set polledIp [/ip proxy access get [find (method=\"\$ipslaName\" and dst-\
   host=\"\$currentIndex\")] dst-address];\
   \n:set percentLoss ((\$lost*100) / ((\$received+\$lost)));\
   \n:if (\$received=0) do=\\\
   \n{\
   \n    :set avgLatency 0;\
   \n} else=\\\
   \n{\
   \n    :set avgLatency (\$totalLatency/\$received);\
   \n};\
   \n\
   \n#Log statistics\
   \n:log info \"Ran \$ipslaName analyze script, checked last \$checkNumStats p\
   oll(s) on \$polledIp\"\
   \n:log info \"Average Latency: \$avgLatency\";\
   \n:log info \"Percent loss: \$percentLoss (lost: \$lost, Received \$received\
   )\";\
   \n\
   \n#Add whatever checks on latency and percent loss down here along with acti\
   ons\
   \n:if ((\$percentLoss>\$lossThreshold) || (\$avgLatency>\$latencyThreshold))\
   \_do=\\\
   \n{\
   \n    :if (("."\$"."$ipslaName)!=\"down\") do=\\\
   \n    {\
   \n        :set $ipslaName \"down\"\
   \n        :log error (\"\$ipslaName is down\"); \
   \n        :log error (\"Packet Loss: \$percentLoss  Average Latency: \$avgLa\
   tency\");\
   \n    };\
   \n} else=\\\
   \n{\
   \n    :if (("."\$"."$ipslaName)=\"down\") do=\\\
   \n    {\
   \n        :log error (\"\$ipslaName is back up\");\
   \n    };\
   \n    :set $ipslaName \"up\";\
   \n    :set ".$ipslaName."PacketLossPercent \$percentLoss;\
   \n    :set ".$ipslaName."AverageLatency \$avgLatency;\
   \n };")
