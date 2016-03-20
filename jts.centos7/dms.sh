#!/bin/bash
# JackTheStripper v2.0
# Deployer for Linux CentOS 7
# 
# @license               http://www.gnu.org/licenses/gpl.txt  GNU GPL 3.0
# @author                Eugenia Bahit <ebahit@linux.com>
# @link                  http://www.eugeniabahit.com/proyectos/jackthestripper
# @Contributor           Jason Soto <jason_soto@jsitech.com>
# @link                  http://www.jsitech.com/proyectos/jackthestripper

source helpers.sh


# 0. Verificar si es usuario root o no 
function is_root_user() {
    if [ "$USER" != "root" ]; then
        echo "Permiso denegado."
        echo "Este programa solo puede ser ejecutado por el usuario root"
        exit
    else
        clear
        cat templates/texts/welcome
    fi
}


# 1. Configurar Hostname
function set_hostname() {
    write_title "1. Configurar Hostname"
    echo -n " ¿Desea configurar un hostname? (y/n): "; read config_host
    if [ "$config_host" == "y" ]; then
        serverip=$(__get_ip)
        echo " Ingrese un nombre para identificar a este servidor"
        echo -n " (por ejemplo: myserver) "; read host_name
        echo -n " ¿Cuál será el dominio principal? "; read domain_name
        echo NETWORKING=yes > /etc/sysconfig/network
        echo HOSTNAME=$host_name >> /etc/sysconfig/network
        echo 127.0.0.1    localhost.localdomain >> /etc/hosts
        echo $serverip    $host_name.$domain_name >> /etc/hosts
        echo NETWORKING_IPV6=no >> /etc/sysconfig/network
        echo IPV6INIT=no >> /etc/sysconfig/network
        echo NOZEROCONF=yes >> /etc/sysconfig/network
    fi
    say_done
}


# 2. Configurar zona horaria
function set_hour() {
    write_title "2. Configuración de la zona horaria"
    rm -rf /etc/localtime
    tzselect
    say_done
}


#  3. Actualizar el sistema
function sysupdate() {
    write_title "3. Actualización del sistema"
    yum -y update
    say_done
}


#  4. Crear un nuevo usuario con privilegios
function set_new_user() {
    write_title "4. Creación de un nuevo usuario"
    echo -n " Indique un nombre para el nuevo usuario: "; read username
    useradd $username
    passwd $username
    usermod -a -G wheel $username
    say_done
}


#  5. Instrucciones para generar una RSA Key
function give_instructions() {
    serverip=$(__get_ip)
    write_title "5. Generación de llave RSA en su ordenador local"
    echo " *** SI NO TIENE UNA LLAVE RSA PÚBLICA EN SU ORDENADOR, GENERE UNA ***"
    echo "     Siga las instrucciones y pulse ENTER cada vez que termine una"
    echo "     tarea para recibir una nueva instrucción"
    echo " "
    echo "     EJECUTE LOS SIGUIENTES COMANDOS:"
    echo -n "     a) ssh-keygen -t rsa -b 4096 "; read foo1
    echo -n "     b) cat /home/$username/.ssh/id_rsa.pub >> /home/$username/.ssh/authorized_keys: "; read foo2
    say_done
}


#  6. Mover la llave pública RSA generada
function move_rsa() {
    write_title "6. Se moverá la llave pública RSA generada en el paso 5"
    echo " Ejecute el comando a Continuación para copiar la llave"
    echo " Presione ENTER cuando haya Finalizado "
    echo " ssh-copy-id -i $HOME/.ssh/id_rsa.pub $username@$serverip "
    say_done
}


#  7. Securizar SSH
function ssh_reconfigure() {
    write_title "7. Securizar accesos SSH"
    sed s/USERNAME/$username/g templates/sshd_config > /etc/ssh/sshd_config
    systemctl enable sshd.service
    systemctl start sshd.service
    say_done
}


#  8. Establecer reglas para iptables
function set_iptables_rules() {
    write_title "8. Establecer reglas para iptables (firewall)"
    sh iptables.sh
    service iptables save
    say_done
}



# 10. Instalar fail2ban
function install_fail2ban() {
    # para eliminar una regla de fail2ban en iptables utilizar:
    # iptables -D fail2ban-ssh -s IP -j DROP
    write_title "10. Instalar Sendmail y fail2ban"
    rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
    yum -y install sendmail
    yum -y install fail2ban
    systemctl enable fail2ban.service
    touch /var/log/auth.log
    systemctl start fail2ban.service
    say_done
}


# 11. Instalar, Configurar y Optimizar MariaDB
function install_mysql() {
    write_title "11. Instalar MariaDB"
    yum -y install mariadb mariadb-server
    echo -n " configurando MariaDB............ "
    systemctl enable mariadb.service
    systemctl start mariadb.service
    mysql_secure_installation
    systemctl restart mariadb.service
    say_done
}


# 12. Instalar, configurar y optimizar PHP
function install_php() {
    write_title "12. Instalar PHP 5 + Apache "
    yum install httpd
    yum install php
    yum install php-mysql php-gd
    echo -n " reemplazando archivo de configuración php.ini..."
    cp templates/php /etc/php.ini; echo " OK"
    systemctl enable httpd.service
    systemctl restart httpd.service
    say_done
}


# 13. Instalar ModSecurity
function install_modsecurity() {
    write_title "13. Instalar ModSecurity"
    yum install mod_security mod_security_crs
    systemctl restart httpd.service
    say_done
}


# 14. Activar ModSecurity
function install_owasp_core_rule_set() {
    write_title "14. Instalar OWASP ModSecurity Core Rule Set"
    sed s/SecRuleEngine\ DetectionOnly/SecRuleEngine\ On/g /etc/httpd/conf.d/mod_security.conf
    echo 'SecServerSignature "AntiChino Server 1.0.4 LS"' >> /etc/httpd/modsecurity.d/modsecurity_crs_10_config.conf
    echo 'Header set X-Powered-By "Plankalkül 1.0"' >> /etc/httpd/modsecurity.d/modsecurity_crs_10_config.conf
    echo 'Header set X-Mamma "Mama mia let me go"' >> /etc/httpd/modsecurity.d/modsecurity_crs_10_config.conf
    systemctl restart httpd.service
    say_done
}


# 15. Configurar y optimizar Apache
function configure_apache() {
    write_title "15. Finalizar configuración y optimización de Apache"
    cp templates/apache /etc/httpd/conf/httpd.conf
    systemctl restart httpd.service
    say_done
}


# 16. Instalar ModEvasive
function install_modevasive() {
    write_title "16. Instalar ModEvasive"
    echo -n " Indique e-mail para recibir alertas: "; read inbox
    yum install httpd-devel gcc
    yum install mod_evasive
    sed s/MAILTO/$inbox/g /etc/httpd/conf/httpd.conf
    systemctl restart httpd.service
    say_done
}


# 17. Configurar fail2ban
function config_fail2ban() {
    write_title "17. Finalizar configuración de fail2ban"
    sed s/MAILTO/$inbox/g templates/fail2ban > /etc/fail2ban/jail.local
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.conf
    systemctl restart fail2ban.service
    say_done
}


# 18. Instalación de paquetes adicionales
function install_aditional_packages() {
    write_title "18. Instalación de paquetes adicionales"
    echo "18.1. Instalar Vim.............."; yum -y install vim
    echo "18.2. Instalar Nano............."; yum -y install nano
    echo "18.3. Instalar mlocate............."; yum -y install mlocate
    echo "18.4. Instalar yum-utils............."; yum -y install yum-utils
    echo "18.5. Instalar yum-plugin-security............."; yum -y install yum-plugin-security
    echo "18.6. Instalar Unhide.............."; yum -y install unhide
    say_done
}

# 19. Tunear y Asegurar Kernel
function tunning_kernel() {
    write_title "19. Tunear Kernel"
    cp templates/sysctl.conf /etc/sysctl.conf; echo " OK"
    sysctl -e -p
    say_done
}

# 21. Deshabilitar Sistemas de Archivos y protocolos no Comunes
function disable_uncommon() {
    write_title "21. Deshabilitar Sistemas de Archivos y protocolos no Comunes"
    echo -n " Deshabilitando Sistemas de Archivos no Comunes............ "
    echo "install cramfs /bin/false" > /etc/modprobe.d/cramfs.conf
    echo "install freevxfs /bin/false" > /etc/modprobe.d/freevxfs.conf
    echo "install jffs2 /bin/false" > /etc/modprobe.d/jffs2.conf
    echo "install hfs /bin/false" > /etc/modprobe.d/hfs.conf
    echo "install hfsplus /bin/false" > /etc/modprobe.d/hfsplus.conf
    echo "install squashfs /bin/false" > /etc/modprobe.d/squashfs.conf
    echo "install udf /bin/false" > /etc/modprobe.d/udf.conf; echo " OK"
    echo -n " Deshabilitando Protocolos no Comunes............ "
    echo "install dccp /bin/false" > /etc/modprobe.d/dccp.conf
    echo "install sctp /bin/false" > /etc/modprobe.d/sctp.conf
    echo "install rds /bin/false" > /etc/modprobe.d/rds.conf
    echo "install tipc /bin/false" > /etc/modprobe.d/tipc.conf; echo " OK"
    say_done
}

# 22. Pasos Adicionales de Seguridad
function additional_SecStep() {
    write_title "22. Ejecutar pasos Adicionales para Asegurar el Sistema"
    systemctl disable avahi-daemon
    echo “tty1” > /etc/securetty
    chmod 700 /root
    chmod 600 /boot/grub2/grub.cfg
    echo "SINGLE=/sbin/sulogin" >> /etc/sysconfig/init
    echo "options ipv6 disable=1" >> /etc/modprobe.d/disabled.conf
    echo -n " ¿Desea Deshabilitar el acceso USB? (y/n): "; read usb_access
    if [ "$usb_access" == "y" ]; then
        echo "install usb-storage /bin/false" > /etc/modprobe.d/usb-storage.conf
    fi
    say_done
}

#23. Restringir Cron/AT a Root
function secure_cron() {
    write_title "23. Restringir Ejecucion Cron/AT a Root"
    echo -n " ¿Desea Restringir Cron/AT a Root? (y/n): "; read cron_access
    if [ "$cron_access" == "y" ]; then
        sh templates/LockCronAT.sh ; echo " OK"
    fi
    say_done
}

# 24. Tunnear Vim
function tunning_vim() {
    write_title "24. Tunnear Vim"
    tunning vimrc
}


# 25. Tunnear Nano
function tunning_nano() {
    write_title "25. Tunnear Nano"
    tunning nanorc
}

# 26. Instalar Sistema de Detección de Intrusos
function install_AIDE() {
    write_title "26. Instalar Sistema de Detección de Intrusos AIDE"
    echo -n " ¿Desea instalar el Ambiente de Deteccion de Intruso AIDE? (y/n): "; read install_aide
    if [ "$install_aide" == "y" ]; then
        yum install aide
        aide --init
        cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    fi
    say_done
}


# 27. Agregar tarea de actualización diaria
function add_updating_task() {
    write_title "27. Agregar tarea de actualización diaria al Cron"
    touch tareas
    echo @daily yum -y update >> tareas
    echo "05 4 * * * root /usr/sbin/aide --check" >> tareas
    crontab tareas
    rm tareas
    say_done
}


# 28. Reiniciar servidor
function final_step() {
    write_title "28. Finalizar deploy"
    replace USERNAME $username SERVERIP $serverip < templates/texts/bye
    echo -n " ¿Ha podido conectarse por SHH como $username? (y/n) "
    read respuesta
    if [ "$respuesta" == "y" ]; then
        reboot
    else
        echo "El servidor NO será reiniciado y su conexión permanecerá abierta."
        echo "Bye."
    fi
}


is_root_user                    #  0. Verificar si es usuario root o no
set_hostname                    #  1. Configurar Hostname
set_hour                        #  2. Configurar zona horaria
sysupdate                       #  3. Actualizar el sistema
set_new_user                    #  4. Crear un nuevo usuario con privilegios
give_instructions               #  5. Instrucciones para generar una RSA Key
move_rsa                        #  6. Mover la llave pública RSA generada
ssh_reconfigure                 #  7. Securizar SSH
set_iptables_rules              #  8. Establecer reglas para iptables
create_iptable_script           #  9. Crear script de automatizacion iptables
install_fail2ban                # 10. Instalar fail2ban
install_mysql                   # 11. Instalar, Configurar y Optimizar MariaDB
install_php                     # 12. Instalar, configurar y optimizar PHP
install_modsecurity             # 13. Instalar ModSecurity
install_owasp_core_rule_set     # 14. Instalar OWASP para ModSecuity
configure_apache                # 15. Configurar y optimizar Apache
install_modevasive              # 16. Instalar ModEvasive
config_fail2ban                 # 17. Configurar fail2ban
install_aditional_packages      # 18. Instalación de paquetes adicionales
tunning_kernel                  # 19. Asegurar Linux Kernel
enable_auditd                   # 20. Habilitar y Configurar Reglas Auditd
disable_uncommon                # 21. Deshabilitar Sistemas de Archivos y protocolos no Comunes
additional_SecStep              # 22. Pasos Adicionales de Seguridad
secure_cron                     # 23. Restringir Cron/AT a Root
tunning_vim                     # 24. Tunnear Vim
tunning_nano                    # 25. Tunnear Nano
install_AIDE                    # 26. Instalar Sistema de Detección de Intrusos
add_updating_task               # 27. Agregar tarea de actualización diaria
final_step                      # 28. Reiniciar servidor

