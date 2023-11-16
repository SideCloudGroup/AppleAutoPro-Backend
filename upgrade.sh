#!/bin/bash
api_url=$(docker exec appleauto printenv API_URL)
api_key=$(docker exec appleauto printenv API_KEY)
sync_time=$(docker exec appleauto printenv SYNC_TIME)
language=$(docker exec appleauto printenv LANG)
docker pull pplulee/appleautopro_manager:latest
docker pull pplulee/appleautopro:latest
docker rm -f appleauto
docker run -d --name=appleautopro --log-opt max-size=1m --log-opt max-file=2 --restart=unless-stopped --network=host -e API_URL="$api_url" -e API_KEY="$api_key" -e SYNC_TIME="$sync_time" -e LANG="$language" -v /var/run/docker.sock:/var/run/docker.sock pplulee/appleautopro_manager
docker rmi sahuidhsu/appleauto_backend
echo "默认容器名：appleautopro | Default container name: appleautopro"
echo "AppleAutoPro后端已更新 | AppleAutoPro backend updated"
