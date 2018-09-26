#!/bin/sh
#
# splunk-install.sh
#   Created: 09-26-2018
#Run this script as root to setup a new Splunk server.
#
################################################################################

###############
###Variables###
###############

#Splunk Public PGP file
WGET_CMD_PGP="wget http://docs.splunk.com/images/a/aa/SplunkPGPKeyBeforeAugust2018.pub"
PGP_KEY="SplunkPGPKeyBeforeAugust2018.pub"

#Splunk Installer File
#WGET_CMD="wget -O splunk-7.1.0-2e75b3406c5b-linux-2.6-x86_64.rpm https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.1.0&product=splunk&filename=splunk-7.1.0-2e75b3406c5b-linux-2.6-x86_64.rpm&wget=true"
#INSTALL_FILE="splunk-7.1.0-2e75b3406c5b-linux-2.6-x86_64.rpm"
WGET_CMD="wget -O splunk-7.0.2-03bbabbd5c0f-linux-2.6-x86_64.rpm https://www.splunk.com/page/download_track?file=7.0.2/linux/splunk-7.0.2-03bbabbd5c0f-linux-2.6-x86_64.rpm&ac=&wget=true&name=wget&platform=Linux&architecture=x86_64&version=7.0.2&product=splunk&typed=release"
INSTALL_FILE="splunk-7.0.2-03bbabbd5c0f-linux-2.6-x86_64.rpm"

#Splunk home directory
SPLUNK_HOME="/opt/splunk"

DEPLOYMENT_SERVER_URI=""

#Should indexer join the cluster?
#0 = Yes or 1 = No
JOINCLUSTER="1"

#Environment variables
LS_COLORS='$LS_COLORS'

#Linux user which Splunk will run as
USERNAME="splunk"

###################
###Install Steps###
###################



#Check to see if /opt/splunk/bin/splunk exists. If it does exit.
if [ -f $SPLUNK_HOME/bin/splunk ]; then
  echo ""
  echo "--------------------------------------"
  echo "Splunk already exists. Exiting script."
  echo "--------------------------------------"
  echo ""
  exit 1
fi

#Collectin Input from user
echo ""
echo ""
echo "-------------------------------"
echo "1 - Heavy Forwarder"
echo "2 - Search Head (not complete)"
echo "3 - Indexer"
echo "4 - Exit"
echo "-------------------------------"
echo ""
read -e -p "Enter the number which corresponds to the type of Splunk system you are setting up: " INSTALL_TYPE
echo ""

#Check Input for invalid characters
INPUT_REGEX='^[1-4]'
if ! [[ $INSTALL_TYPE =~ $INPUT_REGEX ]]; then
  echo "Invalid input."
  exit 1
elif [ $INSTALL_TYPE -eq 4 ]; then
  echo "Exiting script!"
  exit 1
fi

#Get the password for the admin account
read -s -p "Enter the splunk admin password: " SPLUNK_PASSWORD
echo ""

if [ $INSTALL_TYPE -eq 3 ]; then
  read -e -p "Enter the Indexer Cluster Master URI: " INDEXER_CLUSTER_MASTER_URI
  echo ""
  read -e -p "Enter the Indexer Cluster Key: " INDEXER_CLUSTER_KEY
  echo ""
fi

#Install Splunk public key into RPM keystore
$WGET_CMD_PGP && rpm --import $PGP_KEY
if [ $? -eq 0 ]; then
  echo ""
  echo "----------------------------------------"
  echo "Splunk public key successfully imported."
  echo "----------------------------------------"
  echo ""
  rm -rf $PGP_KEY
else
  echo ""
  echo "-----------------------------------------------------"
  echo "Problem installing Splunk public key. Exiting script."
  echo "-----------------------------------------------------"
  echo ""
  exit 1
fi

#Download the rpm file
$WGET_CMD
if [ $? -eq 0 ]; then
  echo ""
  echo "---------------------------"
  echo "RPM downloaded Successfully"
  echo "---------------------------"
  echo ""
else
  echo ""
  echo "---------------------------------------------"
  echo "Problem downloading rpm file. Exiting script."
  echo "---------------------------------------------"
  echo ""
  exit 1
fi

#Verify the public key matches the signature of the rpm
rpm -K $INSTALL_FILE
if [ $? -eq 0 ]; then
  echo ""
  echo "--------------------------"
  echo "RPM verified Successfully."
  echo "--------------------------"
  echo ""
else
  echo ""
  echo "------------------------------------------------------------------"
  echo "Problem verifying Splunk rpm file with public key. Exiting script."
  echo "------------------------------------------------------------------"
  echo ""
  exit 1
fi

#Check to see if splunk user exists and create if it does not
egrep "^$USERNAME" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
  chage -M 9999 splunk
  echo ""
  echo "---------------------------------------------------------------------------"
  echo "$USERNAME username already exists, not creating account but expiration set."
  echo "---------------------------------------------------------------------------"
  echo ""
else
  useradd --home-dir $SPLUNK_HOME $USERNAME
  chage -M 9999 splunk
  echo ""
  echo "-------------------------------------------------------------------"
  echo "$USERNAME username successfully created and password expiration set"
  echo "-------------------------------------------------------------------"
  echo ""
fi

#Install RPM file
rpm -Uvh $INSTALL_FILE
if [ $? -eq 0 ]; then
  echo ""
  echo "----------------------------------------------------------------------------------------------------"
  echo "RPM successfully installed, removing $INSTALL_FILE."
  echo "----------------------------------------------------------------------------------------------------"
  echo ""
  rm -f $INSTALL_FILE
else
  echo ""
  echo "------------------------------------------"
  echo "Problem installing splunk. Exiting script."
  echo "------------------------------------------"
  echo ""
  exit 1
fi

#Change ownership of the splunk directory
chown -R $USERNAME:$USERNAME $SPLUNK_HOME

#Start splunk as the splunk user for the first time
sudo -u $USERNAME $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes --auto-ports --no-prompt

#Set environmental variables for splunk account
sudo -u $USERNAME touch $SPLUNK_HOME/.bashrc
echo -e "
#Custom Variables
source /opt/splunk/bin/setSplunkEnv
LS_COLORS=$LS_COLORS'di=01;32:' ; export LS_COLORS
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
PS1='\u@\h:[\w]> '" >> $SPLUNK_HOME/.bashrc

#Enable Splunk to start automatically if rebooted
/opt/splunk/bin/splunk enable boot-start -user splunk

#Disable Transparent Huge Pages
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

#Disable Transparent Huge Pages at boot time
sed -i -e '$a\
#\
#disable THP at boot time\
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then\
     echo never > /sys/kernel/mm/transparent_hugepage/enabled\
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then\
     echo never > /sys/kernel/mm/transparent_hugepage/defrag\
fi' /etc/rc.local

#make rc.local executable
chmod +x /etc/rc.local

#Load new rc.local config
systemctl start rc-local

#Appy the ulimit settings in limits.conf
sed -i '/# End of file/i \\n splunk soft nofile 64000 \n splunk hard nofile 64000 \n splunk soft nproc 16000 \n splunk hard nproc 16000 \n splunk hard fsize -1 \n' /etc/security/limits.conf

#Update the password
sudo -u $USERNAME $SPLUNK_HOME/bin/splunk edit user admin -password $SPLUNK_PASSWORD -auth admin:changeme

if [ $INSTALL_TYPE -eq 1 ]; then

  #Add as deployment client to receive configuration.
  if [ ! -f $SPLUNK_HOME/etc/system/local/deploymentclient.conf ]; then
    sudo -u $USERNAME touch $SPLUNK_HOME/etc/system/local/deploymentclient.conf
  fi
  echo -e "
  [target-broker:deploymentServer]
  targetUri = $DEPLOYMENT_SERVER_URI" >> $SPLUNK_HOME/etc/system/local/deploymentclient.conf

  #restart splunk
  sudo -u $USERNAME $SPLUNK_HOME/bin/splunk restart
  echo ""
  echo ""

elif [ $INSTALL_TYPE -eq 2 ]; then
  #Search Head specific steps

  #restart splunk
  sudo -u $USERNAME $SPLUNK_HOME/bin/splunk restart
  echo ""
  echo ""

elif [ $INSTALL_TYPE -eq 3 ]; then
  #Indexer specific steps

  #Disable Splunk web to prevent script from waiting for web server.
  if [ ! -f $SPLUNK_HOME/etc/system/local/web.conf ]; then
    sudo -u $USERNAME touch $SPLUNK_HOME/etc/system/local/web.conf
  fi
  echo -e "
  [settings]
  startwebserver = 0" >> $SPLUNK_HOME/etc/system/local/web.conf

  #Join indexer to cluster
  if [ $JOINCLUSTER -eq 0 ]; then
    echo -e "
    [replication_port://9887]

    [clustering]
    master_uri = $INDEXER_CLUSTER_MASTER_URI
    mode = slave
    pass4SymmKey = $INDEXER_CLUSTER_KEY" >> $SPLUNK_HOME/etc/system/local/server.conf
  fi

  #restart splunk
  sudo -u $USERNAME $SPLUNK_HOME/bin/splunk restart
  echo ""
  echo ""
fi

echo ""
echo "****************"
echo "Install Complete"
echo "****************"
echo ""
