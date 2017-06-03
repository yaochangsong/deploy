#!/bin/bash


ROOTSPACE="/app/jobs/$1"
WORKSPACE="$ROOTSPACE/workspace"
DOCKFILE="$ROOTSPACE/Dockerfile"
ARTIFACTS_PATH="/app/artifacts/$1"
JOB=$1
PORT=$2

#docker info
IMAGE="myreg:5000/tomcat:latest"
AUTHOR="yaochangsong@dftcmedia.com"
WORKDIR="/opt"
HOST_JAR_DIR="workspace"
EXPOSE="8080"

copy_artifacts()
{
	if ls $ARTIFACTS_PATH/*.jar >/dev/null 2>&1;then
		echo "$ARTIFACTS_PATH/*.jar  exists"
		cp $ARTIFACTS_PATH/*.jar $WORKSPACE
		return
	fi
	echo "$ARTIFACTS_PATH/*.jar not exists"
	exit 0
}

fold_check()
{
	if [ ! -d "$ROOTSPACE" ]; then
		echo "create fold: $ROOTSPACE"	
		mkdir -p $ROOTSPACE
	fi

	if [ ! -d "$WORKSPACE" ]; then
		 echo "create fold: $WORKSPACE"  
		 mkdir -p $WORKSPACE
	fi
}

dockerfile_check()
{
	if [ -f "$DOCKFILE" ]; then
		return
	fi

	echo "create Dockerfile...[$DOCKFILE]"
	echo "FROM $IMAGE" >> $DOCKFILE
	echo "MAINTAINER $AUTHOR" >> $DOCKFILE
	echo "WORKDIR $WORKDIR" >> $DOCKFILE
	echo "COPY $HOST_JAR_DIR/*.jar app.jar" >> $DOCKFILE 
	echo "RUN [\"/bin/bash\", \"-c\", \"source /etc/profile\"]"
	echo "EXPOSE $EXPOSE" >> $DOCKFILE
	echo "CMD [\"java\", \"-jar\", \"app.jar\"]" >> $DOCKFILE
}

docker_run()
{
	echo "get container id:"
	oid=$(docker ps | grep $JOB | awk '{print $1}')
	echo "old id: $oid"
	#	echo "old id: $oid"
	echo ">>stop old container!"
	if [ "$oid" != "" ]; then
		docker stop $oid
		docker rm $oid
	fi
	echo "run ...[$ROOTSPACE/Dockerfile]"

	cd $ROOTSPACE
	IMAGE=$(docker build -t $JOB:latest $ROOTSPACE | tail -1 | awk '{ print $NF }')
	echo "docker build -t $JOB:latest $ROOTSPACE | tail -1 | awk '{ print $NF }'"

	CONTAINER=$(docker run -it -d -p $PORT:$EXPOSE --name=$JOB $IMAGE)
	echo "docker run -it -d -p $PORT:$EXPOSE --name=$JOB $IMAGE"
#	cd $ROOTSPACE
#	IMAGE=$(docker build -t $JOB:latest   $ROOTSPACE |tail -1 | awk '{ print $NF }')
#	echo "docker build $ROOTSPACE|tail -1 | awk '{ print $NF }'"
#	echo "docker run -it -d -p $PORT:$EXPOSE --name=$JOB $IMAGE /bin/bash"
	#CONTAINER=$(docker run -it -d -p $PORT:8080 --name=$JOB -v "$ROOTSPACE/workplace:/usr/local/tomcat/webapps" $IMAGE /bin/bash)
#	CONTAINER=$(docker run -it -d -p $PORT:$EXPOSE --name=$JOB  $IMAGE)

	#RC=$(docker wait $CONTAINER)

#	echo "containerID: $CONTAINER"
	#exit $RC
}

fold_check
copy_artifacts
dockerfile_check
docker_run

