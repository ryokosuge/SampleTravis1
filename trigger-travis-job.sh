#!/bin/sh -f
BRANCH=$1
USER=$2
REPOSITORY=$3

# TravisCI上で動くの前提で環境変数使っているのでローカルで動かす場合は適時書き換えてください
# TRAVIS_REPO_SLUGN:	jobのbranch
# TRAVIS_API_TOKEN:	TravisCIのユーザー管理画面から取得可能

LAST_COMMIT_LOG=`git log -n 1 HEAD --pretty=format:"%h - %an, %ar"`
MESSAGE="Triggered by upstream build of $TRAVIS_REPO_SLUG commit "$LAST_COMMIT_LOG""
echo $MESSAGE
BODY="{
\"request\": {
  \"branch\": \"$BRANCH\",
  \"message\": \"$MESSAGE\"
}}"

echo $BODY

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token ${TRAVIS_ACCESS_TOKEN}" \
  -d "$BODY" \
  https://api.travis-ci.com/repo/${USER}%2F${REPOSITORY}/requests
