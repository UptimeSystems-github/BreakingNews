#!/bin/sh
# $Header$
#
# checkTempSpaceEaters.sh
#
#   Check if temporary tablespace space usage is over 60G,if it is over 60G 
#   then look for the most likely culprit, which is BI reports from iepbiee1
#   and iepbiee2 servers from IDW and kill these sessions if they have been 
#   running for over 1 hour
#
# Modifications:
#   02/20/2015 - SeshieI - Initial version.
#   08/24/2016 - SeshieI - Added the condition to run clearTempSpaceEaters.sh
#                         if only temp tablespace usage is over 60G.
#


. $HOME/.profile > /dev/null 2>&1

set -x
##Check for  modules with names  like 'nqsserver%iepbiee%'
##
_checkTempSpaceEaters () {
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
}

#
## SQL to determine the temp tablespace used
#
TMPLOGFILE=/u00/home/orasw/util/usedTempSpace.txt

sqlplus -s "/as sysdba"<<-EOF
set heading off
set feedb off
set lines 200
col "UsedSpace GB" format 999.999
select 
'TempspaceUsed='||(used_blocks*8)/1024/1024 
from gv\$sort_segment ss,gv\$instance i where ss.tablespace_name in (select tablespace_name from dba_tablespaces where contents='TEMPORARY') and
i.inst_id=ss.inst_id

spool ${TMPLOGFILE}
/
spool off
EOF


TEMPSPACEUSED=$(grep -i Tempspaceused ${TMPLOGFILE}| cut -d= -f2)
echo ${TEMPSPACEUSED}

#
## Run clearTempSpaceEaters.sh script if only temp tablespace used is over 60G 
#
if [[ ${TEMPSPACEUSED} -gt 60 ]] then
    echo "Running script to clear out BI sessions consuming large temp space"
    _checkTempSpaceEaters
#   /u00/home/orasw/util/clearTempSpaceEaters.sh
fi 
   


