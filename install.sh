#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'
BLUE="\033[36m"

echo "请选择语言 | Please select a language"
echo -e "${YELLOW}Please note that the language you choose will affect the output of the backend program"
echo -e "请注意，你选择的语言将影响后端程序的输出${PLAIN}"
echo -e "${BLUE}However no support for language other than Chinese and English is provided in this installation script${PLAIN}"
echo -e "${BLUE}但是本安装脚本仅提供中文和英文支持${PLAIN}"
echo "1.简体中文(zh_cn)"
echo "2.English(en_us)"
echo "3.Vietnamese(vi_vn)"
read -e language
if [ $language != "1" ] && [ $language != "2" ] && [ $language != "3" ]; then
    echo "输入错误，已退出 | Input error, exit"
    exit;
fi
if [ $language == '1' ]; then
  echo "以全新方式管理你的 Apple ID，基于密保问题的自动化Apple ID检测&解锁程序程序"
  echo "产品官网：appleauto.pro"
  echo "项目TG群：@AppleAutoPro_group"
  echo "==============================================================="
else
  echo "Manage your Apple ID in a new way, an automated Apple ID detection & unlocking program based on security questions"
  echo "Official website: appleauto.pro"
  echo "Project Telegram group: @AppleAutoPro_group"
  echo "==============================================================="
fi
if docker >/dev/null 2>&1; then
    echo "Docker已安装 | Docker is installed"
else
    echo "Docker未安装，开始安装…… | Docker is not installed, start installing..."
    docker version > /dev/null || curl -fsSL get.docker.com | bash
    systemctl enable docker && systemctl restart docker
    echo "Docker安装完成 | Docker installed"
fi
# 检查安装是否成功
if ! docker >/dev/null 2>&1; then
    echo "Docker安装失败，请检查错误信息 | Docker installation failed, please check the error message"
    exit 1
fi
if [ $language == '1' ]; then
  echo "开始安装AppleAutoPro后端"
  echo "请输入API URL（前端域名，格式 http[s]://xxx.xxx）"
  read -e api_url
  echo "请输入API Key"
  read -e api_key
  echo "请输入任务同步周期(单位:分钟，默认15)"
  read -e sync_time
  if [ "$sync_time" = "" ]; then
      sync_time=15
  fi
  echo "是否手动指定任务分批启动数量？"
  echo "回车默认自动计算数量，填写0表示不分批启动，其余数字表示手动指定每批次的账号数"
  read -e batch_num
  if [ "$batch_num" = "" ]; then
      batch_num=-1
      batch_wait=180
  else
      echo "请输入任务分批启动间隔时间(单位:秒，默认180)"
      read -e batch_wait
      if [ "$batch_wait" = "" ]; then
          batch_wait=180
      fi
  fi
else
  echo "Start installing AppleAutoPro backend"
  echo "Please enter API URL (http://xxx.xxx)"
  read -e api_url
  echo "Please enter API Key"
  read -e api_key
  echo "Please enter the task synchronization period (unit: minute, default 15)"
  read -e sync_time
  if [ "$sync_time" = "" ]; then
      sync_time=15
  fi
  echo "Manually specify the number of tasks to start in batches?"
  echo "Press Enter to automatically calculate the number, fill in 0 to start without batching, and other numbers to manually specify the number of accounts per batch"
  read -e batch_num
  if [ "$batch_num" = "" ]; then
      batch_num=-1
      batch_wait=180
  else
      echo "Please enter the task batch start interval (unit: second, default 180)"
      read -e batch_wait
      if [ "$batch_wait" = "" ]; then
          batch_wait=180
      fi
  fi
fi
if docker ps -a --format '{{.Names}}' | grep -q '^appleautopro$'; then
    docker rm -f appleautopro
fi
docker pull pplulee/appleautopro_manager
docker run -d --name=appleautopro --log-opt max-size=1m --log-opt max-file=2 --restart=unless-stopped --network=host -e API_URL=$api_url -e API_KEY=$api_key -e SYNC_TIME=$sync_time -e LANG=$language -e BATCH_NUM=$batch_num -e BATCH_WAIT=$batch_wait -v /var/run/docker.sock:/var/run/docker.sock pplulee/appleautopro_manager
if [ $language = "1" ]; then
  echo "安装完成，容器已启动"
  echo "默认容器名：appleautopro"
  echo "操作方法："
  echo "停止容器：docker stop appleautopro"
  echo "重启容器：docker restart appleautopro"
  echo "查看容器日志：docker logs appleautopro"
else
  echo "Installation completed, container started"
  echo "Default container name: appleautopro"
  echo "Operation method:"
  echo "Stop: docker stop appleautopro"
  echo "Restart: docker restart appleautopro"
  echo "Check status: docker logs appleautopro"
fi
exit 0