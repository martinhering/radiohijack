##RadioHijack

###What's the problem?

Internet streaming radio sucks! And I don't mean the content (that's another discussion), I mean the technology. There is no standard technology like we have with podcasts. Unfortunately most of the radio websites are sill using Adobe Flash and don't offer streaming URLs for native clients. So, what do you do if you want to listen to your favorite radio station, but don't want to use the browser? You need the streaming URL of the radio station to enter into a native client application. And that's where RadioHijack comes into play.

###What does it do?
RadioHijack is a native app for OS X that monitors your network traffic and tries to find a usable streaming URL. The only thing you have to do is, start hijacking and use a Flash enabled browser like Chrome to navigate to the target radio website. Click on the "listen now" button and let it start playing the radio station. In the background RadioHijack parses all the network packets and tries to find the streaming URL of that radio station, that can then be send to other applications like "QuickTime Player" or "Snowtape".

###How does it monitor my network traffic?
RadioHijack includes a small sniffer tool that is installed into the system as a Launch Services daemon and runs with root privileges. These privileges are needed to capture network packets from your network device. If the main application is closed, the tool also gets terminated and doesn't use any resources. The repository includes an uninstall shell script to get rid of the tool if you don't want to use the app anymore. 

###What technologies does it recognize?
At the moment, it only looks for MP3 or AAC/HE-ACC streams that can be played with the QuickTime Player and other Shoutcast/Icecast supporting apps.

###What do I do, when it doesn't find anything?
The best cause of action is to [file a bug](https://github.com/martinhering/radiohijack/issues) on Github. If you are a developer, please feel free to fork the project.