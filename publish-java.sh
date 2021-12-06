#!/bin/bash -l

########################################
# 发布构建springboot代码
# 作者：ellen
# 版本：v1
########################################


ENV_TEST=('192.168.0.49' '192.168.0.44')
ENV_PROD=('192.168.0.49' '192.168.0.44')

# 需要发布的IP
ENV_IP=''
# 需要构建的IP数组 根据环境获取不通的IP数组
ENV_IP_ARRAY=''

# 发布的包名
PACKAGE_NAME=$1
# 发布的环境
PUBLISH_EVN=$2

# git tag
GIT_TAG=$3

# 发布的用户
PUBLISH_ENV_USER='root'


# 根目录
DIR_ROOT=/data

# 发布的文件目录
PUBLISH_DIR=${DIR_ROOT}/dev
# 发布的日志目录
LOG_DIR=${DIR_ROOT}/dev/logs
# 本地的构建目录
BUILD_DIR=/var/lib/jenkins/workspace/java

BACKUP_DIR=${DIR_ROOT}/bak


# 进程号字符串
PID_S='$!'

# awk 获取进程号字符串
AWK_S='$2'

# 存放版本文件名
VERSION_FILE='.version'


# 切换分支 2021-11 第一版 忘记加上分支切换
cd ${BUILD_DIR} && git checkout ${GIT_TAG}



# 公共组件 先mvn clean package 再 mvn install  这里包名是穿进来的 如果是每次构建都必须构建公共包 那么可以直接全部通过一个for循环构建安装
if [ "${PACKAGE_NAME}" == 'component-parent' -o "${PACKAGE_NAME}" == 'component-commons' -o "${PACKAGE_NAME}" == 'component-domain' -o "${PACKAGE_NAME}" == 'component-feign-service' ];then
    echo '公共组件'
    cd ${BUILD_DIR}/${PACKAGE_NAME} && mvn clean package && mvn install
    exit
fi

# 根据环境获取不通的IP数组
if [ ${PUBLISH_EVN} == 'test' ];then
    ENV_IP_ARRAY=${ENV_TEST[*]}
fi
if [ ${PUBLISH_EVN} == 'prod' ];then
    ENV_IP_ARRAY=${ENV_PROD[*]}
fi

# 构建打包
echo '开始构建'
cd ${BUILD_DIR}/${PACKAGE_NAME} && mvn clean package


# 写入版本号
echo ${GIT_TAG} > ${BUILD_DIR}/${PACKAGE_NAME}/${VERSION_FILE}-${PACKAGE_NAME}


sleep 3

for i in ${ENV_IP_ARRAY[*]}; do
    # 发布到哪台服务器
    ENV_IP="${i}"

    echo ENV_IP

    # 创建远程目录
    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "mkdir -pv ${PUBLISH_DIR}; mkdir -pv ${LOG_DIR}; exit"

    # 获取旧的版本号 可用于备份
    GIT_TAG_OLD=`ssh ${PUBLISH_ENV_USER}@${ENV_IP} "cat ${PUBLISH_DIR}/${VERSION_FILE}-${PACKAGE_NAME}"`

    # 将版本号发送到远程
    scp ${BUILD_DIR}/${PACKAGE_NAME}/${VERSION_FILE}-${PACKAGE_NAME} ${PUBLISH_ENV_USER}@${ENV_IP}:${PUBLISH_DIR}

    # 备份当前版本
    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "mkdir -pv ${BACKUP_DIR}/${GIT_TAG_OLD} && mv -f ${PUBLISH_DIR}/${PACKAGE_NAME}*.jar ${BACKUP_DIR}/${GIT_TAG_OLD}"

    # 删除远程的文件
    #ssh ${PUBLISH_ENV_USER}@${ENV_IP} "cd ${PUBLISH_DIR} && ls ${PACKAGE_NAME}*.jar | xargs rm -f"

    # 获取完成的包名字
    JAR_NAME=`cd ${BUILD_DIR}/${PACKAGE_NAME}/target && ls ${PACKAGE_NAME}*.jar`

    #echo ${JAR_NAME}

    # 上传到远程目录
    scp ${BUILD_DIR}/${PACKAGE_NAME}/target/${JAR_NAME} ${PUBLISH_ENV_USER}@${ENV_IP}:${PUBLISH_DIR}
    echo "scp"

    # 还是这种方式杀进程吧 上面那种可能有问题的
    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "ps aux | grep java | grep .jar | grep ${PACKAGE_NAME} | awk '{print ${AWK_S}}' | xargs kill -9"

    # 启动服务 这里用的进程号 也可以使用ps之类的找到进程号
    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "nohup $JAVA_HOME/bin/java -Xms128m -Xmx384m -jar ${PUBLISH_DIR}/${JAR_NAME} > ${LOG_DIR}/${JAR_NAME/.jar/.log} 2>&1 & echo ${PID_S} >  ${LOG_DIR}/${PACKAGE_NAME}.pid &"
done

# 需要sleep的包
if [ "${PACKAGE_NAME}" == 'configure' -o "${PACKAGE_NAME}" == 'register-center' ];then
    sleep 30
fi

