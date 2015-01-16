#!/bin/sh
#By:Zz0
#zz0@garagemhacker.org
#19/08/2014
#version:0.1
#This script has the objective to update iptables rules for ddns users.
#If you need to insert dynamic hosts on your firewall rules this is made for U
#Just change the global vars for your necessit, and enjoy ;)

#---------------
###GLOBAL VARS###
#---------------

#Begin of the clients

client[0]="somehost.sytes.net"
client[1]="anotherhost.ddns.net"
client[2]="onemoresample.ddns.net"

#Change "xxx" to the ip of Destination NAT
#Sample: acessos[0]="192.168.1.253"
acessos[0]="xxx.xxx.xxx.xxx"

#End of the clients

#iptables vars
#Port of incoming connection
#Like ts sample must be like: inport[0]="3389"
inport[0]="0000"

IP=/usr/sbin/iptables
SAVE=/usr/sbin/iptables-save

#Change this for your WAN port
PPP=ppp0
#----------------------
###DONT CHANGE AHEAD###
#----------------------

dynamicfile="/tmp/dynamicfir0"
newipfile="/tmp/newipfile0"
oldipfile="/tmp/oldipfile0"
oldipfileb="/tmp/oldipfile1"
array=0

myip(){
	while [ $array != ${#client[@]} ]
	do
		host -4 ${client[$array]}|cut -d' ' -f4
		let "array=$array + 1"
	done

} 

makefiles(){
	if [ ! -e "$dynamicfile" ]
	then
		myip > "$dynamicfile"
	else
		myip > "$newipfile"
	fi
}

oldip(){
	if [ ! -e "$oldipfile" ]
	then
		makefiles
	fi
	diff -u "$dynamicfile" "$newipfile" > "$oldipfile"
	grep '^-[0-9]' "$oldipfile"|cut -c2- > "$oldipfileb"
	mv -f "$oldipfileb" "$oldipfile"
	
}	

insert_ts_nat(){
	while read ips
	do
		$IP -t nat -A PREROUTING -i $PPP -s $ips -p tcp --dport ${inport[0]} -j DNAT --to ${acessos[0]} 
	done < "$dynamicfile"
}

remove_ts_nat(){
	while read oldips
	do
		$IP -t nat -D PREROUTING -i $PPP -s $oldips -p tcp --dport ${inport[0]} -j DNAT --to ${acessos[0]} 
	done < "$oldipfile"
}

fir_compare(){
	while read validos
	do
		"$SAVE"|grep "$validos"
		if [ $? -eq 0 ]
		then
			echo "$validos ja esta cadastrado"
			continue
		else
			insert_ts_nat
		fi
	done < "$dynamicfile"

}	


#-----------------
### rc-section ####
#-----------------
if [ ! -e "$dynamicfile" ]
then
	makefiles
else
	oldip
fi

if [ -s "$oldipfile" ]
then
	remove_ts_nat
	mv "$newipfile" "$dynamicfile"
	rm -rf "$oldipfile"
	fir_compare
	echo "Os arquivos mudaram, atualizei regras"
else
	rm -rf "$oldipfile"
	rm -rf "$newipfile"
	fir_compare
	echo "Os IP's nao mudaram, nao farei nada"
fi





