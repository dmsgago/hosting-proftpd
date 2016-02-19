#!/bin/bash

# Recibe un nombre de usuario y un nombre de dominio\
# para darlos de baja en el servicio de Hosting.

# Realizado por: Diego Martín Sánchez @diego_mart11

#############
# Funciones #
#############

# Verifica que el número de argumentos pasados al\
# script sean 2.
num_argumentos ()
{
    if ! [ $1 == "2" ]
    then
	echo [ERROR] Numero de argumentos invalido: $1
	exit
    fi
}

# Comprueba si existe el usuario o el dominio pasado\
# por argumento.
check_usuario ()
{
    find=$(ldapsearch -Y EXTERNAL -H ldapi:/// -Q -D "cn=admin,dc=tuweb,dc=com" -b "ou=people,dc=tuweb,dc=com" "uid=$1"|grep numEntries: |grep -oe '[0-9]')
    domain=$(ldapsearch -Y EXTERNAL -H ldapi:/// -Q -D "cn=admin,dc=tuweb,dc=com" -b "ou=people,dc=tuweb,dc=com" "o=$2"|grep numEntries: |grep -oe '[0-9]')
    if [[ $find -eq "0" ]]
    then
	echo El usuario no existe: $1
	exit
    elif [[ $domain -eq "0" ]]
    then
	echo El dominio no ha sido registrado: $2
	exit
    fi
}

# Elimina al usuario y su grupo del servidor LDAP.
baja ()
{
    ldapdelete -D "cn=admin,dc=tuweb,dc=com" "uid=$1,ou=people,dc=tuweb,dc=com" -w ADMINPASSWORD
    ldapdelete -D "cn=admin,dc=tuweb,dc=com" "cn=$1,ou=group,dc=tuweb,dc=com" -w ADMINPASSWORD
}

# Elimina los sitios virtuales del usuario.
apache ()
{
    a2dissite $1.conf $1my.conf
    rm /etc/apache2/sites-available/$1.conf
    rm /etc/apache2/sites-available/$1my.conf
    systemctl restart apache2
}

# Elimina el usuario y la base de datos de MySQL.
database ()
{
    echo -e "DROP DATABASE my$1;\nDROP USER my$1;" > /tmp/dropmysql.sql
    mysql -u root -p < /tmp/dropmysql.sql
}

# Elimina la zona del dominio contratado por el\
# usuario.
dns ()
{
    sed -i '/zone \"'"$1"'\"/,/};/d' /etc/bind/named.conf.local
    rm /var/cache/bind/db.$1
    systemctl restart bind9
}

# Proceso principal
num_argumentos $#
check_usuario $1 $2
baja $1
rm -rf /home/$1
apache $1
database $1
dns $2
