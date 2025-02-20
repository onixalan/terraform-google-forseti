#!/bin/bash
set -eu

# Env variables
USER=ubuntu
USER_HOME=/home/ubuntu

# Ubuntu update.
echo "Forseti Startup - Upgrading Ubuntu packages."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt-get update -y

# Install Ubuntu packages
echo "Forseti Startup - Installing Ubuntu packages."
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates git gnupg unzip

# Install Google Cloud SDK
echo "Forseti Startup - Installing Google Cloud SDK."
# Add the Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Update the package list
sudo apt-get update -y

# Install the Google Cloud SDK
sudo apt-get install google-cloud-sdk -y

# Install fluentd if necessary.
if [ -e "/usr/sbin/google-fluentd" ]; then
    cd $USER_HOME
    curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
    bash install-logging-agent.sh
fi

# Install Forseti Security.
cd $USER_HOME
rm -rf *forseti*

# Download Forseti source code
git clone --branch ${forseti_version} --depth 1 ${forseti_repo_url}
cd forseti-security

# Forseti host dependencies
sudo apt-get install -y $(cat install/dependencies/apt_packages.txt | grep -v "#" | xargs)

# Forseti dependencies
python3 -m pip install -q --upgrade setuptools wheel
python3 -m pip install -q --upgrade -r requirements.txt

# Install Forseti
echo "Installing Forseti"
python3 setup.py install

# Set ownership of the forseti project to $USER
chown -R $USER ${forseti_home}

# Store the variables in /etc/profile.d/forseti_environment.sh
# so all the users will have access to them
echo "${forseti_environment}" > /etc/profile.d/forseti_environment.sh | sudo sh

# Download client configuration from GCS
gsutil cp gs://${storage_bucket_name}/configs/forseti_conf_client.yaml ${forseti_client_conf_path}
