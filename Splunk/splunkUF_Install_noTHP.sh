#!/bin/sh
#
#
#copy splunkforwarder-*.tgz to your home directory on the server
#
#
# Set the install file and it's location
read -e -p "Enter full path and .tgz for the Splunk Forwarder: " INSTALL_FILE

# After installation, the forwarder will become a deployment client of this
# host.  Specify the host and management port of the deployment server
# that will be managing these forwarder instances.
DEPLOY_SERVER=""

# Set the new Splunk admin password
PASSWORD=""

#Splunk Forwarder home directory
SPLUNK_HOME="/opt/splunkforwarder"

#create splunk user and set directory
useradd --home-dir $SPLUNK_HOME splunk

#untar to /opt/ and remove original file
tar -xzf $INSTALL_FILE -C /opt
rm -f $INSTALL_FILE

#Change Owner
chown -RH splunk:splunk $SPLUNK_HOME

#add splunk environmental variables
sudo -u splunk cat >> $SPLUNK_HOME/.bashrc <<EOF
source /opt/splunkforwarder/bin/setSplunkEnv
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
PS1='\u@\h:[\w]> '
EOF

#run splunk for the first time as the new splunk user
sudo -u splunk $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes --no-prompt

#Set splunk deployment server
sudo -u splunk $SPLUNK_HOME/bin/splunk set deploy-poll $DEPLOY_SERVER --accept-license --answer-yes --auto-ports --no-prompt -auth admin:changeme

#Change splunk inter-communication password
sudo -u splunk $SPLUNK_HOME/bin/splunk edit user admin -password $PASSWORD -auth admin:changeme

#restart splunk
sudo -u splunk $SPLUNK_HOME/bin/splunk restart

#Enable splunk to start at boot as user splunk
$SPLUNK_HOME/bin/splunk enable boot-start --accept-license -user splunk

#Change ulimits
sed -i '/# End of file/i \
splunk soft nofile 10240\
splunk hard nofile 10240\
splunk soft nproc 10240\
splunk hard nproc 10240' /etc/security/limits.conf

#Add ulimits to splunk start script
sed -i '/init.d\/functions/a ulimit -Sn 10240' /etc/init.d/splunk
sed -i '/init.d\/functions/a ulimit -Hn 10240' /etc/init.d/splunk
