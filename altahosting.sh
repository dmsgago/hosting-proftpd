#!/bin/bash

# Recibe un nombre de usuario y un nombre de dominio\
# para darlos de alta en el servicio de Hosting.

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
    echo COMPROBANDO USUARIO...
    find=$(ldapsearch -Y EXTERNAL -H ldapi:/// -Q -b "ou=people,dc=example,dc=com" "uid=$1"|grep numEntries: |grep -oe '[0-9]')
    domain=$(ldapsearch -Y EXTERNAL -H ldapi:/// -Q -b "ou=people,dc=example,dc=com" "o=$2"|grep numEntries: |grep -oe '[0-9]')
    if [[ $find -eq "1" ]]
    then
	echo [ERROR] El usuario existe: $1
	exit
    elif [[ $domain -eq "1" ]]
    then
	echo [ERROR] El dominio ya ha sido registrado: $2
	exit
    fi
    echo -e "[OK]\n"
}

# Modifica un fichero plantilla, para crear el nuevo\
# usuario y su grupo en el LDAP.
alta ()
{
    echo CREANDO EL USUARIO...
    # Almacena el en una variables el identificador\
    # que deberá tener el siguiente usuario creado
    id=$(expr $(ldapsearch -Y EXTERNAL -H ldapi:/// -Q -D "cn=admin,dc=example,dc=com" -b "ou=people,dc=example,dc=com" "uid=*"|grep numEntries|awk '{print $3}') + 2001)
    echo Password: $3
    # Añade el grupo del usuario al LDAP
    cp /etc/ldap/slapd.d/grupo.ldif /tmp/group-template.ldif
    sed -i 's/<username>/'"$1"'/g' /tmp/group-template.ldif
    sed -i 's/<gid>/'"$id"'/g' /tmp/group-template.ldif
    ldapadd -D "cn=admin,dc=example,dc=com" -w ADMINPASSWORD -f /tmp/group-template.ldif
    
    # Añade al nuevo usuario al LDAP
    userpass=$(slappasswd -s $3)
    cp /etc/ldap/slapd.d/usuario.ldif /tmp/user-template.ldif
    sed -i 's/<username>/'"$1"'/g' /tmp/user-template.ldif
    sed -i 's/<dominio>/'"$2"'/g' /tmp/user-template.ldif
    sed -i 's%<password>%'"$userpass"'%g' /tmp/user-template.ldif
    sed -i 's/<uid>/'"$id"'/g' /tmp/user-template.ldif
    sed -i 's/<gid>/'"$id"'/g' /tmp/user-template.ldif
    ldapadd -D "cn=admin,dc=example,dc=com" -w ADMINPASSWORD -f /tmp/user-template.ldif
    echo -e "[OK]\n"
}

# Crea el directorio del nuevo usuario y copia la\
# plantilla html que se mostrará por defecto en el\
# hosting.
directorio ()
{
    echo CREANDO EL DIRECTORIO DEL USUARIO...
    mkdir /home/$1
    cp -r /opt/web/* /home/$1
    chown -R $1:$1 /home/$1
    echo -e "[OK]\n"
}

# Crea el virtualhosting para el sitio web del usuario.
virtualhosting ()
{
    echo CREANDO EL VIRTUAL HOSTING...
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$1.conf
    sed -i 's%/var/www/html%/home/'"$1"'\n        ServerName www.'"$2"'\n        ErrorLog ${APACHE_LOG_DIR}/'"$1"'_error.log\n        CustomLog ${APACHE_LOG_DIR}/'"$1"'_access.log combined%g' /etc/apache2/sites-available/$1.conf
    a2ensite $1.conf
    systemctl restart apache2
    echo -e "[OK]\n"
}

# Crea el usuario y la base de datos que se le servirá\
# al cliente. Además se creará un virtualhosting para\
# PhpMyAdmin, que permitirá al usuario administrar\
# mediante un panel web su base de datos.
basededatos ()
{
    echo ALTA EN LA BASE DE DATOS...
    mypass=$(makepasswd --char 8)
    echo Usuario MySQL: my$1
    echo Password MySQL: $mypass
    echo -e "CREATE USER my$1 IDENTIFIED BY \"$mypass\";\nCREATE DATABASE my$1;\nGRANT ALL PRIVILEGES ON my$1.* TO my$1;" > /tmp/newuser.sql
    mysql -u root -p < /tmp/newuser.sql
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$1my.conf
    sed -i 's%/var/www/html%/usr/share/phpmyadmin/\n        ServerName mysql.'"$2"'\n        ErrorLog ${APACHE_LOG_DIR}/my'"$1"'_error.log\n        CustomLog ${APACHE_LOG_DIR}/my'"$1"'_access.log combined%g' /etc/apache2/sites-available/$1my.conf
    a2ensite $1my.conf
    systemctl restart apache2
    echo -e "[OK]\n"
}

# Da de alta al dominio en el servidor DNS
dns ()
{
    echo CREANDO REGISTROS EN EL DNS...
    echo -e "zone \"$2\" {\n    type master;\n    file \"db.$2\";\n};" >> /etc/bind/named.conf.local
    cp /etc/bind/db.empty /var/cache/bind/db.$2
    sed -i 's/localhost/server.'"$2"'/g' /var/cache/bind/db.$2
    echo -e "server IN A 172.22.203.25\nmysql IN CNAME server\nftp IN CNAME server\nwww IN CNAME server" >> /var/cache/bind/db.$2
    systemctl restart bind9
    echo -e "[OK]\n"
}

#####################
# Proceso principal #
#####################
num_argumentos $#
check_usuario $1 $2
pass=$(makepasswd --char 8)
alta $1 $2 $pass
directorio $1
virtualhosting $1 $2
basededatos $1 $2
dns $1 $2
