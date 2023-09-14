#!/bin/sh

tmp=""
now_version=$(nvram get hn_fwver | grep -oE "[0-9]+\.[0-9]+\.[0-9]" | sed 's/\.//g')
board_name=` nvram get computer_name `
#remote_url="https://ghproxy.com/https://github.com/HNXYWIFI/HNXYWIFI/blob/master/firmware/pdv/$board_name"
remote_url="http://hnxywifi.top:5244/d/HNXYWIFI/firmware/pdv/$board_name"
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
index_nvram()
{
	username=`nvram get esdialerhn_username`
	password=`nvram get esdialerhn_password`
	hostname=`nvram get esdialerhn_hostname`
	checkma=`nvram get esdialerhn_checkma`
	chelun=`nvram get esdialerhn_chelun`
	wifiname=`nvram get rt_ssid`
	wifipass=`nvram get rt_wpa_psk`
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
	mtd_write write /tmp/new_ub.bin Bootloader

}

set_ub_bin() {
	dd if=/tmp/uboot.bin of=/tmp/new_ub.bin bs=1 count=$(printf %d $1)
	echo -ne "\x11" >> /tmp/new_ub.bin
	index_nvram
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
    wget -O /tmp/pdv.sha256sum $remote_url/pdv.sha256sum
	if [ $? != 0 ];then
		echo "sha256sum下载失败，请检查网络连接后再试..."
		exit 1
	fi
    remote_firmware_md5=$(cat /tmp/pdv.sha256sum)
    firmware_md5=$(/usr/bin/sha256sum $1 | awk '{print $1}')
    if [ $remote_firmware_md5 != $firmware_md5 ];then
        return 0
    else
        return 1
    fi
}

flash_pdv()
{
	if [ $1 == "spi" ];then
        /sbin/mtd_storage.sh reset && nvram set restore_defaults=1 && nvram commit && /usr/share/hnxywifi/esdialerhn.sh stop
		mtd_write -r write /tmp/pdv.bin firmware
	elif [ $1 == "nand" ];then
		dd if=/tmp/pdv.bin of=/tmp/part1.bin bs=1 count=$(printf %d $2)
		dd if=/tmp/pdv.bin of=/tmp/part2.bin bs=1 skip=$(printf %d $2)
		mtd write /tmp/part1.bin kernel
		mtd -r write /tmp/part2.bin ubi
	fi
}

dl_new_firmware()
{
    wget -O /tmp/pdv.bin $remote_url/pdv.bin
	if [ $? != 0 ];then
		echo "固件下载失败，请检查网络连接后再试..."
		exit 1
	fi
    check_md5sum /tmp/pdv.bin
    if [ $? != 0 ];then
        echo "固件MD5校验成功，即将进行更新..."
		sleep 10s
        flash_pdv $1 $2
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
	dd if=/dev/mtd0 of=/tmp/uboot.bin
	mkdir /tmp/esdialerhn
	dd if=/tmp/uboot.bin of=/tmp/esdialerhn/en.txt bs=1 count=1 skip=$(printf %d $1)
	set_ub_bin $1
	sleep 5
}


board=$board_name
check_firmware_version

if [ $? != 0 ];then
	echo "检测到新的固件版本，即将进行更新..."
	case "$board" in
	youhua,wr1200js|\
	psg1218a|\
	ZTE-E8820V2|\
	WR1200JS)
		index "0x28000"
		check_update "spi"
		;;
	zte,e8820s|\
	ZTE-E8820S)
		index "0x78000"
		check_update "nand" "0x200000"
		;;
	r6220)
		index "0x98000"
		check_update "nand" "0x400000"
		;;
	esac
else
	echo "当前固件已是最新版本，无需更新..."
	exit 0
fi
