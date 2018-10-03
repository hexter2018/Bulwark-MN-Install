#!/bin/bash

# Make installer interactive and select normal mode by default.
INTERACTIVE="y"
ADVANCED="n"
I2PREADY="n"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--advanced)
    ADVANCED="y"
    shift
    ;;
    -n|--normal)
    ADVANCED="n"
    FAIL2BAN="y"
    UFW="y"
    BOOTSTRAP="y"
    shift
    ;;
    -i|--externalip)
    EXTERNALIP="$2"
    ARGUMENTIP="y"
    shift
    shift
    ;;
    --bindip)
    BINDIP="$2"
    shift
    shift
    ;;
    -k|--privatekey)
    KEY="$2"
    shift
    shift
    ;;
    -f|--fail2ban)
    FAIL2BAN="y"
    shift
    ;;
    --no-fail2ban)
    FAIL2BAN="n"
    shift
    ;;
    -u|--ufw)
    UFW="y"
    shift
    ;;
    --no-ufw)
    UFW="n"
    shift
    ;;
    -b|--bootstrap)
    BOOTSTRAP="y"
    shift
    ;;
    --no-bootstrap)
    BOOTSTRAP="n"
    shift
    ;;
    --no-interaction)
    INTERACTIVE="n"
    shift
    ;;
    -h|--help)
    cat << EOL

Bulwark Masternode installer arguments:

    -n --normal               : Run installer in normal mode
    -a --advanced             : Run installer in advanced mode
    -i --externalip <address> : Public IP address of VPS
    --bindip <address>        : Internal bind IP to use
    -k --privatekey <key>     : Private key to use
    -f --fail2ban             : Install Fail2Ban
    --no-fail2ban             : Do nott install Fail2Ban
    -u --ufw                  : Install UFW
    --no-ufw                  : Do not install UFW
    -b --bootstrap            : Sync node using Bootstrap
    --no-bootstrap            : Do not use Bootstrap
    -h --help                 : Display this help text.
    --no-interaction          : Do not wait for wallet activation.


EOL
    exit
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

clear

# Make sure curl is installed
apt-get update
apt-get install -qqy curl
clear

# These should automatically find the latest version of Bulwark

TARBALLURL=$(curl -s https://api.github.com/repos/parkingcrypto/parking/releases/latest | grep browser_download_url | grep -e "parkingd" | cut -d '"' -f 4)
TARBALLNAME=$(curl -s https://api.github.com/repos/parkingcrypto/parking/releases/latest | grep browser_download_url | grep -e "parkingd" | cut -d '"' -f 4 | cut -d "/" -f 9)
#BOOTSTRAPURL=$(curl -s https://api.github.com/repos/bulwark-crypto/bulwark/releases/latest | grep bootstrap.dat.xz | grep browser_download_url | cut -d '"' -f 4)
#BOOTSTRAPARCHIVE="bootstrap.dat.xz"


#!/bin/bash

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ $(free -m | awk '/^Mem:/{print $2}') -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# TODO: Uncomment once we release I2P
# Check if I2P is an option
# if [[ $(free -m | awk '/^Mem:/{print $2}') -gt 1700 ]]; then
#   I2PREADY="y"
# fi

# Check if we have enough disk space
#if [[ $(df -k --output=avail / | tail -n1) -lt 10485760 ]]; then
  #echo "This installation requires at least 10GB of free disk space.";
  #exit 1
#fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# Get our current IP
if [ -z "$EXTERNALIP" ]; then
EXTERNALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
fi
clear

if [[ $INTERACTIVE = "y" ]]; then
echo "
    ___T_
   | o o |
   |__-__|
   /| []|\\\\
 ()/|___|\\()
    |_|_|
    /_|_\\  ------- MASTERNODE INSTALLER v4 -------+
 |                                                  |
 |   Welcome to the Parking Masternode Installer!   |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::

"

sleep 3
fi

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=parking

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

INSTALLERUSED="#Used Advanced Install"

echo "" && echo 'Added user "parking"' && echo ""
sleep 1

else

USER=root

if [ -z "$FAIL2BAN" ]; then
  FAIL2BAN="y"
fi
if [ -z "$UFW" ]; then
  UFW="y"
fi
if [ -z "$BOOTSTRAP" ]; then
  BOOTSTRAP="y"
fi
INSTALLERUSED="#Used Basic Install"
fi

USERHOME=$(eval echo "~$USER")

if [ -z "$ARGUMENTIP" ]; then
  read -erp "Server IP Address: " -i "$EXTERNALIP" -e EXTERNALIP
fi

if [ -z "$BINDIP" ]; then
    BINDIP=$EXTERNALIP;
fi

if [ -z "$KEY" ]; then
  read -erp "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
fi

if [ -z "$FAIL2BAN" ]; then
  read -erp "Install Fail2ban? [Y/n] : " FAIL2BAN
fi

if [ -z "$UFW" ]; then
  read -erp "Install UFW and configure ports? [Y/n] : " UFW
fi

if [ -z "$BOOTSTRAP" ]; then
  read -erp "Do you want to use our bootstrap file to speed the syncing process? [Y/n] : " BOOTSTRAP
fi

# Generate random passwords
RPCUSER=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop xz-utils
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  # Reduce Fail2Ban memory usage - http://hacksnsnacks.com/snippets/reduce-fail2ban-memory-usage/
  echo "ulimit -s 256" | sudo tee -a /etc/default/fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 47777/tcp
  yes | ufw enable
fi

# Install Parking daemon
wget "$TARBALLURL"
#tar -xzvf "$TARBALLNAME" -C /usr/local/bin
unzip parkingd.zip
rm parkingd.zip
mv parking* /usr/local/bin

# Create .parkingcore directory
mkdir "$USERHOME/.parkingcore"

# Install bootstrap file
#if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
  #echo "Installing bootstrap file..."
  #wget "$BOOTSTRAPURL" && xz -cd $BOOTSTRAPARCHIVE > "$USERHOME/.parkingcore/bootstrap.dat" && rm $BOOTSTRAPARCHIVE
#fi

# Create parking.conf
touch "$USERHOME/.parkingcore/parking.conf"

cat > "$USERHOME/.parkingcore/parking.conf" << EOL
${INSTALLERUSED}
bind=${BINDIP}:47777
daemon=1
externalip=${EXTERNALIP}
listen=1
logtimestamps=1
masternode=1
masternodeaddr=${EXTERNALIP}
masternodeprivkey=${KEY}
maxconnections=256
rpcallowip=127.0.0.1
rpcpassword=${RPCPASSWORD}
rpcuser=${RPCUSER}
server=1
EOL
fi
chmod 0600 "$USERHOME/.parkingcore/parking.conf"
chown -R $USER:$USER "$USERHOME/.parkingcore"

sleep 1

cat > /etc/systemd/system/parkingd.service << EOL
[Unit]
Description=Bulwarks's distributed currency daemon
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/parkingd -conf=${USERHOME}/.parkingcore/parking.conf -datadir=${USERHOME}/.parkingcore
ExecStop=/usr/local/bin/parking-cli -conf=${USERHOME}/.parkingcore/parking.conf -datadir=${USERHOME}/.parkingcore stop
Restart=on-failure
RestartSec=1m
StartLimitIntervalSec=5m
StartLimitInterval=5m
StartLimitBurst=3
[Install]
WantedBy=multi-user.target
EOL
systemctl enable parkingd
echo "Starting parkingd..."
systemctl start parkingd

sleep 10

if ! systemctl status parkingd | grep -q "active (running)"; then
  echo "ERROR: Failed to start parkingd. Please contact support."
  exit
fi

echo "Waiting for wallet to load..."
until su -c "parking-cli getinfo 2>/dev/null | grep -q \"version\"" $USER; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."

echo ""

until su -c "parking-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\": true' > /dev/null" "$USER"; do 
  echo -ne "Current block: $(su -c "parking-cli getblockcount" "$USER")\\r"
  sleep 1
done

clear

cat << EOL

Now, you need to start your masternode. If you haven't already, please add this
node to your masternode.conf now, restart and unlock your desktop wallet, go to
the Masternodes tab, select your new node and click "Start Alias."

EOL


if [[ $INTERACTIVE = "y" ]]; then
  read -rp "Press Enter to continue after you've done that. " -n1 -s
fi

clear

sleep 1
su -c "/usr/local/bin/parking-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/parking-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." 

echo ""
