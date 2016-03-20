#!/bin/bash

# Configuración de colores
resaltado="\033[43m\033[30m"
verde="\033[33m"
normal="\033[40m\033[37m"


# Escribir el título en colores
function write_title() {
    echo " "
    echo -e "$resaltado $1 $normal"
    say_continue
}


# Mostrar mensaje "Done."
function say_done() {
    echo " "
    echo -e "$verde Done. $normal"
    say_continue
}


# Preguntar para continuar
function say_continue() {
    echo -n " Para SALIR, pulse la tecla x; sino, pulse ENTER para continuar..."
    read acc
    if [ "$acc" == "x" ]; then
        exit
    fi
    echo " "
}


# Obtener la IP del servidor
function __get_ip() {
    serverip=`ifconfig enp0s3 | grep -e "inet " | cut -d: -f2 | awk '{ print $2 }'`
    echo $serverip
}


# Copiar archivos de configuración locales
function tunning() {
    whoapp=$1
    cp templates/$whoapp /root/.$whoapp
    cp templates/$whoapp /home/$username/.$whoapp
    chown $username:$username /home/$username/.$whoapp
    say_done
}



