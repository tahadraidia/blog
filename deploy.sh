SSH_HOST="209.97.182.37"
SSH_PORT="22"
SSH_USER="blogger"
SSH_TARGET_DIR="/home/blogger/www/"
OUTPUTDIR="./public/"

#scp -P $SSH_PORT -rp "$OUTPUTDIR" "$SSH_USER@$SSH_HOST:$SSH_TARGET_DIR"

# Remove Hugo from metadata.
find ./public/ -type f -print0 | xargs -0 sed -i /Hugo/d

# Upload to server.
rsync -a "$OUTPUTDIR" "$SSH_USER@$SSH_HOST:$SSH_TARGET_DIR"
