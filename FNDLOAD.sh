#!/bin/sh
Author: Ishmael Seshie
#set -x
echo "
     PROGRAM LCT is afcpprog.lct
     PERSONALIZATION LCT is affrmcus.lct
     REQUEST_GROUP LCT is afcpreqg.lct
     REQUEST_SET LCT is afcprset.lct
     VALUE_SET LCT is afffload.lct
     ALERT LCT is alr.lct
     "
 echo "Please Enter APPS Password"
  read APPSPWD
 echo "Please Enter LCT_NAME only not the path"
  read LCT_NAME
 echo "Please Enter LDT_NAME "
  read LDT_NAME
 echo "Is this ALERT ldt? (Y/N) "
  read WHATLDT 

if [ ${WHATLDT} == "N" ] || [ ${WHATLDT} == "n" ]; then
FNDLOAD apps/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/$LCT_NAME $LDT_NAME CUSTOM_MODE=FORCE
else
##For ALERT Only
FNDLOAD apps/$APPSPWD 0 Y UPLOAD $ALR_TOP/patch/115/import/alr.lct $LDT_NAME CUSTOM_MODE=FORCE
fi
##Test
##Update 2022
##Update 2023
