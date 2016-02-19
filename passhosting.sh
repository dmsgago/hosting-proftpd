#!/bin/bash

# Recibe un nombre de usuario y un parámetro que\
# identifica la contraseña que quiere reestablecer el\
# cliente.

# Realizado por: Diego Martín Sánchez @diego_mart11

#############
# Funciones #
#############

# Comprueba que el número de argumentos es válido.
num_argumentos ()
{
    if ! [ $1 == "2" ]
    then
	echo [ERROR] Numero de argumentos invalido: $1
	exit
    fi
}

# Comprueba que el usuario pasado como argumento es\
# un usuario válido.
check_usuario ()
{
    find=$(ldapsearch -Y EXTERNAL -H ldapi:/// -Q -D "cn=admin,dc=tuweb,dc=com" -b "ou=people,dc=tuweb,dc=com" "uid=$1"|grep numEntries: |grep -oe '[0-9]')
    if [[ $find -eq "0" ]]
    then
	echo El usuario no existe: $1
	exit
    fi
}

# Verifica la contraseña que el usuario desea\
# actualizar y lleva a cabo el cambio.
change_pass ()
{
    if [ $2 == "-sql" ]
    then
	read -p "Introduce la nueva contraseña: " -s pass
        echo -e "SET PASSWORD FOR my$1 = PASSWORD('$pass');" > /tmp/pass.sql
	echo
	mysql -u root -p < /tmp/pass.sql
	echo [OK] Contraseña MySQL cambiada.
    elif [ $2 == "-ftp" ]
    then
	ldappasswd -H ldapi:/// -x -D "cn=admin,dc=tuweb,dc=com" -S "uid=$1,ou=people,dc=tuweb,dc=com" -w ADMINPASSWORD
	echo [OK] Contraseña FTP cambiada.
    else
	echo Parametro invalido: $2
    fi
}

# Proceso principal
num_argumentos $#
check_usuario $1
change_pass $1 $2
