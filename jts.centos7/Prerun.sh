
#Instalar Paquetes Necesarios JacktheStripper CentOS 7

yum install net-tools
yum install iptables-services
yum install policycoreutils-python

#Deshabilitar Firewalld y Habilitar Iptables

systemctl mask firewalld.service
systemctl enable iptables.service
systemctl stop firewalld.service
systemctl start iptables.service

#Agregar Nuevo Puerto SSH a SeLinux

semanage port -a -t ssh_port_t -p tcp 2020
