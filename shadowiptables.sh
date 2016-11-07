#!/bin/sh
 
#自动翻墙脚本，配合shadowsocks-libev的ss-redir使用。需要ipset（sudo apt-get install ipset）
 
server_IP=$VPS_SERVER_IP
sub_network=$SUB_NETWORK
ss_redir_port=$SS_REDIR_PORT
 
[ -r chnroute.txt ] || curl 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | grep ipv4 | grep CN | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > chnroute.txt
 
iptables -t nat -N SHADOWSOCKS
 
iptables -t nat -A SHADOWSOCKS -d $server_IP -j RETURN
 
# 内网网段
iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN
 
# 创建ipset列表
ipset create chnroute hash:net
cat chnroute.txt | xargs -I ip ipset add chnroute ip
 
iptables -t nat -A SHADOWSOCKS -m set --match-set chnroute dst -j RETURN  # 国内ip表直连
iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports $ss_redir_port  #其他连接走ss转发 
 
 
iptables -t nat -A PREROUTING -s $sub_network/24 -p tcp -j SHADOWSOCKS # 192xx为vpn客户端的网段
iptables -t nat -A PREROUTING -s $sub_network/24 -p udp -j SHADOWSOCKS
