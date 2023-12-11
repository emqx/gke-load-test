#!/usr/bin/env bash

set -eou pipefail

echo "session required pam_limits.so" >> /etc/pam.d/common-session
echo "*      soft    nofile      10000000"  >> /etc/security/limits.conf
echo "*      hard    nofile      100000000"  >> /etc/security/limits.conf

echo 'DefaultLimitNOFILE=2097152' >> /etc/systemd/system.conf
echo >> /etc/security/limits.conf << EOF
*      soft   nofile      2097152
*      hard   nofile      2097152
EOF

cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.netdev_max_backlog=16384
net.core.optmem_max=16777216
net.core.somaxconn=32768
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fin_timeout=5
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.tcp_max_tw_buckets=1048576
net.ipv4.tcp_mem=378150000  504200000  756300000
net.ipv4.tcp_rmem=1024 4096 16777216
net.ipv4.tcp_wmem=1024 4096 16777216
net.ipv4.tcp_tw_reuse=1
net.netfilter.nf_conntrack_max=1000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
net.nf_conntrack_max=1000000
fs.file-max=2097152
fs.nr_open=2097152
EOF

sysctl --load=/etc/sysctl.d/99-sysctl.conf

ulimit -n 2097152
