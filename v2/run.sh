#!/bin/bash  
export PATH=$PATH:/usr/local/java/jdk1.8.0_161/bin
PROG_NAME=$0
JOB=$1
EV=$2
ACT=$3
APP_HOME=$4
APP_PORT=$5


usage() {
    echo "Usage: $PROG_NAME JOB EV  {start|stop|restart|deploy}  WORKSPACE PORT"
    exit 2
}
#帮助，参数个数过滤
if [ "$JOB" == "help" -o "$JOB" == "--help" ]; then
        usage
        exit 1
fi

if [ $# != 5 ]; then
        echo "参数个数错误！！"
        usage
        exit 1
fi


CMD="java -jar"
#TYPE=${JOB##*.}
TYPE=war

ARTIFACTS_PATH="/app/artifacts/${JOB}"
HEALTH_CHECK_URL=http://127.0.0.1:${APP_PORT}  # 应用健康检查URL
APP_START_TIMEOUT=50     # 等待应用启动的时间

APP_WAR_HOME=${APP_HOME}              #war包jetty容器路径
APP_WAR_LOG=${APP_HOME}/logs          #war包运行log路径 
APP_WAR_FILE=`cd ${ARTIFACTS_PATH}; ls *.war|awk '{print $1}'|head -n 1`  #获取war包文件名

APP_JAR_HOME=${APP_HOME}/${JOB}       #jar包存放路径
APP_JAR_LOG=${APP_JAR_HOME}/logs       #jar包运行log路径
APP_JAR_FILE=`cd ${ARTIFACTS_PATH}; ls *.jar|awk '{print $1}'|head -n 1`  #获取jar包文件名


health_check() {
    exptime=0
    echo "checking ${HEALTH_CHECK_URL}"
    while true
    do
        status_code=`/usr/bin/curl -L -o /dev/null --connect-timeout 5 -s -w %{http_code}  ${HEALTH_CHECK_URL}`
        if [ x$status_code != x200 ];then
            sleep 1
            ((exptime++))
            echo -n -e "\rWait app to pass health check: $exptime..."
        else
            break
        fi
        if [ $exptime -gt ${APP_START_TIMEOUT} ]; then
            echo
            echo 'app start failed'
            exit 1
        fi
    done
    echo "check ${HEALTH_CHECK_URL} success"
}

stop_check()
{
    stopexptime=0
    echo "stop checking ${HEALTH_CHECK_URL}"
    while true
    do
        status_code=`/usr/bin/curl -L -o /dev/null --connect-timeout 5 -s -w %{http_code}  ${HEALTH_CHECK_URL}`
	echo "status_code=${status_code}"
        if [ x$status_code != x000 ];then
            sleep 1
            ((stopexptime++))
            echo -n -e "\rWait stop: $stopexptime..."
        else
            break
        fi
        if [ $stopexptime -gt ${APP_START_TIMEOUT} ]; then
            echo
            echo 'app stop failed'
            exit 1
        fi
    done
    echo "stop ${HEALTH_CHECK_URL} success"
}


function copy_artifacts()
{
	echo "[copy file...]"
        if [ "$TYPE" == "jar" ]; then
		if ls $ARTIFACTS_PATH/$APP_JAR_FILE >/dev/null 2>&1;then
                	echo "cp $ARTIFACTS_PATH/$APP_JAR_FILE $APP_JAR_HOME/"
                	cp $ARTIFACTS_PATH/$APP_JAR_FILE $APP_JAR_HOME/
                	return
        	fi
        	echo "$ARTIFACTS_PATH/$APP_JAR_FILE not exists"
        	exit 0
	elif [ "$TYPE" == "war" ]; then
                if ls ${ARTIFACTS_PATH}/${APP_WAR_FILE} >/dev/null 2>&1;then
			if [ ! -d "${APP_WAR_HOME}" ]; then
                        	echo "workspace id not valid:$APP_WAR_HOME"
                        	return
                	fi
			rm -rf ${APP_WAR_HOME}/webapps/ROOT/*
                        echo "rm -rf ${APP_WAR_HOME}/webapps/ROOT/*: $?"
			cp ${ARTIFACTS_PATH}/${APP_WAR_FILE} ${APP_WAR_HOME}/webapps/ROOT
			echo "cp ${ARTIFACTS_PATH}/${APP_WAR_FILE} ${APP_WAR_HOME}/webapps/ROOT: $?"
			jar -xvf  ${APP_WAR_HOME}/webapps/ROOT/${APP_WAR_FILE} -d ${APP_WAR_HOME}/webapps/ROOT/ >/dev/null 2>&1
			echo "jar -xvf ${APP_WAR_HOME}/webapps/ROOT/${APP_WAR_FILE}: $?"
			rm ${APP_WAR_HOME}/webapps/ROOT/${APP_WAR_FILE}
			echo "rm ${APP_WAR_HOME}/webapps/ROOT/${APP_WAR_FILE}: $?"
                        return
                fi
		echo "${ARTIFACTS_PATH}/${APP_WAR_FILE} not found!!"
	else
		echo "others type!"
	fi
}


stop(){  
	echo "[stop $TYPE...]"
	if [ "$TYPE" == "jar" ]; then
        	ps -ef|grep "$APP_JAR_HOME/$APP_JAR_FILE"|grep -v grep|awk '{print $2}'|while read pid 
		do
			echo "kill -9  $pid"
			kill  -9 $pid
		done
	elif [ "$TYPE" == "war" ]; then
		if [ ! -d "$APP_WAR_HOME" ]; then
 			echo "workspace id not valid:$APP_WAR_HOME"
			return
		fi
		$APP_WAR_HOME/jetty.sh stop >  ${APP_WAR_LOG}/log 2>&1 &
                echo "stop jetty: $?"
		
        else
                echo "stop others type!"
        fi
}

start(){  
	echo "[start $TYPE...]"
	if [ "$TYPE" == "jar" ]; then
		echo "$CMD $APP_JAR_HOME/$APP_JAR_FILE -Dspring.profiles.active=$EV > /dev/null &"
		$CMD $APP_JAR_HOME/$APP_JAR_FILE  -Dspring.profiles.active=$EV > ${APP_JAR_LOG}/log 2>&1 &
		echo $?
			
	elif [ "$TYPE" == "war" ]; then
		if [ ! -d "$APP_WAR_HOME" ]; then
                        echo "workspace id not valid:$APP_WAR_HOME"
                        return
                fi
                $APP_WAR_HOME/jetty.sh start > ${APP_WAR_LOG}/log 2>&1 &
        else
                echo "start others type!"
        fi
}

init_check(){
	
	echo  "[init check...]"
	TYPE=${APP_JAR_FILE##*.}
	if [ "$TYPE" != "jar" ]; then
		TYPE=${APP_WAR_FILE##*.}
		if [ "$TYPE" != "war" ]; then
			echo "File Type Error!! [$TYPE]"
			exit 2
		fi
		echo  "File Type: $TYPE"
	fi
	
	if [ "$TYPE" == "jar" ]; then
		if [ ! -f "$ARTIFACTS_PATH/$APP_JAR_FILE" ]; then
                	echo "file is not valid:$ARTIFACTS_PATH/$APP_JAR_FILE!!"
                	exit 1
        	fi
 		echo "Create Jar App Home and Log Path: ${APP_JAR_HOME}, ${APP_JAR_LOG}"
		mkdir -p ${APP_JAR_HOME}
		mkdir -p ${APP_JAR_LOG}
	elif [ "$TYPE" == "war" ]; then
		if [ ! -f "$ARTIFACTS_PATH/$APP_WAR_FILE" ]; then
                       	echo "file is not valid:$ARTIFACTS_PATH/$APP_WAR_FILE!!"
                        exit 1
                fi
		echo "Create War App Home and Log Path: ${APP_WAR_HOME}, ${APP_WAR_LOG}"
		mkdir -p ${APP_WAR_HOME}
		mkdir -p ${APP_WAR_LOG}
	fi

	if [ "$APP_PORT" == "" ]; then
		APP_PORT="8080"
	fi
}

 
init_check

case "$ACT" in  
start)  
	start  
	;;  
stop)  
	stop 
	;;  
restart)  
	stop
	start  
	;;
deploy) 
	stop
	stop_check
	copy_artifacts
	start
	health_check
	;;
	
*)  
	usage
	;;  
esac  
