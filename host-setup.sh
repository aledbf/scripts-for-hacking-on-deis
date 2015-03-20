#!/bin/bash
#
# Preps a Ubuntu 14.04 box with requirements to run the deis test suite.
#

# fail on any command exiting non-zero
set -eo pipefail

# check user
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
fi

apt-get install -y apt-transport-https

# install docker
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
sh -c "echo deb https://get.docker.com/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
apt-get update && apt-get install -yq lxc-docker-1.5.0

# add user to docker group
usermod -G docker "$SUDO_USER"

# install virtualbox
apt-get install -yq build-essential psmisc xvfb

# install vagrant
echo "deb http://download.virtualbox.org/virtualbox/debian '$(lsb_release -cs)' contrib non-free" > /etc/apt/sources.list.d/virtualbox.list
wget -nv http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
apt-get update && apt-get install -y virtualbox-4.3 dkms

# install vagrant
wget -nv https://dl.bintray.com/mitchellh/vagrant/vagrant_1.7.2_x86_64.deb
dpkg -i vagrant_1.7.2_x86_64.deb && rm vagrant_1.7.2_x86_64.deb

# install go
wget -nv -O- https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz | tar -C /usr/local -xz
echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile

# install fleet
wget -nv -O- https://github.com/coreos/fleet/releases/download/v0.9.1/fleet-v0.9.1-linux-amd64.tar.gz | \
  tar -C /usr/local/bin/ --strip-components=1 -xz

# install test suite requirements
apt-get install -yq mercurial python-dev libffi-dev libpq-dev libyaml-dev git postgresql-client
curl -sSL https://raw.githubusercontent.com/pypa/pip/6.0.8/contrib/get-pip.py | python -
pip install virtualenv

# install Virtualbox Extension Pack
VBOX_VERSION=$(dpkg -s virtualbox-4.3 | grep '^Version: ' | sed -e 's/Version: \([0-9\.]*\)\-.*/\1/')
wget -nv "http://download.virtualbox.org/virtualbox/$VBOX_VERSION/Oracle_VM_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack"
VBoxManage extpack install "Oracle_VM_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack"

# install required plugins
vagrant plugin install vagrant-triggers
vagrant plugin install vagrant-vbguest

# cleanup
rm -rf "Oracle_VM_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack"
rm -rf ./*.deb

exit 0

