#!/bin/bash
api_url=$(docker exec appleauto printenv API_URL)
api_key=$(docker exec appleauto printenv API_KEY)
sync_time=$(docker exec appleauto printenv SYNC_TIME)
language=$(docker exec appleauto printenv LANG)
docker pull pplulee/appleautopro
docker rm -f appleauto
docker run -d --name=appleauto --log-opt max-size=1m --log-opt max-file=2 --restart=always --network=host -e API_URL=$api_url -e API_KEY=$api_key -e SYNC_TIME=$sync_time -e LANG=$language -v /var/run/docker.sock:/var/run/docker.sock pplulee/appleautopro
docker rmi sahuidhsu/appleauto_backend
echo "AppleAutoPro后端已更新 | AppleAutoPro backend updated"
