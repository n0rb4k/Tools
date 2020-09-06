#!/bin/bash

# Tittle: NmapAutomation
# Description: Tool for the OSCP exam, just to get easyly and faster nmap scans over the exam hosts.
# Author: Iván Solís

if [ $UID -ne 0 ]; then
  echo "[-] It should be executed as root"
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "[-] Please provide the file containing the hosts"
  exit 1
fi

# First we create all the folders to organise the next work
for host in $(cat $1); do
  mkdir $host
done
echo
for host in $(cat $1); do
  mkdir $host"/simple"
  echo "Scan: Simple without scripts/version"
  echo "Host: "$host
  echo "Command: nmap -Pn ${host} -oA ${host}/simple/simple"
  echo
  nmap -Pn $host -oA $host"/simple/simple"
  # Now it time to parse the opened ports to perform a thorough next scan
  simple_ports=$(grep -o -E "[0-9]{1,5}/open" $host"/simple/simple.gnmap" | tr -d "/open" | xargs -I {} echo -n {},)
  simple_ports=${simple_ports::-1} # Deleting the last ','
  echo
  echo
  echo

  mkdir $host"/simple-scans"
  echo "Scan: Simple with scripts/version"
  echo "Host: "$host
  echo "Command: nmap -Pn -sC -sV -p ${simple_ports} ${host} -oA ${host}/simple-scans"
  echo
  nmap -Pn -sC -sV -p $simple_ports $host -oA $host"/simple-scans/simple-scans"
  echo
  echo
  echo

  mkdir $host"/full"
  echo "Scan: Full without scripts/version"
  echo "Host: "$host
  echo "Command: nmap -Pn -p- ${host} -oA ${host}/full/full"
  echo
  nmap -Pn -p- $host -oA $host"/full/full"
  # Now it time to parse the opened ports to perform a thorough next scan
  full_ports=$(grep -o -E "[0-9]{1,5}/open" $host"/full/full.gnmap" | tr -d "/open" | xargs -I {} echo -n {},)
  full_ports=${full_ports::-1} # Deleting the last ','
  echo
  echo
  echo

  mkdir $host"/full-scripts"
  echo "Scan: Full with scripts/version"
  echo "Host: "$host
  echo "Command: nmap -Pn -p ${full_ports} ${host} -oA ${host}/full-scripts/full-scripts"
  echo
  nmap -Pn -sC -sV -p $full_ports $host -oA $host"/full-scripts/full-scripts"
  echo
  echo
  echo

  mkdir $host"/os-detection"
  echo "Scan: OS Detection"
  echo "Host: "$host
  echo "Command: nmap -Pn -O ${host} -oN ${host}/os-detection/os-detection"
  echo
  nmap -Pn -O $host -oN $host"/os-detection/os-detection"
  echo
  echo
  echo

  mkdir $host"/udp"
  echo "Scan: UDP protocol"
  echo "Host: "$host
  echo "Command: nmap -Pn -sU ${host} -oN ${host}/udp/udp"
  nmap -Pn -sU $host -oN $host"/udp/udp"
  echo
done

# In order to get only the more relevant information, we're deleting all the files .gnmap and .xml
find . -name "*.gnmap" -exec rm {} \;
find . -name "*.xml" -exec rm {} \;
