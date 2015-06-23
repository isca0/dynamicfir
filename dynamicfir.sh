#!/bin/sh
#by:isca0 igorsca at gmail
#version: 0.3
conf="/etc/dynamicfir.conf"
current="/tmp/currentchain0"
apply="/tmp/apply0"
newchain="/tmp/newchain0"
oldchain="/tmp/oldchain0"
changes="/tmp/changesfile0"
ipfile="/tmp/ipfile0"
validhost="/tmp/validhost0"

IP=/usr/sbin/iptables
SAVE=/usr/sbin/iptables-save
WAN=ppp0


limpazona(){
rm -rf $apply >/dev/null 2>&1
rm -rf $newchain >/dev/null 2>&1
rm -rf $oldchain >/dev/null 2>&1
rm -rf $changes >/dev/null 2>&1
rm -rf $ipfile >/dev/null 2>&1
rm -rf $validhost >/dev/null 2>&1
}


validport(){
porta=$1
if expr 1 + $porta  >/dev/null 2>&1
then
	if [[ $porta -le 0 || $porta -gt 65535 ]]
	then
		echo "porta invalida"
		continue
	fi
elif [[ "$porta" == '\ ' || "$porta" == "" || "$porta" == " " ]]
then
	:	
else
	continue
fi

}

validhost(){
ipv4=$1
#Oq normalmente o pessoal testa eh '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'
# mas para esse caso se colocar um ip 999.999.999.999 que nao eh um ip valido
#aquela primeira validacao passaria. Oq seria um problema.
#com isso eu estou usando essa nova regex que consigo testar somente ips validos incluindo broadcast
if [[ $1 =~ ^[a-z] ]]
then
        host -4 $1|cut -d' ' -f4 > $ipfile
	cp $ipfile $validhost
else
        echo $ipv4 > $ipfile
fi
grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" $ipfile >/dev/null 2>&1
if [ $? -ne 0 ]
then
        echo "Endereco de IP \"$ipv4\" invalido para a regra: $host $inport $ip $outport"
        continue
fi
}

convert(){
grep -v '^[#]' "$conf" > "$apply"
if [ -s $apply ] #Se o apply nao estiver vazio
then
	while IFS=, read host inport ip outport
	do
		validhost $host
		validport $inport
		validhost $ip
		validport $outport
		echo "`cat $validhost`,$inport,$ip,$outport" >> $newchain
	
	done < $apply
else
	echo "Nao existem regras para serem processadas em $conf"
	limpazona
	exit
fi
}

compare(){
if [[ -e $current ]] 
then

	if [ -e $newchain ]
	then
		diff -u $current $newchain > $changes #Crie um patch com a diferenca entre eles
		if [ -s $changes ] #Se o changes nao estiver vazio
		then
			grep ^-[0-9] $changes|cut -c2-  > $oldchain #Pegue todas as entradas que sairam e coloque no oldchain
			grep ^+[0-9] $changes|cut -c2-  > $newchain #Pegue todas as novas entradas e coloque no newchain
			#echo "mostrando o current" #Use para debug
			#cat $current #use para debug
			#echo "mostrando o changes" #debug
			#cat $changes #debug
			patch $current < $changes #Aplique no current chain as mudancas
			#echo "mostrando como ficou" #debug
			#cat $current #debug
		else
			echo "Sem alteracoes"
			limpazona
			exit 
		fi
	fi
else
	insert
	mv $newchain $current
	limpazona
	exit

fi
}

insert(){
if [ -s $newchain ] #Se o newchain nao estive vazio
then
	while IFS=, read host inport ip outport
	do
		if [[ "$outport" == '\ ' || "$outport" == " " || "$outport" == "" ]]
		then
			#"$SAVE"|grep -in "$host.*$inport.*$ip" #Procurando varias palavras na mesma linha
			"$SAVE"|grep -E '$host.*$inport.*$ip' #Procurando varias palavras na mesma linha
			if [ $? -eq 0 ]
			then
				echo "esta regra ja foi adcionada"	
				echo "-t nat -A PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip"
				continue
			else	
				echo "Adcionando regra A"
				echo "-t nat -A PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip"
				$IP -t nat -A PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip
			fi
		else

			#"$SAVE"|grep -in "$host.*$inport.*$ip.$outport" #Procurando varias palavras na mesma linha
			"$SAVE"|grep -E '$host.*$inport.*$ip.$outport' #Procurando varias palavras na mesma linha
			if [ $? -eq 0 ]
			then
				echo "esta regra ja foi adcionada"	
				echo "-t nat -A PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip:$outport"
				continue
			else	
				echo "Adcionando regra B"
				echo "-t nat -A PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip:$outport"
				$IP -t nat -A PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip:$outport
			fi
		fi
	
	done < $newchain
fi
}

remove(){
if [ -s $oldchain ] #se oldchain nao estiver vazio
then
	while IFS=, read host inport ip outport
	do
		if [[ "$outport" == '\ ' || "$outport" == " " || "$outport" == "" ]]
		then
			echo "Removendo regra A"
			echo "-t nat -D PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip"
			"$IP" -t nat -D PREROUTING -s "$host" -i "$WAN" -p tcp --dport "$inport" -j DNAT --to "$ip"
		else

			echo "Removendo regra B"
			echo "-t nat -D PREROUTING -s $host -i $WAN -p tcp --dport $inport -j DNAT --to $ip:$outport"
			"$IP" -t nat -D PREROUTING -s "$host" -i "$WAN" -p tcp --dport "$inport" -j DNAT --to "$ip":"$outport"
		fi

	done < $oldchain
fi
}

first_run(){
if [ ! -e $conf ]
then
	echo "arquivo $conf nao foi encontrado" 
	read -p "Deseja criar o arquivo $conf? (S/n): " ask
	if [[ "$ask" == s || "$ask" == S ]]
	then
		echo "#This file requires the parameters separated by colum" > $conf
		echo "#DYNAMIC_HOST,SOURCE_PORT,DEST_IP,DEST_PORT" >> $conf
		echo "#myhost.ddns.net,3389,192.168.1.222,3389" >> $conf
		echo "Arquivo $conf criado com sucesso, leia as instrucoes para prosseguir"
		exit
	fi
fi
}

case "$1" in
-a)
MINPAR=4
if [ $# -lt "$MINPAR" ]
then
	echo "Ops... falta de parametros...
#ex.: $0 -a fulano.ddns.net 3389 192.168.1.254
"
	exit
fi
echo $2 $3 $4 $5
;;
-r)
;;
-z)
limpazona
rm -rf $current >/dev/null 2>&1
;;
-x)
$0 -z
rm -rf $conf >/dev/null 2>&1
;;
-s)
first_run
convert
compare
remove
insert
limpazona
;;
esac
