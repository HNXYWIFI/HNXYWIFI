#!/bin/sh

. /lib/functions.sh

tmp=""
now_version=$(cat /etc/openwrt_version)
board_name=$(cat /tmp/sysinfo/board_name)
#remote_url="https://ghproxy.com/https://github.com/HNXYWIFI/HNXYWIFI/blob/master/firmware/pdv/$board_name"
remote_url="http://hnxywifi.top:5244/d/HNXYWIFI/firmware/new/$board_name"
local_version_file="/tmp/new_version"

check_firmware_version()
{
    wget $remote_url/new_version.txt -O $local_version_file
    remote_version=$(cat $local_version_file)
    if [ $remote_version -gt $now_version ];then
        return 1
    else
        return 0
    fi
}

fill_64()
{
	echo -n $1 > /tmp/esdialerhn/$2.bin
	tmp=$1
	len=`echo $1 | wc -c`
	while [ $len -lt 65 ]
	do
		echo -ne "\x00" >> /tmp/esdialerhn/$2.bin
		len=`expr $len + 1`
	done
}
index_uboot()
{
	username=`uci get esdialerhn.@esdialerhn[0].username`
	password=`uci get esdialerhn.@esdialerhn[0].password`
	hostname=`uci get esdialerhn.@esdialerhn[0].hostname`
	checkma=`uci get esdialerhn.@esdialerhn[0].checkma`
	chelun=`uci get esdialerhn.@esdialerhn[0].chelun`
	wifiname=`uci get wireless.@wifi-iface[0].ssid`
	wifipass=`uci get wireless.@wifi-iface[0].key`
	fill_64 $username username
	fill_64 $password password
	fill_64 $hostname hostname
	fill_64 $checkma checkma
	fill_64 $chelun chelun
	fill_64 $wifiname wifiname
	fill_64 $wifipass wifipass
}
write_ub()
{
    mtd write /tmp/new_ub.bin /dev/mtd13
    mtd write /tmp/new_ub.bin /dev/mtd14

}

set_ub_bin() {
	dd if=/tmp/uboot.bin of=/tmp/new_ub.bin bs=1 count=$(printf %d $1)
	echo -ne "\x11" >> /tmp/new_ub.bin
	index_uboot
	dd if=/dev/zero of=/tmp/zero.bin bs=1 count=4095
	cat /tmp/zero.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/username.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/password.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/hostname.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/checkma.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/chelun.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/wifiname.bin >> /tmp/new_ub.bin
	cat /tmp/esdialerhn/wifipass.bin >> /tmp/new_ub.bin
	write_ub
}


check_md5sum()
{
    wget -O /tmp/op.sha256sum $remote_url/op.sha256sum
	if [ $? != 0 ];then
		echo "sha256sum下载失败，请检查网络连接后再试..."
		exit 1
	fi
    remote_firmware_md5=$(cat /tmp/op.sha256sum)
    firmware_md5=$(/usr/bin/sha256sum $1 | awk '{print $1}')
    if [ "$remote_firmware_md5" != "$firmware_md5" ];then
        return 0
    else
        return 1
    fi
}

flash_op()
{
    sysupgrade -f /tmp/op.bin
}

dl_new_firmware()
{
    wget -O /tmp/op.bin $remote_url/op.bin
	if [ $? != 0 ];then
		echo "固件下载失败，请检查网络连接后再试..."
		exit 1
	fi
    check_md5sum /tmp/op.bin
    if [ $? != 0 ];then
        echo "固件MD5校验成功，即将进行更新..."
		sleep 10s
        flash_op $1 $2
    else
        echo "固件MD5校验失败，请检查网络连接后再试..."
		exit 1
    fi
}

check_update()
{
    echo "有新的固件更新...pdv"
    echo "将进行更新操作."
    dl_new_firmware $1 $2
}

index() {
	dd if=/dev/mtd13 of=/tmp/uboot.bin
	mkdir /tmp/esdialerhn
	dd if=/tmp/uboot.bin of=/tmp/esdialerhn/en.txt bs=1 count=1 skip=$(printf %d $1)
	set_ub_bin $1
	sleep 5
}


board=$board_name
check_firmware_version
if [ $? != 0 ];then
	echo "检测到新的固件版本，即将进行更新..."
	index "0x178000"
	check_update "nand" "0x200000"


else
	echo "当前固件已是最新版本，无需更新..."
	exit 0
fi
