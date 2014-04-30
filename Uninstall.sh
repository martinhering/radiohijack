#! /bin/sh

# <codex>
# <abstract>Script to remove everything installed by the sample.</abstract>
# </codex>

# This uninstalls everything installed by the sample.  It's useful when testing to ensure that 
# you start from scratch.

sudo launchctl unload /Library/LaunchDaemons/com.vemedio.RadioHijack.Sniffer.plist
sudo rm /Library/LaunchDaemons/com.vemedio.RadioHijack.Sniffer.plist
sudo rm /Library/PrivilegedHelperTools/com.vemedio.RadioHijack.Sniffer

sudo security -q authorizationdb remove "com.example.apple-samplecode.EBAS.readLicenseKey"
sudo security -q authorizationdb remove "com.example.apple-samplecode.EBAS.writeLicenseKey"
sudo security -q authorizationdb remove "com.example.apple-samplecode.EBAS.startWebService"
