#!/bin/bash
PATH="/bin:/usr/bin:/usr/sbin"
set -e

#On installe les paquets prérequis à nagios
apt-get update
apt-get install -y autoconf gcc libc6 make wget unzip apache2 apache2-utils php libgd-dev openssl libssl-dev

#On télécharge la source depuis github
cd /tmp 
wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.14.tar.gz 
tar xzf nagioscore.tar.gz

#Ensuite on compile
#Conseils M2 pour vérifier et limiter les erreurs
if [[ $? -eq 0 && -d /tmp/nagioscore-nagios-4.4.14/  ]]; then
    # si le répertoire existe, alors on exécute les actions suivantes : 
    cd /tmp/nagioscore-nagios-4.4.14/ 
    ./configure --with-httpd-conf=/etc/apache2/sites-enabled 
    make all
else
    # on arrête le script proprement avec le code retour 1
    exit 1
fi

read -p "Nouvel utilisateur : " username
# on nettoie l'entrée utilisateur pour éviter les injections de commandes. on enlève les caractères spéciaux ici
username=$(echo "$username" | sed 's/[^A-Za-z0-9._-]//g')
groupadd nagios
useradd $username
gpasswd -a $username nagios

# boucle infinie jusqu'à ce que l'utilisateur envoie les deux mêmes mdp
while true; do
    read -s -p "Password pour le nouvel utilisateur (aucun retour visuel) : " password
    echo
    read -s -p "Confirmer : " confirmed
    echo

    if [[ $password == $confirmed ]]; then
        break
    else
        echo "Les mots de passe ne sont pas identiques."
    fi
done
echo "$username:$password" | chpasswd

#On installe des services
make install
make install-daemoninit
make install-commandmode
make install-config

#On installe ensuite un serveur apache
make install-webconf
a2enmod rewrite
a2enmod cgi

#On installe pour le firewall
iptables -I INPUT -p tcp --destination-port 80 -j ACCEPT
apt-get install -y iptables-persistent

#Maintenant on configure le compte nagiois user (mdp à définir)
htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin

#On allume le systeme
systemctl start nagios.service

#On vérifie le démarrage
if [[ $? -eq 0 ]]; then
    echo "Service démarrer correctement"
else
    echo "Impossible de démarrer le service"
fi
#Cette partie là permet d'installer les plugins, nous avions qu'installer le moteur nagios
apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
cd /tmp
wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.4.6.tar.gz
tar zxf nagios-plugins.tar.gz
cd /tmp/nagios-plugins-release-2.4.6/
./tools/setup
./configure
make
make install

systemctl restart nagios.service
systemctl status nagios.service