$SSH_HOST="209.97.182.37"
$SSH_PORT="22"
$SSH_USER="blogger"
$SSH_TARGET_DIR="/home/blogger/www/"
$OUTPUTDIR=".\public\"

wsl --cd $PWD ./deploy.sh
