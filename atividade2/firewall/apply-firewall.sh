#!/bin/sh
set -eu

# conexoes ja abertas continuam funcionando
iptables -A INPUT -m conntrack \
  --ctstate ESTABLISHED,RELATED -j ACCEPT

# loopback
iptables -A INPUT -i lo -j ACCEPT

# so nginx e admin podem bater na porta 8000
for ip in "$NGINX_IP" "$ADMIN_IP"; do
  iptables -A INPUT -p tcp -s "$ip" \
    --dport 8000 -j ACCEPT
done

# bloqueia o resto
iptables -A INPUT -p tcp --dport 8000 -j DROP
