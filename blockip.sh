#!/bin/env bash
echo start:` /bin/date +%Y-%m-%d_%H:%M`

LOCAL_DIR=$(cd "$(dirname "$0")";pwd)

LOG_DIR='/home/pirate/programs/nginx/logs'

IS_RELOAD=0

ECHO_INFO=''

#配置文件
CONF_FILE=$LOCAL_DIR/config
BLOCKIP_FILE=/home/pirate/programs/nginx/conf/vhosts/blockip.conf

#最大访问数量
MAX_PHP=500
MAX_IMG=50

#过滤的关键字
GREP_STRING_PHP='php'
GREP_STRING_IMG='/loginimg/'

#检测配置文件是否存在
if [ ! -f $BLOCKIP_FILE -o ! -f $CONF_FILE ];then
	/bin/echo "ERROR: config file not exists!!!"
	/bin/echo 'ERROR: run failure'
	exit 1
fi

#过滤 ip
function findIp()
{
	FILE=$1.log
	STRING=$2
	MAX=$3
	if [ -f $LOG_DIR/$FILE ];then
		/bin/echo `/bin/grep $STRING $LOG_DIR/$FILE | /bin/awk  '{print $2}' | grep -v '119.255.38.86' | /bin/sort | /usr/bin/uniq -c | /bin/awk '{if ($1>'$MAX') print $2}'`
		return 0
	else
		/bin/echo "err log file not found";
	fi
}

#执行插入
function doBan()
{
	IP=$1;
	EXISTS=`/bin/grep $IP $BLOCKIP_FILE`
	if [ "$EXISTS" = "" ];then
		let IS_RELOAD=$IS_RELOAD+1
		ECHO_INFO=${ECHO_INFO}${IP}'\n'
		`echo "deny $IP;" >> $BLOCKIP_FILE`
	fi
}

#重新载入nginx 配置
function reload()
{
	`/usr/bin/sudo /home/pirate/programs/nginx/sbin/nginx -t > $LOCAL_DIR/nginx-t 2>&1`

	IS_OK=`/bin/grep 'ok' $LOCAL_DIR/nginx-t`

	if [ "$IS_OK" != "" ];then
	        `/usr/bin/sudo /home/pirate/programs/nginx/sbin/nginx -s reload`
	else
	        /bin/echo "ERROR: NGINX CONFIG -t fatal!!!"
	fi
}

#每天清除一遍黑名单
function initFile()
{
	NOW_TIME=`/bin/date +%s`
	FILE_TIME=`/usr/bin/stat $BLOCKIP_FILE | /bin/grep Modify | /bin/awk '{print $2}'`
	FILE_TIME=`/bin/date -d "$FILE_TIME" +%s`
	TIME_DATE=`/usr/bin/expr $NOW_TIME - $FILE_TIME`

	if [ "$TIME_DATE" -gt "86400" ];then

		`echo > $BLOCKIP_FILE`
	fi
}

initFile

for FILE in `/bin/cat $CONF_FILE`
do
	ECHO_INFO=${ECHO_INFO}${FILE}"\n"
	for i in `findIp $FILE $GREP_STRING_PHP $MAX_PHP`
	do 
		doBan $i
	done
	for i in `findIp $FILE $GREP_STRING_IMG $MAX_IMG`
	do 
		doBan $i
	done
done

#重新载入 nginx 配置
if [ $IS_RELOAD -ne 0 ];then
	ECHO_INFO=${ECHO_INFO}${IS_RELOAD}'yesreload'
	echo -e $ECHO_INFO
	reload
else
	ECHO_INFO=${ECHO_INFO}${IS_RELOAD}'noreload'
fi


echo over: `/bin/date +%Y-%m-%d_%H:%M`
