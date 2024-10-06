enable-cups:
    firewall-cmd --permanent --add-port=631/tcp
    firewall-cmd --permanent --add-port=631/udp 
    firewall-cmd --reload 
    systemctl unmask cups
    systemctl enable cups
    systemctl start cups
