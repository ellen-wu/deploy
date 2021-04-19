#!/bin/bash -l

########################################
# 发布构建前端代码
# 作者：ellen
# 版本：v1
########################################


ENV_TEST=('192.168.0.49' '192.168.0.44')
ENV_PROD=('192.168.0.49' '192.168.0.44')

# 发布环境
PUBLISH_EVN=$1
# git tag
GIT_TAG=$2

# 本地的构建目录
BUILD_DIR=/var/lib/jenkins/workspace/node

# 需要发布的IP
ENV_IP='192.168.0.44'
# 需要构建的IP数组 根据环境获取不通的IP数组
ENV_IP_ARRAY=''
# 发布的用户
PUBLISH_ENV_USER='root'



# 根据环境获取不通的IP数组
if [ ${PUBLISH_EVN} == 'test' ];then
    ENV_IP_ARRAY=${ENV_TEST[*]}
fi
if [ ${PUBLISH_EVN} == 'prod' ];then
    ENV_IP_ARRAY=${ENV_PROD[*]}
fi


# 根目录
DIR_ROOT=/data

# 发布到哪个目录
PUBLISH_DIR=${DIR_ROOT}/test/pub
# 发布文件对应的软链接
PUBLISH_LINK=${DIR_ROOT}/test/pub/publish
# 代码的备份目录
BACKUP_DIR=${DIR_ROOT}/test/bak
# 旧版本号
VERSION_OLD='0'

# 存放版本文件名
VERSION_FILE='.version-node'


# 构建项目
cd ${BUILD_DIR} && npm install && npm run build

# 将版本号写入文件 以便后面的版本发布，回滚 这里直接使用的是package中的版本号 也可以使用git标签
cat ${BUILD_DIR}/package.json | grep '"version":' | awk -F'"' '{print $4}' > ${BUILD_DIR}/${VERSION_FILE}

VERSION=`cat ${BUILD_DIR}/${VERSION_FILE}`
cp -Rf ${BUILD_DIR}/${VERSION_FILE} ${BUILD_DIR}/dist/


# 重复打包 删除旧包
if [ -d ${BUILD_DIR}/v${VERSION} ]; then
    rm -rf ${BUILD_DIR}/v${VERSION}
fi

# 重命名 打包
mv -f ${BUILD_DIR}/dist v${VERSION}
tar czf v${VERSION}.tar.gz v${VERSION}


for i in ${ENV_IP_ARRAY[*]}; do

    ENV_IP="${i}"

    # 获取旧的版本号 TODO
    VERSION_OLD=`ssh ${PUBLISH_ENV_USER}@${ENV_IP} "cat ${PUBLISH_DIR}/${VERSION_FILE}"`


    # 创建远程目录
    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "mkdir -pv ${PUBLISH_DIR}; mkdir -pv ${BACKUP_DIR}; exit"

    # scp
    scp ${BUILD_DIR}/v${VERSION}.tar.gz ${PUBLISH_ENV_USER}@${ENV_IP}:${PUBLISH_DIR}

    # 版本相等，删除旧版本
    #if [ "${VERSION}" == "${VERSION_OLD}" ];then
    #    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "rm -rf ${PUBLISH_DIR}/${VERSION}"
    #fi

    # 远程打开发布目录 解压文件 删除软连接 建立新版本的软连接 删除新版本的打包文件 复制版本号到发布目录
    ssh ${PUBLISH_ENV_USER}@${ENV_IP} "cd ${PUBLISH_DIR} && tar xf v${VERSION}.tar.gz && rm -f ${PUBLISH_LINK} && ln -s ${PUBLISH_DIR}/v${VERSION} ${PUBLISH_LINK} && rm -f v${VERSION}.tar.gz && cp -f v${VERSION}/${VERSION_FILE} ${PUBLISH_DIR}"
done