#!/bin/bash
# Provision the test target services (sshd + vsftpd) directly on an ubuntu
# host (github actions runner), without docker. Mirrors the server image in
# Tests/docker. Run as a regular user, uses sudo internally.
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "$EUID" -ne 0 ]; then
    SUDO=sudo
else
    SUDO=
fi

$SUDO apt-get update -qq
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq vsftpd openssh-server > /dev/null

# the tests address the remote host as "server" (the docker compose network
# name in local runs); make it resolvable here as well
grep -q '127.0.0.1 server' /etc/hosts || echo "127.0.0.1 server" | $SUDO tee -a /etc/hosts > /dev/null

# {{{ test user (ssh + ftp password auth)
id testuser > /dev/null 2>&1 || $SUDO useradd -m testuser
echo 'testuser:testpass' | $SUDO chpasswd
# }}}

# {{{ sshd: fixed RSA host key (the tests pin its fingerprint) + RSA signatures
$SUDO install -m 600 Tests/docker/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
$SUDO install -m 644 Tests/docker/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
$SUDO mkdir -p /etc/ssh/sshd_config.d
$SUDO install -m 644 Tests/docker/sshd_tests.conf /etc/ssh/sshd_config.d/10-tests.conf
$SUDO systemctl restart ssh
# }}}

# {{{ authorized_keys for the ssh key authentication tests
$SUDO install -d -m 700 -o testuser -g testuser /home/testuser/.ssh
$SUDO install -m 600 -o testuser -g testuser Tests/docker/home/.ssh/authorized_keys /home/testuser/.ssh/authorized_keys
# }}}

# {{{ TLS certificates: CA + CA-signed server cert (same as the server image)
tmp="$(mktemp -d)"
openssl genrsa -out "$tmp/ca.key" 2048 2> /dev/null
openssl req -x509 -new -key "$tmp/ca.key" -days 3650 -out "$tmp/ca.pem" -subj "/C=DE/ST=Berlin/L=Berlin/O=depage.net-ca/OU=IT/CN=ca.depage.net"
openssl genrsa -out "$tmp/ftp.key" 2048 2> /dev/null
openssl req -new -key "$tmp/ftp.key" -out "$tmp/ftp.csr" -subj "/C=DE/ST=Berlin/L=Berlin/O=depage.net/OU=IT/CN=localhost"
openssl x509 -req -days 365 -CA "$tmp/ca.pem" -CAkey "$tmp/ca.key" -CAcreateserial -CAserial "$tmp/serial" -in "$tmp/ftp.csr" -out "$tmp/ftp.pem" 2> /dev/null

# serve the cert via the ssl-cert-snakeoil paths: ubuntu's apparmor profile
# for vsftpd only permits reading the key through the ssl-cert group there
$SUDO cp "$tmp/ftp.pem" /etc/ssl/private/ssl-cert-snakeoil.pem
$SUDO cp "$tmp/ftp.key" /etc/ssl/private/ssl-cert-snakeoil.key
sslcert_group="$(getent group ssl-cert > /dev/null && echo ssl-cert || echo root)"
$SUDO chown "root:$sslcert_group" /etc/ssl/private/ssl-cert-snakeoil.key
$SUDO chmod 640 /etc/ssl/private/ssl-cert-snakeoil.key

# the tests read the CA certificate from Tests/docker/ssl/ca.pem
install -d Tests/docker/ssl
cp "$tmp/ca.pem" Tests/docker/ssl/ca.pem
rm -rf "$tmp"
# }}}

# {{{ vsftpd: run the image's config directly; ubuntu's packaged service unit
# expects different config semantics than the standalone listen=YES config
sed -e 's#^rsa_cert_file=.*#rsa_cert_file=/etc/ssl/private/ssl-cert-snakeoil.pem#' \
    -e 's#^rsa_private_key_file=.*#rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key#' \
    Tests/docker/vsftpd.conf > /tmp/vsftpd-ci.conf
$SUDO cp /tmp/vsftpd-ci.conf /etc/vsftpd.conf
$SUDO mkdir -p /var/run/vsftpd/empty
$SUDO systemctl stop vsftpd vsftpd.socket > /dev/null 2>&1 || true
nohup $SUDO /usr/sbin/vsftpd /etc/vsftpd.conf > /tmp/vsftpd-ci.log 2>&1 &
# }}}

# {{{ wait for the services to accept connections
for port in 21 22; do
    ready=
    for ((i = 0; i < 30; i++)); do
        if (exec 3<> "/dev/tcp/127.0.0.1/${port}") 2> /dev/null; then
            exec 3<&- 3>&-
            ready=1
            break
        fi
        sleep 1
    done
    if [ -z "$ready" ]; then
        echo "service on port ${port} did not start" >&2
        if [ "$port" = "21" ] && [ -r /tmp/vsftpd-ci.log ]; then
            cat /tmp/vsftpd-ci.log >&2
        fi
        exit 1
    fi
done
# }}}
