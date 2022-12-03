#!/bin/ksh
Author:Ishmael.seshie
. $HOME/.profile > /dev/null 2>&1
set -x
LOGFILE=/u00/home/orasw/util/clearTempSpaceEaters.sql

sqlplus -s "/as sysdba"<<-EOF
set heading off
set feedb off
SELECT 'ALTER SYSTEM KILL SESSION '||''''||sid||','||serial#||''''||' immediate;'
from v\$session 
where module like 'nqsserver%iepbiee%'
and (last_call_et/3600)>=1

spool ${LOGFILE}
/
spool off
@${LOGFILE}
EOF
