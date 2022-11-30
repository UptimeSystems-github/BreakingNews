#!/bin/sh
set -x

TDATE=$(date "+%Y%m%d")

##Create a functions to check if the VALID_NODE_CHECKING_REGISTRATION already exists

_chk_node_entry_exist_single () {
                       NODE_ENTRY_CHK=/tmp/node_entry_chk.txt
                       grep VALID_NODE_CHECKING_REGISTRATION ${TNS_ADMIN}/listener.ora > ${NODE_ENTRY_CHK}
                       
                       ##filesize=$(cat ${NODE_ENTRY_CHK}|wc -m)
                       if [ -s ${NODE_ENTRY_CHK} ]; then
                       echo "VALID_NODE_CHECKING_REGISTRATION Already exists"
                       else
                       cp ${TNS_ADMIN}/listener.ora ${TNS_ADMIN}/listener.ora.${TDATE}
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER=LOCAL">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_${ORACLE_SID}=LOCAL">>${TNS_ADMIN}/listener.ora
                       fi
}

_chk_node_entry_exist_rac_11g () {
                       NODE_ENTRY_CHK=/tmp/node_entry_chk.txt
                       grep VALID_NODE_CHECKING_REGISTRATION ${TNS_ADMIN}/listener.ora > ${NODE_ENTRY_CHK}
                       
                       ##filesize=$(cat ${NODE_ENTRY_CHK}|wc -m)
                       if [ -s ${NODE_ENTRY_CHK} ]; then
                       echo "VALID_NODE_CHECKING_REGISTRATION Already exists"
                       else
                       cp ${TNS_ADMIN}/listener.ora ${TNS_ADMIN}/listener.ora.${TDATE}
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN1=SUBNET">>${TNS_ADMIN}/listener.ora 
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN2=SUBNET">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN3=SUBNET">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER=SUBNET">>${TNS_ADMIN}/listener.ora
                       fi
}

_chk_node_entry_exist_rac_12c () {
                       NODE_ENTRY_CHK=/tmp/node_entry_chk.txt
                       grep VALID_NODE_CHECKING_REGISTRATION ${TNS_ADMIN}/listener.ora > ${NODE_ENTRY_CHK}
                       
                       ##filesize=$(cat ${NODE_ENTRY_CHK}|wc -m)
                       if [ -s ${NODE_ENTRY_CHK} ]; then
                       echo "VALID_NODE_CHECKING_REGISTRATION Already exists"
                       else
                       cp ${TNS_ADMIN}/listener.ora ${TNS_ADMIN}/listener.ora.${TDATE}
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN1=OFF   ">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN2=OFF   ">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN3=OFF   ">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SUBNET      ">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_LISTENER_SCAN1=SUBNET">>${TNS_ADMIN}/listener.ora
                       echo "VALID_NODE_CHECKING_REGISTRATION_MGMTLSNR=SUBNET      ">>${TNS_ADMIN}/listener.ora
                       fi
}

for LINE in $(cat /etc/oratab|grep -v '#'|grep -v '^$')
do
OH=$(echo $LINE|cut -d: -f2)
DB=$(echo $LINE|cut -d: -f1)
export ORACLE_HOME=${OH}
export ORACLE_SID=${DB}
export PATH=$PATH:$ORACLE_HOME/bin
export TNS_ADMIN=$ORACLE_HOME/network/admin

ISCLUSTERDB=/tmp/ISCLUSTERDB.txt
$ORACLE_HOME/bin/sqlplus -s "/as sysdba"<<EOF
set head off
set trimspool on
set linesize 200
set pagesize 0
set feedback on
set echo off
select value from v\$parameter where name='cluster_database';
spool ${ISCLUSTERDB}
/
spool off
exit;
EOF

DB_VERSION=/tmp/DB_VERSION.txt
$ORACLE_HOME/bin/sqlplus -s "/as sysdba"<<EOF
set head off
set trimspool on
set linesize 200
set pagesize 0
set feedback on
set echo off
select version from v\$instance;
spool ${DB_VERSION}
/
spool off
exit;
EOF

if [ -e ${ISCLUSTERDB} ] && [ "$(grep FALSE ${ISCLUSTERDB})" == "FALSE" ]; then
   _chk_node_entry_exist_single 
   
elif [ -e ${DB_VERSION} ] && [ "$(grep 11.2.0.3 ${DB_VERSION})" == "11.2.0.3.0" ]; then
   _chk_node_entry_exist_rac_11g 
else
   _chk_node_entry_exist_rac_12c
fi
done
