#!/bin/bash
# This script has been created to easily get domains related with certain BB scope
# The final output is a detailed EyeWitness report

FILE="$1"
USER_AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36'
SUBLIST3R_PATH='/opt/Sublist3r/sublist3r.py'

# Veryfing the arguments
[ $# -ne 1 ] && echo "Usage: ./getAssets.sh [file]"

# Veryfing if file exists
ls "$1" > /dev/null 2>&1 || (echo "The file doesn't exist!" && exit 1)

# Veryfing if Sublist3r is found
ls "$SUBLIST3R_PATH" > /dev/null 2>&1 || (echo "The Sublist3r tool is not found, please check 'SUBLIST3R_PATH' variable!" && exit 1)

# Removing previous output if any
echo '[+] Cleaning previous output'
rm -rf screenshots 2>/dev/null
rm assets.gnmap 2>/dev/null

# Starting the subdomains enumeration with Sublist3r
# We'll only discover new subdomains in all those lines in the file entered that contains the following pattern:
#      *.domain.com
grep -E '^\*\.' $FILE | sed 's/^\*\.//g' > /tmp/getassets_bb_sublist3rinput.tmp
echo "[+] Detected $(grep -E '^\*\.' $FILE | wc -l) domains with wildcard"

echo "[+] Starting Sublist3r execution for $(cat $FILE | wc -l) domains"
while read domain; do 
	# Getting subdomains
	python3 $SUBLIST3R_PATH -d $domain -t 10 -o /tmp/getassets_bb_sublist3r_output_tmp > /dev/null 2>&1
	cat /tmp/getassets_bb_sublist3r_output_tmp >> /tmp/getassets_bb_sublist3r_output
done < /tmp/getassets_bb_sublist3rinput.tmp

# Adding the domains without wildcard and remvoving duplicates
grep -E '^[^*]' $FILE >> /tmp/getassets_bb_sublist3r_output
sort -u /tmp/getassets_bb_sublist3r_output > /tmp/getassets_bb_sublist3r_final

# Getting DNS registers in order to send them to nmap
while read domain; do
	dig +short "$domain" | 	while read register; do 
		echo "$domain $register" >> /tmp/getassets_bb_assets.tmp
	done
done < /tmp/getassets_bb_sublist3r_final

echo "[+] Found a total of $(sort -u /tmp/getassets_bb_assets.tmp | wc -l) assets"
echo "[+] Total of unique IP/hostnames: $(cat /tmp/getassets_bb_assets.tmp | awk -F' ' '{print $2}' | sort -u | wc -l)"

# Getting the opened ports with Nmap
echo '[+] Starting the nmap service enumeration'
nmap -iL <(sort -u /tmp/getassets_bb_assets.tmp) -p80,443,8080,8443,4443,10000 --open -Pn -oX /tmp/getassets_bb_nmapassets.xml -oG assets.gnmap > /dev/null 2>&1

# Removing unwanted lines
sort -u assets.gnmap | grep -vE '^#' | grep -v 'Status: Up' > tmp && mv tmp assets.gnmap

# Adding Scope asset to the Gnmap output
while read line; do 
	asset=$(echo $line | awk -F' ' '{print $2}')
	scope=$(cat /tmp/getassets_bb_assets.tmp | grep -m1 $asset | awk -F' ' '{print $1}')
	ports=$(echo $line | grep -oE 'Ports:.*$')
	echo "Scope: $scope | Host: $asset | $ports" 
done < assets.gnmap | sort -u > tmp && mv tmp assets.gnmap

echo '[+] Done! Generated the "assets.gnmap" to easily search for assets'
echo "[+] There are $(sort -u assets.gnmap | wc -l) diferent hosts"

# Starting the screenshots taking with EyeWitness
echo '[+] Starting the EyeWitness screenshots taking for websites'
mkdir screenshots 2>/dev/null

scanned=()

# Looping into the results to take screenshots
while read line; do
	ports_https=()
	ports_http=()

	IFS='|' read scope asset ports <<< $line
	scope_eyewitness=$(echo "$scope" | awk -F' ' '{print $2}')

	# Checking if the domain has been already scanned
	echo "${scanned[@]}" | grep -q "$scope_eyewitness"
	if [ $? -eq 0 ]; then
		continue
	fi

	for port in "$(echo $ports | sed 's/Ports: //g')"; do 
		port_num=$(echo $port | awk -F'/' '{print $1}')
		echo "$port" | grep -q 'https'
		if [ $? -eq 0 ]; then 
			ports_https+=("$port_num")
		else
			ports_http+=("$port_num")
		fi
	done

	# Taking screenshots for HTTP ports
	for port_http in ${ports_http[@]}; do
		echo "http://$scope_eyewitness:$port_http" >> /tmp/getassets_bb_eyewitness_input.txt
	done
	# Taking screenshots for HTTPS ports
	for port_https in ${ports_https[@]}; do
		echo "https://$scope_eyewitness:$port_https" >> /tmp/getassets_bb_eyewitness_input.txt
	done

	# Adding the domain to the scanned list
	scanned+=("$scope_eyewitness")

done < <(grep 'http' assets.gnmap)

python3 /opt/EyeWitness/Python/EyeWitness.py \
	-f /tmp/getassets_bb_eyewitness_input.txt \
	--results 10000 \
	--web \
	-d screenshots \
	--no-prompt \
	--user-agent "$USER_AGENT" > /dev/null 2>&1

echo '[+] Removing temporals'
rm /tmp/getassets_bb_* 2> /dev/null

exit 0
