#!/bin/bash

# @sacloud-name "yum update"
# @sacloud-once
# @sacloud-desc yum updateを実行します。完了後自動再起動します。
# @sacloud-desc （このスクリプトは CentOS でのみ動作します）
# @sacloud-require-archive distro-centos
# @sacloud-checkbox default= noreboot "yum update完了後に再起動しない"

yum -y update || exit 1
WILL_NOT_REBOOT=@@@noreboot@@@

if [ -z ${WILL_NOT_REBOOT} ]; then
    WILL_NOT_REBOOT="0"
fi

if [ ${WILL_NOT_REBOOT} != "1" ];then
  echo "rebooting..."
  sh -c 'sleep 10; reboot' &
fi
exit 0