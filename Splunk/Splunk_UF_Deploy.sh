######### UF_install.sh Script ##############

#!/bin/sh

#### forwarderlist.txt contains the IP address of the forwarder to SSH into
HOSTS_FILE="/opt/splunk/bin/scripts/forwarderlist.txt"

### Download the latest version of the installer from splunk site
WGET_CMD="wget -O splunkforwarder-6.6.3-e21ee54bc796-Linux-x86_64.tgz 'https://www.splunk.com/page/download_track?file=6.6.3/linux/splunkforwarder-6.6.3-e21ee54bc796-Linux-x86_64.tgz&ac=&wget=true&name=wget&platform=Linux&architecture=x86_64&version=6.6.3&product=universalforwarder&typed=release'"
INSTALL_FILE="splunkforwarder-6.6.3-e21ee54bc796-Linux-x86_64.tgz"

#Splunk Forwarder home directory
SPLUNK_HOME="/opt/splunkforwarder"

#Splunk deployment server
DEPLOY_SERVER=""

#New Splunk admin password
PASSWORD=""

#SSH user
USER=""

### installation steps
REMOTE_SCRIPT="
sudo $WGET_CMD
sudo tar -xzf $INSTALL_FILE -C /opt
sudo rm -f $INSTALL_FILE

sudo useradd --home-dir $SPLUNK_HOME admin
sudo chown -R admin:admin $SPLUNK_HOME


sudo -u admin $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes --auto-ports --no-prompt
sudo $SPLUNK_HOME/bin/splunk enable boot-start --accept-license -user admin
sudo -u admin $SPLUNK_HOME/bin/splunk set deploy-poll $DEPLOY_SERVER --accept-license --answer-yes --auto-ports --no-prompt  -auth admin:changeme
sudo -u admin $SPLUNK_HOME/bin/splunk edit user admin -password $PASSWORD -auth admin:changeme

#Restart Splunk
sudo -u admin $SPLUNK_HOME/bin/splunk restart
"

### Continue the same for other UF hosts
echo "In 5 seconds, will run the following script on each remote host:"
echo
echo "===================="
echo "$REMOTE_SCRIPT"
echo "===================="
echo
sleep 5
echo "Reading host logins from $HOSTS_FILE"
echo
echo "Starting."
for DST in `cat "$HOSTS_FILE"`; do
  if [ -z "$DST" ]; then
    continue;
  fi
  echo "---------------------------"
  echo "Installing to $DST"
  sudo ssh -t "$USER"@"$DST" "$REMOTE_SCRIPT"
done
echo "---------------------------"
echo "Done"
