OK, here it is. 

The below script is a "setup" to create all the items necessary to setup a monitor on one IP address. By its self, this setup does nothing but monitor one ip address and based on the results, sets a global variable for to "up" or "down". You need another "failover" script to monitor these global variables and take action. I'll post my failover script shortly. 

Here is what the setup script does though: 
1. Creates a "probe" script & schedule that runs a ping and stores the latency 
- Set "probeInterval" to decide how frequently scheduler runs this
- Set "livesKept" to decide how many ping results to store (I recommend keeping 100)
- Set "target" to the IP you want to monitor
- Set "ipslaName" to the name. Should be "ipsla1", "ipsla2", etc.. Each must be unique.
2. Creates a "analyze" script & schedule that runs analysis on the stored ping responses 
- Set "analyzeInterval" to decide how frequently scheduler runs this
- Set "checkNumStats" to decide how many previous statistics to calculate loss on. I set this to the same value as "livesKept" since I don't care about storing data longer than it is used to calculate the average latency/average packet loss
- Set "latencyThreshold" to the average milliseconds threshold for the monitor to go to a "down" state
- Set "lossThreshold" to the percent packet loss threshold for the monitor to go to a "down" state
3. Creates rules in /ip proxy access . These rules do nothing but store ping values for each instance 
- If you use "/ip proxy" for it's intended purpose (running a proxy), you will have to find a different area to store the ping variables in and adjust this script. 

Before running the setup, please edit values under the, "User set Variables" comment first. This was tested on ROS version 5.26.


Keep in mind that this script uses floodping since regular ping can not return a latency value to a script. Floodping can only run one instance at a time so these scripts use a global variable called, "floodpingisbusy" to check whether it is in use by another probe monitor before trying to probe. For this reason, I don't think you can run many more than 4 or 5 probe scripts at a time (depending on the probe interval, this 4-5 estimate is based on 10s interval). 

Some useful suggestions after running initial setup:
1. Go to IP -> Proxy -> Access and see current values to confirm this is working
2. Go to System -> Scripts -> Environment to see current values of global variables
3. Watch logs to see "analyze" scripts running and current statistics
