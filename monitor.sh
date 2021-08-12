#!/bin/bash

# Inicializar arquivos e variáveis
touch /tmp/sendmail.txt;
RECIPIENT=$1
SENDER=$2
SIGNATURE=$3

Usage(){

cat << EOF

Monitor blocking of new IPs in fail2ban. Usable only on Zimbra or server with postfix email.

Usage:

bash monitor.sh RECIPIENT SENDER "SIGNATURE"

Example:

bash monitor.sh teste@dominio.com.br root@hostname.com.br "Your love."

EOF

}

if [[ -z ${RECIPIENT} ]] || [[ -z ${SENDER} ]] || [[ -z ${SIGNATURE} ]]; then
   Usage;
   exit 2;
fi;

# Verifica se a lista de IPs bloqueados existe
if [ -e /tmp/ips_atuais.txt ]; then
	echo "Arquivo existe. Validando se a lista de IPs não está vazia...";
	count=$(cat /tmp/ips_atuais.txt | egrep "*" | wc -l);
	if [ $count -eq 0 ]; then
		echo "Arquivo de IPs está vazio. Inicializando nova contagem de IPs";
		iptables -S | grep DROP | awk '{ print $4 }' >> /tmp/ips_atuais.txt;
	fi;
else
	echo "Arquivo não existe, reset de IPs efetuados. Inicializando nova contagem de IPs";
	iptables -S | grep DROP | awk '{ print $4 }' >> /tmp/ips_atuais.txt;
fi;

# Verifica se houve novos bloqueios
count_ips=$(iptables -S | grep DROP | awk '{ print $4 }' | egrep -v "$(cat /tmp/ips_atuais.txt | paste -sd'|')" | wc -l)

if [ $count_ips -eq 0 ]; then
	echo -e "Não houve novos bloqueios de IP em sua estrutura.\n\nAtenciosamente,\n$SIGNATURE" >> /tmp/sendmail.txt;
else
	echo -e "Segue IPs bloqueados em sua estrutura:\n" >> /tmp/sendmail.txt;
	iptables -S | grep DROP | awk '{ print $4 }' | egrep -v "$(cat /tmp/ips_atuais.txt | paste -sd'|')" | tee -a /tmp/ips_atuais.txt >> /tmp/sendmail.txt;
	echo -e "\nAtenciosamente,\n$SIGNATURE" >> /tmp/sendmail.txt;
fi;

cat <<EOF | /opt/zimbra/common/sbin/sendmail -i $RECIPIENT 
Subject: Monitoramento de bloqueio de IPs
From: Monitoracao $(hostname) <$SENDER>
To: $RECIPIENT

Prezados,

$(cat /tmp/sendmail.txt && rm -f /tmp/sendmail.txt)

EOF
