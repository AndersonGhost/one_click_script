#!/bin/bash
# one key v2ray
kill -9 $(ps -ef | grep v2ray | grep -v grep | awk '{print $2}')
kill -9 $(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print $2}')
clear
read -p "��ѡ��v2rayЭ��(Ĭ��1.vmess,2.vless):" mode
if [ -z "$mode" ]
then
	mode=1
fi
if [ $mode != 1 ] && [ $mode != 2 ]
then
	echo ��������ȷ��v2rayģʽ
	exit
fi
read -p "��ѡ��argo����ģʽIPV4����IPV6(����4��6,Ĭ��4):" ips
if [ -z "$ips" ]
then
	ips=4
fi
if [ $ips != 4 ] && [ $ips != 6 ]
then
	echo ��������ȷ��argo����ģʽ
	exit
fi
linux_os=("Debian" "Ubuntu" "CentOS" "Fedora" "Alpine")
linux_update=("apt update" "apt update" "yum -y update" "yum -y update" "apk update -f")
linux_install=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
n=0
for i in `echo ${linux_os[@]}`
do
	if [ $i == $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') ]
	then
		break
	else
		n=$[$n+1]
	fi
done
if [ $n == 5 ]
then
	echo ��ǰϵͳ$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2)û������
	echo Ĭ��ʹ��APT��������
	n=0
fi
if [ -z $(type -P unzip) ]
then
	${linux_update[$n]}
	${linux_install[$n]} unzip
fi
if [ -z $(type -P wget) ]
then
	${linux_update[$n]}
	${linux_install[$n]} wget
fi
rm -rf v2ray cloudflared-linux v2ray.zip
case "$(uname -m)" in
	x86_64 | x64 | amd64 )
	wget https://proxy.freecdn.ml?url=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip -O v2ray.zip
	wget https://proxy.freecdn.ml?url=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared-linux
	;;
	i386 | i686 )
	wget https://proxy.freecdn.ml?url=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-32.zip -O v2ray.zip
	wget https://proxy.freecdn.ml?url=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -O cloudflared-linux
	;;
	armv8 | arm64 | aarch64 )
	echo arm64
	wget https://proxy.freecdn.ml?url=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-arm64-v8a.zip -O v2ray.zip
	wget https://proxy.freecdn.ml?url=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O cloudflared-linux
	;;
	arm71 )
	wget https://proxy.freecdn.ml?url=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-arm32-v7a.zip -O v2ray.zip
	wget https://proxy.freecdn.ml?url=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O cloudflared-linux
	;;
	* )
	echo ��ǰ�ܹ�$(uname -m)û������
	exit
	;;
esac
chmod +x cloudflared-linux
unzip -d v2ray v2ray.zip
rm -rf v2ray.zip
uuid=$(cat /proc/sys/kernel/random/uuid)
urlpath=$(echo $uuid | awk -F- '{print $1}')
port=$[$RANDOM+10000]
if [ $mode == 1 ]
then
cat>v2ray/config.json<<EOF
{
	"inbounds": [
		{
			"port": $port,
			"listen": "localhost",
			"protocol": "vmess",
			"settings": {
				"clients": [
					{
						"id": "$uuid",
						"alterId": 0
					}
				]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": ""
				}
			}
		}
	],
	"outbounds": [
		{
			"protocol": "freedom",
			"settings": {}
		}
	],
	"policy": {
		"levels": {
			"0": {
				"handshake": 3,
				"connIdle": 60,
				"uplinkOnly": 0,
				"downlinkOnly": 0,
				"bufferSize": 0
			}
		}
	}
}
EOF
fi
if [ $mode == 2 ]
then
cat>v2ray/config.json<<EOF
{
	"inbounds": [
		{
			"port": $port,
			"listen": "localhost",
			"protocol": "vless",
			"settings": {
				"decryption": "none",
				"clients": [
					{
						"id": "$uuid"
					}
				]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": ""
				}
			}
		}
	],
	"outbounds": [
		{
			"protocol": "freedom",
			"settings": {}
		}
	],
	"policy": {
		"levels": {
			"0": {
				"handshake": 3,
				"connIdle": 60,
				"uplinkOnly": 0,
				"downlinkOnly": 0,
				"bufferSize": 0
			}
		}
	}
}
EOF
fi
./v2ray/v2ray run>/dev/null 2>&1 &
./cloudflared-linux tunnel --url http://localhost:$port --no-autoupdate --edge-ip-version $ips --protocol h2mux>argo.log 2>&1 &
sleep 2
clear
echo �ȴ�cloudflare argo���ɵ�ַ
sleep 5
argo=$(cat argo.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
clear
if [ $mode == 1 ]
then
	echo -e vmess�����Ѿ�����, speed.cloudflare.com ���滻ΪCF��ѡIP'\n' > v2ray.txt
	echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"","port":"443","ps":"vmess_tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0) >> v2ray.txt
	echo -e '\n'�˿� 443 �ɸ�Ϊ 2053 2083 2087 2096 8443'\n' >> v2ray.txt
	echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"","port":"80","ps":"vmess","tls":"","type":"none","v":"2"}' | base64 -w 0) >> v2ray.txt
	echo -e '\n'�˿� 80 �ɸ�Ϊ 8080 8880 2052 2082 2086 2095 >> v2ray.txt
fi
if [ $mode == 2 ]
then
	echo -e vless�����Ѿ�����, speed.cloudflare.com ���滻ΪCF��ѡIP'\n' > v2ray.txt
	echo 'vless://'$uuid'@speed.cloudflare.com:443?encryption=none&security=tls&type=ws&host='$argo'&path=#vless_tls' >> v2ray.txt
	echo -e '\n'�˿� 443 �ɸ�Ϊ 2053 2083 2087 2096 8443'\n' >> v2ray.txt
	echo 'vless://'$uuid'@speed.cloudflare.com:80?encryption=none&security=none&type=ws&host='$argo'&path=#vless' >> v2ray.txt
	echo -e '\n'�˿� 80 �ɸ�Ϊ 8080 8880 2052 2082 2086 2095 >> v2ray.txt
fi
rm -rf argo.log
cat v2ray.txt
echo -e '\n'��Ϣ�Ѿ������� v2ray.txt,�ٴβ鿴������ cat v2ray.txt