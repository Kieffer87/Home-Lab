#!/bin/bash

#Add the Dell OMSA Jessie repository
sudo echo 'deb http://linux.dell.com/repo/community/debian jessie openmanage' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list

#Install directory manager which is required by gpg
sudo apt-get install dirmngr

#To verify OMSA packages, add the repository key to apt.
##Download the key
sudo gpg --keyserver pool.sks-keyservers.net --recv-key 1285491434D8786F

##Install the key
gpg -a --export 1285491434D8786F | sudo apt-key add -

#Download the libslp package from jessie, it was removed from Debian 9 stretch.
wget http://ftp.br.debian.org/debian/pool/main/o/openslp-dfsg/libslp1_1.2.1-10+deb8u1_amd64.deb

#Install libslp1
sudo dpkg -i libslp1_1.2.1-10+deb8u1_amd64.deb

#Download the libssl package from jessie, it was removed from Debian 9 stretch.
wget http://ftp.us.debian.org/debian/pool/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u7_amd64.deb

#Install libssl1
sudo dpkg -i libssl1.0.0_1.0.1t-1+deb8u7_amd64.deb

#Update packages
sudo apt-get update

#Install OMSA 8.4
sudo apt-get install srvadmin-all

#Edit OMSA web users
nano /opt/dell/srvadmin/etc/omarolemap

#Start web interface
sudo service dsm_om_connsvc start

#Enable web interface to start at boot
sudo update-rc.d dsm_om_connsvc defaults

#Access OMSA via web ui
https://<ip_address>:1311/
