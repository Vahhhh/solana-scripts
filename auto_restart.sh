#!/bin/bash
# set -x -e

echo "###################### WARNING!!! ###################################"
echo "###   This script will perform the following operations:          ###"
echo "###   * check your slot and rpc slot                              ###"
echo "###   * delete ledger and run snapsot-finder (optional)           ###"
echo "###   * restart validator service and send message                ###"
echo "###   * wait for catchup send message                             ###"
echo "###                                                               ###"
echo "###   *** Script provided by MARGUS.ONE                           ###"
echo "#####################################################################"
echo

NODE_NAME=""
RM_LEDGER="1"                       # delete ledger (1 = YES; 0 = NO)
FINDER="1"                          # delete local snapsot and download new with snapshot-finder (1 = YES; 0 = NO, use local snapshot) not working if RM_LEDGER="0"
LEDGER="/root/solana/ledger"        # path to ledger (default: /root/solana/ledger)
SNAPSHOTS="/root/solana/ledger"  # path to snapshots (default: /root/solana/ledger)
BEHIND="2000"                       # enter the value of the slots, if the node is behind, it will restart
NETWORK=""
RPC_URL="https://api.${NETWORK}.solana.com"

ICON=`echo -e '\U0001F514'`
PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
send_message() {
telegram_bot_token=""
telegram_chat_id=""
Title="$1"
Message="$2"
curl -s \
 --data parse_mode=HTML \
 --data chat_id=${telegram_chat_id} \
 --data text="<b>${Title}</b>%0A${Message}" \
 --request POST https://api.telegram.org/bot${telegram_bot_token}/sendMessage
}

catchup_info() {
  while true; do
    rpcPort=$(ps aux | grep solana-validator | grep -Po "\-\-rpc\-port\s+\K[0-9]+")
    sudo -i -u root solana catchup --our-localhost $rpcPort
    status=$?
    if [ $status -eq 0 ];then break
    fi
    echo "waiting next 30 seconds for rpc"
    sleep 30
  done
}

THEIR_SLOT=$(solana slot)
OUR_SLOT=$(solana slot -ul)
if [ "$(( "$OUR_SLOT" + "$BEHIND" ))" -lt "$THEIR_SLOT" ];then
	systemctl stop solana
if [ "$RM_LEDGER" = "1" ];then 
if [ "$FINDER" = "1" ];then
	rm -fr ${LEDGER}/*
  rm -fr ${SNAPSHOTS}/*
  cd /root/solana
  rm -fr solana-snapshot-finder
  sudo apt-get update
  sudo apt-get install python3-venv git -y
  git clone https://github.com/c29r3/solana-snapshot-finder.git
  cd solana-snapshot-finder
  python3 -m venv venv
  source ./venv/bin/activate
  pip3 install -r requirements.txt
  python3 snapshot-finder.py --snapshot_path ${SNAPSHOTS} -r ${RPC_URL}
else
 rm -fr "${LEDGER}/!(*.tar.zst)"
 rm -fr "${SNAPSHOTS}/!(*.tar.zst)"
fi
fi
	systemctl start solana
  send_message "${ICON} Solana alert! ${NODE_NAME}" "Solana service has been restarted!"
  send_message "${ICON} Solana alert! ${NODE_NAME}" "$(catchup_info)"
else
	echo "All good! Restart is not required..."
fi
