# Firewall da API

Script pra aplicar regras de iptables no container da API e restringir quem pode acessar a porta 8000.

## Como usar

1. Subir os containers da atividade 2:

```bash
docker compose -f atividade2/docker-compose.yml -p lab6-a2 up -d --build
```

2. Pegar os IPs:

```bash
docker inspect lab6-a2-nginx-1   # IP na rede app
docker inspect lab6-a2-admin-1   # IP na rede management
```

3. Copiar o script pro container:

```bash
docker cp atividade2/firewall/apply-firewall.sh lab6-a2-api-1:/tmp/apply-firewall.sh
```

4. Executar com os IPs:

```bash
docker exec \
  -e NGINX_IP=<ip_nginx> \
  -e ADMIN_IP=<ip_admin> \
  lab6-a2-api-1 \
  sh /tmp/apply-firewall.sh
```

5. Verificar:

```bash
docker exec lab6-a2-api-1 iptables -L INPUT -n -v
```

As regras somem se o container for recriado, então precisaria rodar de novo.
