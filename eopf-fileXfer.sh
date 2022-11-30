#!/bin/sh
## Name: eopf_fileXfer.sh
##
## Description: EOPF File Transfer Script ConnectDirect to/from NBC.
##
## Modifications:
##   07/29/2011 - hersey - Initial Revision.
##   12/14/2011 - hersey - SCR 13813, remove all file xfer delays, summarize
##                         notifications in single email without attachments.
##   01/27/2012 - hersey - SCR 13813, added ability to transfer files in 
##                         smaller groups or transfer sets to prevent overload
##                         of Connect:Direct.
##
. ~/.profile > /dev/null 2>&1

##############################################################################
##
## Copying Files from stario.doe.gov
##
SFTP_CONN=starsftp@starsio.doe.gov
SFTP_EOPF_IN=/chroot/jail/stars/starsftp/strs/int/eopf_fehb/datain

#
## Copy the eOPF(DNDN*.zip) files from sftp server
#
scp -p ${SFTP_CONN}:${SFTP_EOPF_IN}/DNDN*.zip /u00/home/eopfsw/files

#
## Remove the eOPF(DNDN*.zip) files from the ftp server.
#
ssh ${SFTP_CONN} rm ${SFTP_EOPF_IN}/DNDN*.zip


##
## BEGIN MODIFIABLE VARIABLES
##

#EOPF_SNODE=eOPF_CD
EOPF_SNODE=EOPF_CD2

CDFT_HOME=/u00/home/cdft/cdunix/ndm
CDFTP_HOME=/u00/home/CDFtp

#CDFT_EXEC=${CDFT_HOME}/bin/direct
CDFTP_EXEC=${CDFTP_HOME}/cdftp

#export NDMAPICFG=${CDFT_HOME}/cfg/cliapi/ndmapi.cfg

D_EOPF_FTP=/u00/home/eopfsw/files               ## Files from App Server

D_EOPF_HST=${CDFT_HOME}/ehistory                ## History of files
 
D_LOC_SEND=${CDFT_HOME}/eperfout                ## Local send directory

D_LOC_RECV=${CDFT_HOME}/eperfin                 ## Local receive directory

D_CFM_RECV="F:\eOPF\DoeEperformance\Confirmed"  ## Remote confirm directory

D_ERR_RECV="F:\eOPF\DoeEperformance\Errors"     ## Remote error directory

#EOPF_DLIST=eperf.dlist
EOPF_DLIST=ishmael.seshie@hq.doe.gov

##
## END MODIFIABLE VARIABLES
##
##############################################################################

##############################################################################
##
## BEGIN INITIALIZATION
##

umask 002

cd $(dirname $0)

## Exit if this script is already running.
if ps -ef |grep -v grep |grep -v $$ |grep $0; then
    echo "Warning: $0 already executing.  Exiting."
    exit 1
fi

##
## END INITIALIZATION
##
##############################################################################

##############################################################################
##
## BEGIN FUNCTIONS
##

##
## Update file status.
##     Parameters: XFER_SET FILE STATUS.
##
update_status () {
    D_XFER_SET=${1}

    cd ${D_EOPF_FTP}/${D_XFER_SET}

    ## Create a new status file if file does not exist.
    if [[ ! -a xfer_set_status ]]; then
       for FN in $(cat xfer_set_list); do
           echo "${FN} Ready" >> xfer_set_status
       done 
    fi

    ## Check if the status update is for a single or all files.
    if [[ ${2} == "ALL" ]]; then
        ## Edit and replace the status(3) for all files.
        ex -s xfer_set_status<<- EOF
		%s; .*; ${3};
		:x
		EOF
    else
        ## Edit and replace status(3) for file entry(2).
        ex -s xfer_set_status<<- EOF
		/${2}/s; .*; ${3};
		:x
		EOF
    fi

    return 0
}

##
## Update transfer set status summary.
##     Parameters: XFER_SET
##
update_summary () {
    D_XFER_SET=${1}

    cd ${D_EOPF_FTP}/${D_XFER_SET}

    ## Determine the current file counts.
    CNT_FILES=$(cat xfer_set_list| wc -l)
    CNT_PENDT=$(grep "zip Pending_Transfer" xfer_set_status| wc -l)
    CNT_PENDC=$(grep "zip Transferred" xfer_set_status| wc -l)
    CNT_RVCFM=$(grep "zip Confirmed" xfer_set_status| wc -l)
    CNT_RVERR=$(grep "zip Error" xfer_set_status| wc -l)
    
    ## Generate a new summary file.
    echo "File Summary for Transfer Set: ${D_XFER_SET}" > xfer_set_summary
    echo " " >> xfer_set_summary
    echo "Number of Files        : ${CNT_FILES}" >> xfer_set_summary
    echo "Pending Transfer       : ${CNT_PENDT}" >> xfer_set_summary
    echo "Pending Confirmation   : ${CNT_PENDC}" >> xfer_set_summary
    echo "Confirmations Received : ${CNT_RVCFM}" >> xfer_set_summary
    echo "Errors Received        : ${CNT_RVERR}" >> xfer_set_summary
    echo " " >> xfer_set_summary
    echo " " >> xfer_set_summary

    return 0
}

##
## Send an email with the current transfer status and summary.
##
send_status_email () {
    echo "Sending updated status notification."

    ## Create the notification using the summary and file status.
    cd ${D_EOPF_FTP}/${D_XFER_SET}
    cat xfer_set_summary xfer_set_status > status_email

    ## Send the notification.
    SUBJECT="eOPF/ePerformance File Transfer Status"
    mailx -s "${SUBJECT}" ${EOPF_DLIST} < status_email

    return 0
}

##
## Create transfer sets for files to prevent overload of Connect:Direct.
##     Parameters: None
##
create_xfer_set () {
    cd ${D_EOPF_FTP}

    ## Check if any new zip files have been staged for transfer.
    if ls *.zip 2>/dev/null; then
        let XFER_SET_MAX=1000
        let XFER_SET_SEQ=1
        let XFER_SET_CNT=0

        ## Divide the files up into transfer sets.
        for FN in $(ls -1 *.zip); do
            D_XFER_SET=xfer_set_$$.${XFER_SET_SEQ}
            if [[ ! -d ${D_XFER_SET} ]]; then
                mkdir ${D_XFER_SET}
                mkdir -p ${D_XFER_SET}/confirmed
                mkdir -p ${D_XFER_SET}/errors
            fi
   
            ## Add the file to the current transfer set.
            mv ${FN} ${D_XFER_SET}/.
            let XFER_SET_CNT=XFER_SET_CNT+1

            ## Finish setup for the current transfer set.
            if (( XFER_SET_CNT >= XFER_SET_MAX )); then
                cd ${D_XFER_SET}
                ls -1 *.zip > xfer_set_list
                update_status ${D_XFER_SET} ALL Pending_Transfer
                touch status-READY
                let XFER_SET_SEQ=XFER_SET_SEQ+1
                let XFER_SET_CNT=0
                create_cdftp_mget_cmds ${D_XFER_SET}
                create_cdftp_mput_cmds ${D_XFER_SET}
                cd ${D_EOPF_FTP}
            fi
        done

        ## Finish setup for the last odd sized transfer set.
        if (( XFER_SET_CNT != XFER_SET_MAX )); then
            cd ${D_XFER_SET}
            ls -1 *.zip > xfer_set_list
            update_status ${D_XFER_SET} ALL Pending_Transfer
            touch status-READY
            create_cdftp_mget_cmds ${D_XFER_SET}
            create_cdftp_mput_cmds ${D_XFER_SET}
            cd ${D_EOPF_FTP}
        fi 
    fi

    return 0
}

##
## Create get commands for all return confirmations and errors.
##     Parameters: XFER_SET
##
create_cdftp_mget_cmds () {
    D_XFER_SET=${1}

    cd ${D_EOPF_FTP}/${D_XFER_SET}
    echo "prompt" > xfer_set_cfm_mget
    echo "bin" > xfer_set_cfm_mget
    echo "lcd ${D_LOC_RECV}/confirmed/" >> xfer_set_cfm_mget
    echo "cd ${D_CFM_RECV}" >> xfer_set_cfm_mget
    for FN in $(ls -1 *.zip); do
        echo "get ${FN%%.zip}.xml" >> xfer_set_cfm_mget
    done

    echo "prompt" > xfer_set_err_mget
    echo "lcd ${D_LOC_RECV}/errors/" >> xfer_set_err_mget
    echo "cd ${D_ERR_RECV}" >> xfer_set_err_mget
    for FN in $(ls -1 *.zip); do
        echo "get ${FN%%.zip}.xml" >> xfer_set_err_mget
    done
        
    return 0
}

##
## Create get commands for uploading files.
##     Parameters: XFER_SET
##
create_cdftp_mput_cmds () {
    D_XFER_SET=${1}

    cd ${D_EOPF_FTP}/${D_XFER_SET}
    echo "prompt" > xfer_set_cfm_mput
    echo "bin" > xfer_set_cfm_mput
    echo "lcd ${D_LOC_SEND}/${D_XFER_SET}" >> xfer_set_cfm_mput
    echo "cd prestage" >> xfer_set_cfm_mput
    for FN in $(ls -1 *.zip); do
        echo "put ${FN}" >> xfer_set_cfm_mput
    done

    return 0
}

##
## Call connect direct software to send the file.
##     Parameters: XFER_SET
##
eopf_send () {
    D_XFER_SET=${1}

    ## Stage the outbound files for Connect:Direct to transfer.
    mkdir -p ${D_LOC_SEND}/${D_XFER_SET}
    cp ${D_EOPF_FTP}/${D_XFER_SET}/*.zip ${D_LOC_SEND}/${D_XFER_SET}

    ## Call ConnectDirect to send the files.
    echo "Transferring ePerf files via ConnectDirect."
    {
    echo "####################################################################"
    ${CDFTP_EXEC} ${EOPF_SNODE} < ${D_EOPF_FTP}/${D_XFER_SET}/xfer_set_cfm_mput
    echo "####################################################################"
    } > ${D_EOPF_FTP}/${D_XFER_SET}/send.xfer.log
    touch ${D_LOC_SEND}/${D_XFER_SET}/status-SENT

    for FN in $(cat ${D_EOPF_FTP}/${D_XFER_SET}/xfer_set_list); do
        if cat ${D_EOPF_FTP}/${D_XFER_SET}/send.xfer.log|\
            sed -n "
                /$FN/{
                    N
                    /250 Transfer completed successfully/{
                        P
                    }
                }"| grep -q ${FN}; then
             update_status ${D_XFER_SET} $FN Transferred
        else
             update_status ${D_XFER_SET} $FN Error
        fi

    done

    return 0
}

##
## Call connect direct software to receive the confirmation xmls.
##     Parameters: XFER_SET
##
eopf_recv_cfm () {
    D_XFER_SET=${1}

    ## Call ConnectDirect to transfer the files.
    echo "Checking for confirmation files on remote host."
    {
    echo "####################################################################"
    ${CDFTP_EXEC} ${EOPF_SNODE} < ${D_EOPF_FTP}/${D_XFER_SET}/xfer_set_cfm_mget
    echo "####################################################################"
    } > ${D_EOPF_FTP}/${D_XFER_SET}/recv_cfm.xfer.log

    return 0
}

##
## Call Connect:Direct software to receive the error xmls.
##     Parameters: XFER_SET
##
eopf_recv_err () {
    D_XFER_SET=${1}

    ## Call ConnectDirect to transfer the files.
    echo "Checking for error files on remote host."
    {
    echo "####################################################################"
    ${CDFTP_EXEC} ${EOPF_SNODE} < ${D_EOPF_FTP}/${D_XFER_SET}/xfer_set_err_mget
    echo "####################################################################"
    } > ${D_EOPF_FTP}/${D_XFER_SET}/recv_err.xfer.log

    return 0
}

##
## Process the ACTIVE transfer set.
##     Parameters: XFER_SET
##
process_active_set () {
    D_XFER_SET=${1}

    cd ${D_XFER_SET}
    echo "${D_XFER_SET} is ACTIVE."

    ## Backup the status to compare later if a new notification needs sent.
    if [[ -a xfer_set_status ]]; then
        cp xfer_set_status xfer_set_status.old
    else
        touch xfer_set_status.old
    fi

    if [[ -a ${D_LOC_SEND}/${D_XFER_SET}/status-SENT ]]; then
        echo "Verified files have already been sent via Connect:Direct."

        eopf_recv_cfm ${D_XFER_SET}
        eopf_recv_err ${D_XFER_SET}

        for FN in $(cat ${D_EOPF_FTP}/${D_XFER_SET}/xfer_set_list); do
            CFM_FNAME=${D_LOC_RECV}/confirmed/${FN%%.zip}.xml
            if [[ -a ${CFM_FNAME} ]]; then
                echo "Confirmation received for ${FN}."
                mv ${CFM_FNAME} ${D_EOPF_FTP}/${D_XFER_SET}/confirmed/.
                update_status ${D_XFER_SET} ${FN} Confirmed
            fi 

            ERR_FNAME=${D_LOC_RECV}/errors/${FN%%.zip}.xml
            if [[ -a ${ERR_FNAME} ]]; then
                echo "Error received for ${FN}."
                mv ${ERR_FNAME} ${D_EOPF_FTP}/${D_XFER_SET}/errors/.
                update_status ${D_XFER_SET} ${FN} Error
            fi 

        done
    else
        echo "Verified files need to be sent via Connect:Direct."

        eopf_send ${D_XFER_SET}
    fi

    cd ${D_EOPF_FTP}/${D_XFER_SET}
    if ! grep -q "Trans" xfer_set_status; then
       mv status-ACTIVE status-COMPLETE
       touch status-COMPLETE
    fi

    update_summary ${D_XFER_SET}

    ## Check if a new status notification is needed.
    if ! diff xfer_set_status xfer_set_status.old > /dev/null; then
        ## Send updated notification.
        send_status_email ${D_XFER_SET}
    fi

    cd ${D_EOPF_FTP}

    return 0
}

##
## Process the READY transfer set.
##     Parameters: XFER_SET
##
process_ready_set () {
    D_XFER_SET=${1}

    cd ${D_XFER_SET}
    mv status-READY status-ACTIVE
    touch status-ACTIVE

    echo "${D_XFER_SET} is now ACTIVE."

    if [[ ! -a ${D_LOC_SEND}/${D_XFER_SET}/status-SENT ]]; then
        eopf_send ${D_XFER_SET}
    else
        echo "Error: This transfer set has already been sent."
    fi

    update_summary ${D_XFER_SET}

    ## Send an updated notification for the initial processing.
    send_status_email ${D_XFER_SET}

    cd ${D_EOPF_FTP}

    return 0
}

##
## Process the COMPLETED transfer set.
##     Parameters: XFER_SET
##
process_completed_set () {
    D_XFER_SET=${1}

    echo "Completed all transfer set activity, archiving to history."

    ## Cleanup the xfer set staging area and archive it.
    if [[ -d ${D_EOPF_FTP}/${D_XFER_SET} ]]; then
        cd ${D_EOPF_FTP}
        zip -rpm ${D_XFER_SET}.zip ${D_XFER_SET}
        mv ${D_XFER_SET}.zip ${D_EOPF_HST}/.
    fi

    ## Cleanup the xfer set Connect:Direct send area.
    if [[ -d ${D_LOC_SEND}/${D_XFER_SET} ]]; then
        cd ${D_LOC_SEND}
        rm -rf ${D_XFER_SET}
    fi

    cd ${D_EOPF_FTP}

    return 0
}

##
## END FUNCTIONS
##
##############################################################################

##############################################################################
##
## BEGIN MAIN SCRIPT
##

##
## Create groups of files to break up the transfer into smaller transfer sets.
##
create_xfer_set

##
## Check for and process any ACTIVE transfer set.
##
cd ${D_EOPF_FTP}
for D_XFER_SET in $(ls -d1 xfer_set*); do
    if [[ -a ${D_XFER_SET}/status-ACTIVE ]]; then
        echo "Active transfer set found."

        ## Process the ACTIVE set.
        process_active_set ${D_XFER_SET}

        ## Check if all processing is complete for this transfer set.
        if [[ -a ${D_XFER_SET}/status-COMPLETE ]]; then

            ## Process the COMPLETED set.
            process_completed_set ${D_XFER_SET}

        fi

        exit
    fi
done

##
## Check for and perform initial processing for the next READY transfer set.
##
cd ${D_EOPF_FTP}
for D_XFER_SET in $(ls -d1 xfer_set*); do
    if [[ -a ${D_XFER_SET}/status-READY ]]; then
        echo "Ready transfer set found."

        ## Perform initial processing on the READY transfer set.
        process_ready_set ${D_XFER_SET}

        exit
    fi
done

##
## END MAIN SCRIPT
##
##############################################################################
