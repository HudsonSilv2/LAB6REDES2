# Laboratório 6 — Segurança de Redes

**Tema:** Análise e Mitigação de Riscos em Segurança de Redes

Este laboratório demonstra, em ambiente controlado com Docker, como identificar serviços expostos e como aplicar controles para mitigar os riscos encontrados.

---

## Estrutura do projeto

```
lab6-seguranca-redes/
│
├── atividade1/
│   └── docker-compose.yml          # Rede plana sem segmentação
│
├── atividade2/
│   ├── docker-compose.yml          # Redes segmentadas + HTTPS
│   ├── nginx/
│   │   ├── nginx.conf              # Proxy reverso com TLS
│   │   └── certs/                  # Certificados autoassinados (não versionados)
│   └── firewall/
│       ├── apply-firewall.sh       # Regras iptables para a API
│       └── README.md
│
├── api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py                      # Flask API demonstrativa
│
├── README.md
└── .gitignore
```

---

## Pré-requisitos

- Docker Engine
- Docker Compose
- OpenSSL

---

## Atividade 1 — Reconhecimento e Análise de Vulnerabilidades

### Objetivo

Identificar portas e serviços acessíveis em uma rede sem segmentação e analisar os riscos que essa configuração representa.

### Execução

```bash
# 1. Criar a rede compartilhada
docker network create lab6-net

# 2. Subir os containers
docker compose -f atividade1/docker-compose.yml -p lab6-a1 up -d --build

# 3. Confirmar os containers
docker compose -f atividade1/docker-compose.yml -p lab6-a1 ps

# 4. Inspecionar a rede
docker network inspect lab6-net
```

### Testes de reconhecimento (dentro do container admin)

```bash
docker exec -it lab6-a1-admin-1 sh

# Nmap
nmap -sV nginx
nmap -p 3306 mysql
nmap -p 6379 redis
nmap -sV api

# Netcat
nc -vz api 8000
nc -vz redis 6379
nc -vz mysql 3306

# Curl
curl -v http://api:8000/
curl -v http://nginx/
```

### Encerramento

```bash
docker compose -f atividade1/docker-compose.yml -p lab6-a1 down
```

---

## Atividade 2 — Mitigação e Proteção da Rede

### Objetivo

Aplicar segmentação de rede, firewall por IP e HTTPS, e comparar os resultados com a Atividade 1.

### Arquitetura de redes

| Rede         | Tipo     | Participantes              |
|--------------|----------|----------------------------|
| `frontend`   | bridge   | Nginx, Admin               |
| `app`        | internal | Nginx, API                 |
| `management` | internal | API, Admin                 |
| `backend`    | internal | API, MySQL, Redis          |

### Políticas de acesso

| Origem | Destino | Política |
|--------|---------|----------|
| Admin  | Nginx   | Permitir |
| Admin  | API     | Permitir |
| Admin  | MySQL   | Bloquear |
| Admin  | Redis   | Bloquear |
| Nginx  | API     | Permitir |
| API    | MySQL   | Permitir |
| API    | Redis   | Permitir |

### Execução

```bash
# 1. Gerar certificado autoassinado
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout atividade2/nginx/certs/key.pem \
  -out atividade2/nginx/certs/cert.pem \
  -subj "/CN=nginx"

# 2. Subir os containers
docker compose -f atividade2/docker-compose.yml -p lab6-a2 up -d --build

# 3. Confirmar os containers
docker compose -f atividade2/docker-compose.yml -p lab6-a2 ps
```

### Aplicar o firewall

```bash
# Obter IPs
docker inspect lab6-a2-nginx-1   # anote o IP da rede "app"
docker inspect lab6-a2-admin-1   # anote o IP da rede "management"

# Copiar o script
docker cp atividade2/firewall/apply-firewall.sh lab6-a2-api-1:/tmp/apply-firewall.sh

# Executar (substitua os IPs)
docker exec \
  -e NGINX_IP=<IP_NGINX_APP> \
  -e ADMIN_IP=<IP_ADMIN_MANAGEMENT> \
  lab6-a2-api-1 \
  sh /tmp/apply-firewall.sh

# Verificar regras
docker exec lab6-a2-api-1 iptables -L INPUT -n -v
```

### Testes de validação (dentro do container admin)

```bash
docker exec -it lab6-a2-admin-1 sh

# Deve falhar — Admin não está na rede backend
nmap -p 3306 mysql
nmap -p 6379 redis
nc -vz -w 3 mysql 3306
nc -vz -w 3 redis 6379

# Deve funcionar — Admin está na rede management
nc -vz api 8000
curl http://api:8000/health

# Testar HTTPS
curl -v http://nginx          # Espera: 301 redirect
curl -v https://nginx --insecure  # Espera: resposta da API via TLS
```

### Testes internos da API

```bash
# A API deve resolver e conectar ao MySQL e Redis
docker exec lab6-a2-api-1 python -c "import socket; print(socket.gethostbyname('mysql'))"
docker exec lab6-a2-api-1 python -c "import socket; print(socket.gethostbyname('redis'))"
docker exec lab6-a2-api-1 python -c "import socket; socket.create_connection(('mysql',3306),5); print('MySQL acessivel')"
docker exec lab6-a2-api-1 python -c "import socket; socket.create_connection(('redis',6379),5); print('Redis acessivel')"
```

### Testar HTTPS do host

```bash
curl -vk https://localhost:8443/
```

### Encerramento

```bash
docker compose -f atividade2/docker-compose.yml -p lab6-a2 down
```

---

## Tabela comparativa — Atividade 1 vs Atividade 2

| Teste           | Atividade 1                | Atividade 2 |
|-----------------|----------------------------|-------------|
| Admin → MySQL   | Acesso TCP possível        | Isolado     |
| Admin → Redis   | Acesso TCP possível        | Isolado     |
| Admin → API     | Permitido                  | Permitido   |
| Nginx → API     | Não configurado como proxy | Permitido   |
| HTTPS           | Não configurado            | Habilitado  |
| Firewall da API | Não aplicado               | Aplicado    |

---

## Perguntas de reflexão

1. **Por que o reconhecimento é uma fase crítica?** — Permite identificar portas, serviços e pontos de exposição. Defensores usam essas informações para planejar controles; atacantes, para identificar alvos.

2. **Quais serviços representam maior risco?** — MySQL, Redis e APIs sem autenticação, pois expõem dados e permitem acessos indevidos.

3. **Como um firewall reduz a superfície de ataque?** — Restringindo conexões por regras, permitindo apenas os acessos necessários e bloqueando comunicações não autorizadas.

4. **Por que o HTTPS é fundamental?** — Utiliza TLS para proteger a confidencialidade e integridade dos dados em trânsito.

5. **Quais vantagens o Docker oferece para testes de segurança?** — Cria ambientes reproduzíveis, isola serviços em redes diferentes e simula arquiteturas sem hardware adicional.

---

## Repositório

> URL do GitLab institucional (a ser preenchida após publicação)
