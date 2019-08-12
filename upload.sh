#!/bin/bash

# 此脚本必须放在.podspec同一层级下

oldVersionString=`grep -E 's.version.*=' XNLocationTool.podspec`

#分割字符串
arry=(${oldVersionString//./ })
#获取数组长度
arrLength=${#arry[@]}

mainString=`tr -cd 0-9 <<<"${arry["${arrLength}-3"]}"`
subString=`tr -cd 0-9 <<<"${arry["${arrLength}-2"]}"`
shortString=`tr -cd 0-9 <<<"${arry["${arrLength}-1"]}"`
#提升版本
NewShortString="$(($shortString + 1))"
#替换字符串
newVersionString=${oldVersionString/"'${mainString}.${subString}.${shortString}'"/"'${mainString}.${subString}.${NewShortString}'"}


sed -i "" "s/${oldVersionString}/${newVersionString}/g" $(dirname "${BASH_SOURCE[0]}")/XNLocationTool.podspec

echo "oldVersion is ${oldVersionString},newVersion is ${newVersionString}"

read -p "Please enter comment > " comment

git add .
git commit -am ${comment}
git tag "${mainString}.${subString}.${NewShortString}"
git push origin master --tags
pod trunk push --verbose --allow-warnings --use-libraries --use-modular-headers
