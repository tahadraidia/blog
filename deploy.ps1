$SSH_HOST="209.97.182.37"
$SSH_PORT="22"
$SSH_USER="blogger"
$SSH_TARGET_DIR="/home/blogger/www/"
$OUTPUTDIR=".\public\"

#scp -P $SSH_PORT -r "$OUTPUTDIR"* "$SSH_USER@${SSH_HOST}:$SSH_TARGET_DIR"
# Somehow, this PS1 script does not work as intended, hence we use SHELL script with WSL instead.
# Due the usage of different laptops, WSL won't be installed on all of them so we keep old PS1 code here.
wsl --cd $PWD ./deploy.sh
