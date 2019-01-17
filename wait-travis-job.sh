#!/bin/sh

BRANCH=$1
USER=$2
REPOSITORY=$3
REPO_SLUG=${USER}/${REPOSITORY}

# 60秒 * 10回sleep = 10分間最大待つ
# 短いようであれば伸ばす
ITERATION_RETRY_SLEEP=10
ITERATION_MAX=60

BUILD_STATE=""
ITERATION=0

function getBuildInfo() {
	echo "* `date '+%Y-%m-%d %H:%M:%S'` [${ITERATION} requesting ${REPO_SLUG}]"
	BUILD_INFO=$(curl -s -X GET \
		-H "Content-Type: application/json" \
		-H "Accept: application/json" \
		-H "Travis-API-Version: 3" \
		-H "Authorization: token ${TRAVIS_ACCESS_TOKEN}" \
		https://api.travis-ci.com/repo/${USER}%2F${REPOSITORY}/builds\?branch.name\=${BRANCH}\&sort_by\=started_atdesc\&limit\=1)

	if [[ ${BUILD_INFO} == *"access denied"* ]]; then
		echo " X access denied"
		exit 1
	fi
	if [[ ${BUILD_INFO} == *"not_found"* ]]; then
		echo " X not found"
		exit 1
	fi

	BUILD_STATE=$(echo "${BUILD_INFO}" | grep -oP '"state":.*?[^\\]",'|head -n1| awk -F "\"" '{print $4}')
	BUILD_ID=$(echo "${BUILD_INFO}" | grep '"id": '|head -n1| awk -F'[ ,]' '{print $8}')
}

echo " * now waiting pending Unity-Dev tests build"

while [[ ( "${BUILD_STATE}" != "created" ) && ( "${BUILD_STATE}" != "started" ) && ( ${ITERATION} -lt ${ITERATION_MAX} ) ]]
do
	if [ ${ITERATION} -ne 0 ]; then
		sleep ${ITERATION_RETRY_SLEEP}
	fi

	getBuildInfo

	DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
	echo " * ${DATETIME} https://travis-ci.com/${REPO_SLUG}/builds/${BUILD_ID} => ${BUILD_STATE}"
	if [[ ( "${BUILD_STATE}" != "created" ) && ( "${BUILD_STATE}" != "started" ) ]]; then
		ITERATION=$((ITERATION + 1))
	fi
done

# wait 'passed' or 'failed' final state
while [[ ( "${BUILD_STATE}" != "passed" ) && ( "${BUILD_STATE}" != "failed" ) && ( ${ITERATION} -lt ${ITERATION_MAX} ) ]]
do
	if [ ${ITERATION} -ne 0 ]; then
		sleep ${ITERATION_RETRY_SLEEP}
	fi

	getBuildInfo

	DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
	echo " * ${DATETIME} https://travis-ci.com/${REPO_SLUG}/builds/${BUILD_ID} => ${BUILD_STATE}"
	if [[ ( "${BUILD_STATE}" != "passed" ) && ( "${BUILD_STATE}" != "failed" ) ]]; then
		ITERATION=$((ITERATION + 1))
	fi
done

# do we reach timeout ?
if [ ${ITERATION} -ge ${ITERATION_MAX} ]; then
	DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
	echo " * ${DATETIME} build #${BUILD_ID} Timeout, state was \"${BUILD_STATE}\" after $((ITERATION * ITERATION_RETRY_SLEEP)) seconds"
	echo " * WARN: build doesn't failed for QA timeout case, anyway please check QA results"
	exit 0
fi

if [ "${BUILD_STATE}" == "failed" ]; then
	exit 1
fi
