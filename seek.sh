. $HOME/.profile > /dev/null 2>&1
set -x
_KillOpmnSess () {
    sleep 5
    USR=$(whoami)
    OPMNPRC="opmn"

    for PID in $(ps -fu $USR| grep "$OPMNPRC"| grep -v grep| awk '{print $2}'); do
        echo "  Killing OPMN service ${OPMNPRC}: ${PID}"
        kill -9 ${PID}
    done
}

echo "#########Stopping OPMN Services now##########"
$SCRIPTS/adopmnctl.sh  stopall
sleep 20

if ps -ef|grep opmn|grep appsw|grep -v grep|grep -v bounce_opmn; then
_KillOpmnSess
       sleep 5
       ${SCRIPTS}/adopmnctl.sh stopall
       ${SCRIPTS}/adopmnctl.sh startall
       ${SCRIPTS}/adopmnctl.sh stopall
fi

echo "#########Starting OPMN Services##############"
$SCRIPTS/adopmnctl.sh  startall
sleep 20

echo "#########Checking OPMN Services Status#############"
$SCRIPTS/adopmnctl.sh  status