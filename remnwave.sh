#!/bin/bash

# -----------------------------
# SYSCTL NETWORK OPTIMIZATION
# -----------------------------

sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv4.ip_forward=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3

net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.rmem_max=67108864
net.core.wmem_max=67108864

net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_no_metrics_save=1

net.ipv4.icmp_echo_ignore_broadcasts=1

net.core.netdev_max_backlog=16384
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
EOF

sudo sysctl -p


# -----------------------------
# IPTABLES RULES
# -----------------------------

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# VPN interface
sudo iptables -A INPUT -i tun0 -j ACCEPT
sudo iptables -A OUTPUT -o tun0 -j ACCEPT


# Block IP ranges
sudo iptables -A OUTPUT -d 77.83.59.0/24 -j DROP
sudo iptables -A OUTPUT -d 95.85.96.0/19 -j DROP
sudo iptables -A OUTPUT -d 103.220.0.0/22 -j DROP
sudo iptables -A OUTPUT -d 119.235.112.0/20 -j DROP
sudo iptables -A OUTPUT -d 185.69.184.0/22 -j DROP
sudo iptables -A OUTPUT -d 185.246.72.0/22 -j DROP
sudo iptables -A OUTPUT -d 194.117.52.192/26 -j DROP
sudo iptables -A OUTPUT -d 216.250.8.0/21 -j DROP
sudo iptables -A OUTPUT -d 217.65.78.0/24 -j DROP
sudo iptables -A OUTPUT -d 217.174.224.0/20 -j DROP
sudo iptables -A OUTPUT -d 93.171.220.0/22 -j DROP
sudo iptables -A OUTPUT -d 104.28.194.0/24 -j DROP
sudo iptables -A OUTPUT -d 93.171.222.0/24 -j DROP


# Save firewall
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent 
# sudo apt install -y iptables-persistent
sudo iptables-save | sudo tee /etc/iptables/rules.v4


# -----------------------------
# DOCKER INSTALL
# -----------------------------

curl -fsSL https://get.docker.com | sudo sh


# -----------------------------
# REMNANODE SETUP
# -----------------------------

sudo mkdir -p /opt/remnanode
cd /opt/remnanode

sudo tee docker-compose.yml > /dev/null <<'EOF'
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    network_mode: host
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      - NODE_PORT=2222
      - SECRET_KEY="eyJub2RlQ2VydFBlbSI6Ii0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLVxuTUlJQmlUQ0NBUytnQXdJQkFnSUhBWGRwT0lJVGhqQUtCZ2dxaGtqT1BRUURBakF1TVN3d0tnWURWUVFERXlONlxuVlZwaFJuVjVTME5yTFVwWlVtMXVOMlJ3Vldab1pWVkJZbkExU0RaMGJtWm9NakFlRncweU5qQTBNak14TURBM1xuTURGYUZ3MHlPVEEwTWpNeE1EQTNNREZhTUM0eExEQXFCZ05WQkFNVEkzbFlSMEkwZDJwWFpUZE5hSGRrYzBOa1xuVURJNFNsUllSSGRVWWtwSE4yNVNOa0o1TUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFTFNEOVxuT0h6VnYwNE1EOGtRWFArZEk0Y2FoaEVnc1dmT292KzZrSEhNU1A5anRGbXJNZUNsdWFtUXZIUE4rYXZRNkxqeVxuL1IycXh1ZHEyelJheHJHTzdLTTRNRFl3REFZRFZSMFRBUUgvQkFJd0FEQU9CZ05WSFE4QkFmOEVCQU1DQmFBd1xuRmdZRFZSMGxBUUgvQkF3d0NnWUlLd1lCQlFVSEF3RXdDZ1lJS29aSXpqMEVBd0lEU0FBd1JRSWhBSjAySjZmZFxuVTdzY25XVWRWNmo5MHhNSm9ISkhqM293M05OMTI3Q2hRRWQwQWlCd1hWL2lMTXZEb2FyVXAwd2NyR1ZNUUJsYlxuVkNBOGNRZWNJand6OUExVXBRPT1cbi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0iLCJub2RlS2V5UGVtIjoiLS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tXG5NSUdIQWdFQU1CTUdCeXFHU000OUFnRUdDQ3FHU000OUF3RUhCRzB3YXdJQkFRUWdtRjZPcEtEUExVT0dGRnYwXG5yZ0pyb1h4UGNuNUVtY290SGZ6a3I5eERMVEtoUkFOQ0FBUXRJUDA0Zk5XL1Rnd1B5UkJjLzUwamh4cUdFU0N4XG5aODZpLzdxUWNjeEkvMk8wV2FzeDRLVzVxWkM4YzgzNXE5RG91UEw5SGFyRzUycmJORnJHc1k3c1xuLS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLSIsImNhQ2VydFBlbSI6Ii0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLVxuTUlJQmJ6Q0NBUlNnQXdJQkFnSUJBVEFLQmdncWhrak9QUVFEQWpBdU1Td3dLZ1lEVlFRREV5TjZWVnBoUm5WNVxuUzBOckxVcFpVbTF1TjJSd1ZXWm9aVlZCWW5BMVNEWjBibVpvTWpBZUZ3MHlOVEV5TVRZd016UTNORE5hRncwelxuTlRFeU1UWXdNelEzTkROYU1DNHhMREFxQmdOVkJBTVRJM3BWV21GR2RYbExRMnN0U2xsU2JXNDNaSEJWWm1obFxuVlVGaWNEVklOblJ1Wm1neU1Ga3dFd1lIS29aSXpqMENBUVlJS29aSXpqMERBUWNEUWdBRVQwcnhtTlR6ZUk2SlxuYlR3ZmRvWFR4UjMvbE9TbGd1UWJLdG1TWlFPVlhGUzA1ZTlESjE4bVBobFkwNnhpMC9MZDF1TEIxZVRXakdMUFxuVHpBSGo3M0JhS01qTUNFd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBT0JnTlZIUThCQWY4RUJBTUNBb1F3Q2dZSVxuS29aSXpqMEVBd0lEU1FBd1JnSWhBUEt0NVdQR0Rnb1g4d3BWcmtrdm50VWZzOG5Ja2QvYzlKVjRJT3lSRUtBNlxuQWlFQXU2dzRoaUJGOWpvTk8xSE02UkRQV1ZxaXVNNjBaclM2bHk0T0NxRCtweEU9XG4tLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tIiwiand0UHVibGljS2V5IjoiLS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS1cbk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBdU5wcmZrZG83UHJlYS9LS1NxN3ZcbldhaXlGWE5NZzRRLzRTay9PajdzbDU1S0owWGFLOEkrdDEyZU9wUnlVLzVvcDRsWTlzYXlkU0hkSzAyTkdDdnpcbjRFbU1ZL1lxSStCNmNRNHZuR0xpNXRWQVRodkdxdmp1UHpUVGpZK2tmY0s2dXNsUjQvTERFUkR5c29ZWXJaZzJcbnhxQkZLV3JuS3dVUlBUVnRmUTFETnhQa3JJRDB0aHZnY2U2MExnYW5aWUVoSzRLZnVKSG9pcW93RndEVGJ2aDNcbk82TnRURVZhRi9udTM1TnR4RTRkb1FOL2JhaXQ5VEhLQmo2SHkvVldxTXoyVGtsNUZMYjM0NEJKUVh3blNmUmNcbnMwWlhBWC9iQk5FVkNQNVEvSXVQdjdhUElGZUVidXVycWdodzJTbTU2ZUlFbmVCQlEwM2xva01XYTYrWUUzVS9cbmd3SURBUUFCXG4tLS0tLUVORCBQVUJMSUMgS0VZLS0tLS1cbiJ9"
    volumes:
      - '/var/log/remnanode:/var/log/remnanode'
EOF


sudo mkdir -p /var/log/remnanode


# -----------------------------
# LOGROTATE
# -----------------------------

sudo apt install -y logrotate

sudo tee /etc/logrotate.d/remnanode > /dev/null <<'EOF'
/var/log/remnanode/*.log {
    size 50M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
EOF

sudo logrotate -vf /etc/logrotate.d/remnanode


# -----------------------------
# START REMNANODE
# -----------------------------

sudo docker compose down
sudo docker compose up -d

# sudo docker compose logs -f -t


# -----------------------------
# MARZBAN NODE
# -----------------------------


apt-get update; apt-get upgrade -y; apt-get install curl socat git -y


git clone https://github.com/Gozargah/Marzban-node
mkdir /var/lib/marzban-node
cd  /var/lib/marzban-node 
cd ~/Marzban-node 

sudo tee docker-compose.yml > /dev/null <<'EOF'
services:
  marzban-node:
    # build: .
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host

    # env_file: .env
    environment:
      SSL_CERT_FILE: "/var/lib/marzban-node/ssl_cert.pem"
      SSL_KEY_FILE: "/var/lib/marzban-node/ssl_key.pem"
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/ssl_client_cert.pem"
      SERVICE_PROTOCOL: "rest"

    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
EOF

sudo tee /var/lib/marzban-node/ssl_client_cert.pem > /dev/null <<'EOF'
-----BEGIN CERTIFICATE-----
MIIEnDCCAoQCAQAwDQYJKoZIhvcNAQENBQAwEzERMA8GA1UEAwwIR296YXJnYWgw
IBcNMjUxMDA0MjIwMTE5WhgPMjEyNTA5MTAyMjAxMTlaMBMxETAPBgNVBAMMCEdv
emFyZ2FoMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAuSADnA2thISP
sqXoq0vcrhUZKSbjhaZt9IZOEsBFprDmwK1Xgbc+6pxin7u9ueKOzArhRqihnuJZ
01DVQ8LXO9zoHasWBBAROFVFaNdFKEq9H7mj8KjPASDlPeEPzjxQvTHEDegSVJPx
yyQyw8/3hL1QRXvZx5GRc1HOenBN8koNk2w5SGRleozLJp9X2TTvNBWHJxNMTvtE
4LDJ+5i7dg0xfldzOAkyaEGeX9vKZVNX+h4w6mnmdEdO6mjddctNIoQPi/ixsyfL
/uRPpsdQ+81KXUv6M0GNAMuazdA0NHaoIruQlLKwwdK4IFYUZ10gOO9gjoUhkifv
iTHbB4z0kOZFFToigKfD/KNH0wTByRzAA5XPzylMxee5BjWmSj4Z9ALc/zFg+SqC
oTfmQboVWJI2Fg7XRNQ6uev1B9IqLsyOJF02cS1Ps1hwME89+qetH0XD2GZeGlh5
0maHSg1DxkgK6rnJLmJmN3BRLJLtAFzd/6g98IZgVKG15vlPJ3z9ev2S1UNKrq6l
njNt1Z+IWA9MmB28QsWQaIrvk1AgK6L26CmzDS/TcFjozW+1fP6sYWteDP4ChHTL
C1+XAuzQQtqah6W8ABINFJyGutT+FWBvaMOVv+1pSAXMNWQafENfjui4i9PT1L1Q
a6vIqm7FBE26FDW6zxBrPfzEX7Wj03UCAwEAATANBgkqhkiG9w0BAQ0FAAOCAgEA
eD8f/g7nr+9kXemezIi9BUnqc7TB3lawYQOqiHla6GCXK23kA9iHbPuJe3WI4R5w
Tg4oO1vzJQLb7/PUofo9DUJ1xqiitGMLLnTAOxuY4KupPRXktEr7ZjR2tIlveGAL
q5A4sbTEcI7PvzRmD78mowuTKkzaqid03qrH33L2TLFIyNiIZ7bFw4PNvjj7w8Sv
82IFV3Mn+4mKJfmss7xDQEOFs1YviK5rIG+VM7f5COefDqRnn8HbB88+1bkCcqmQ
mTpkXWJzRNLEjVXCGo2p1QWO1z4qkmJbWQV1S5/J13fZRByrW6TOzRUKuvW4udrx
UdOOsuASRHWdQO/m20Ks8vlAaBRculJkTa3VEz+IjkQA1/18dPkvN70s9nHA87GF
F7yN+YeherhsMAfMNZm3YgsPuS/hSfINEuu0wjfq7B8byt6ehi8D4j+9jzGZGv9b
bz2gq3epVEN/cfonEdZcCDvcA8miSF6Q5qGSJ+mIY9J99BaifTG1cfzGNfz+7Mqf
79wBpvUvaOO/SFY6AWHYkKqn8agZjKsUL5aZOW2I6OmNUCi8yRyxVWRKxuJZuBoP
iNW2Zl58Ig5vwvUUHr4byfHB1pf7c0r9Ys8KIYBJ6lifYbnSnq+0T2hSllACgaR1
IL21YIzH9QC4n1EfgCPVfoAu+eG/+h028C5MBqQBtvY=
-----END CERTIFICATE-----
EOF

sudo docker compose down
sudo docker compose up -d

sudo apt update && sudo apt upgrade -y
