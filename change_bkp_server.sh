#!/bin/bash
#Author : Kens Babu [C5241465]
#Team : GCS BACKUP EXPERT TEAM
#Script to change backup server details in DB configuration
#Usage <syntax> : sh <file_name>.sh -s <new backup server>
#Supported DBs : SAPDB, SAPHANA, DB2, SYBASE
#Change history
#========================
#02-Jan-2023 |Kens (C5241465)|v1.0: 
#             - Make a copy the SapAgent.conf file with date of migration
#             - Change the backup server name in SapAgent.conf. In the next run, backup agents will change the server name in remaining config files
#				  - Added a switch variable to pass the backup server name 				         
#

dateTime=`date +%Y%m%d%H%M`
while getopts "s:h" options
do
case "$options" in
      s)srv="$OPTARG"
      ;;
      h)echo >&2 "usage: sh $0 -s <new_server_name>"
      ;;
      [?])echo -e "missing parameter.. please follow below usage\nusage: sh $progName.sh -s <new_server_name>"
      exit 1
      ;;
esac
done
#SAPDB System
if [ "$(df -h|grep -i "/sapdb " >/dev/null; echo $?)" -eq "0" ]; then 
    echo "SAPDB system"
    file=`ls /var/spool/cron/tabs/ | grep -i sqd | grep -v '.bak'`
    agentpath=`cat /var/spool/cron/tabs/$file | grep "backup_agent" | sed 's/[^/]*\(\/[^> ]*\).*/\1/g' | sed 's/\(.*\)\/.*/\1/g'`
    echo "Agentpath: $agentpath"
    cd $agentpath
    echo -e "Before Change\n----------------"
    cat ./SapAgent.conf|egrep "BackupServer|ArchiveServer"
    cp ./SapAgent.conf SapAgent_migrated_to_${srv}_${dateTime}
    echo -e "After change\n----------------------------------"
    sed -i '/BackupServer/d' ./SapAgent.conf 
    sed -i '10 a\BackupServer="${srv}"' ./SapAgent.conf
    sed -i '/ArchiveServer/d' ./SapAgent.conf 
    sed -i '11 a\ArchiveServer="${srv}"' ./SapAgent.conf
    cat ./SapAgent.conf|egrep "BackupServer|ArchiveServer"
    sed -i '/NSR_HOST/d' ./env
    sed -i '4 a\NSR_HOST  "${srv}"' ./env
    echo -e "Changed server in env file\n--------"
    cat ./env |grep  "NSR_HOST" 
#SAPHANA system
   elif [ "$(df -h|egrep -i "\/hana|\/hdb" >/dev/null; echo $?)" -eq "0" ]; then 
    saps=/usr/sap/sapservices
        if [[ -r $saps ]]; then 
            sidinfo=$( awk '/^LD_LIBRARY_PATH=.*HDB[0-9][0-9]/{ for(i=1;i<=NF;i++) { if ( $i ~ /pf=/) {n=split($i,a,"/");print a[n]}}}' $saps )
            echo "SAPHANA system | $sidinfo"
            sid=$( echo $sidinfo | awk -F"_" '{print $1}')
            insnr=$( echo $sidinfo | awk -F"_" '{print $2}' | sed 's!HDB!!g' )
            lsid=`echo ${sid}|tr '[:upper:]' '[:lower:]'`
                if [[ -d /usr/sap/$sid/home ]]; then 
                  echo -e " ----> Path /usr/sap/$sid/home/ exist\n" 
                  cd /usr/sap/$sid/home/sapscripts/monitor2 
                  echo -e "Before configuration change\n-------------------"
                  cp ./SapAgent.conf SapAgent_migrated_to_${srv}_${dateTime}
                  cat SapAgent.conf|grep -i server
                  sed -i '/ArchiveServer=/d' SapAgent.conf 
                  sed -i '2 a\ArchiveServer="${srv}"' SapAgent.conf
                  sed -i '/BackupServer=/d' SapAgent.conf
                  sed -i '2 a\BackupServer="${srv}"' SapAgent.conf
                  echo -e "After configuration change\n-------------------"
                  cat /usr/sap/$sid/home/sapscripts/monitor2/SapAgent.conf|egrep -i 'BackupServer|ArchiveServer'
                     if [[ -d /usr/sap/$sid/SYS/global/hdb/opt ]]; then 
                        echo -e " ----> Path /usr/sap/$sid/SYS/global/hdb/opt exist..\n"
                        cd /usr/sap/$sid/SYS/global/hdb/opt/
                        sed -i '/server/d' init${sid}.utl
                        sed -i '1 a\server='${srv}'' init${sid}.utl
                        cat /usr/sap/$sid/SYS/global/hdb/opt/init${sid}.utl
                      else echo -e "Cannot determine global path, Edit the init file manually"
                     fi
                else echo -e "Cannot determine home path, do configuration change manually"
                fi
        fi          
#Sybase system
   elif [ $(ls /var/spool/cron/tabs/ | egrep -i "syb|sqd"  | grep -v '.bak'>/dev/null;echo $?) == 0 ]; then
      echo "SYBASE system"
      file=`ls /var/spool/cron/tabs/ | egrep -i "syb|sqd"  | grep -v '.bak'`
      agentpath=`cat /var/spool/cron/tabs/$file | grep "backup_agent" | sed 's/[^/]*\(\/[^> ]*\).*/\1/g' | sed 's/\(.*\)\/.*/\1/g'`
      printf "Agentpath: $agentpath"
      cd $agentpath
      cp ./SapAgent.conf SapAgent_migrated_to_${srv}_${dateTime}
      echo -e "\nChanging Backup server in SapAgent\n-------------------"
      sed -i '/ArchiveServer=/d' SapAgent.conf 
      sed -i '2 a\ArchiveServer="${srv}"' SapAgent.conf
      sed -i '/BackupServer=/d' SapAgent.conf 
      sed -i '3 a\BackupServer="${srv}"' SapAgent.conf
      cat ./SapAgent.conf|grep -i server
      echo -e "\nChanging Backup server in NMDA file\n-------------------"
      sed -i '/NSR_SERVER/d' ./nmda_sybase*.cfg
      sed -i '1 a\NSR_SERVER=${srv}' ./nmda_sybase*.cfg
      cat ./nmda_sybase*.cfg |grep SERVER
#DB2 system
   elif [ "$(df -h|grep -i "/db2" >/dev/null; echo $?)" -eq "0" ]; then 
      echo "DB2 system"
      file=`ls /var/spool/cron/tabs/ | grep -i db2 | grep -v '.bak'`
      agentpath=`cat /var/spool/cron/tabs/$file | grep "backup_agent"|head -1 | sed 's/[^/]*\(\/[^> ]*\).*/\1/g' | sed 's/\(.*\)\/.*/\1/g'`
      echo "Agentpath: $agentpath"
      cd $agentpath
      echo -e "Before Change\n----------------"
      cat ./SapAgent.conf|egrep "BackupServer|ArchiveServer"
      cp ./SapAgent.conf SapAgent_migrated_to_${srv}_${dateTime}
      echo -e "After change\n----------------------------------"
      sed -i '/BackupServer/d' ./SapAgent.conf 
      sed -i '10 a\BackupServer="${srv}"' ./SapAgent.conf
      sed -i '/ArchiveServer/d' ./SapAgent.conf 
      sed -i '11 a\ArchiveServer="${srv}"' ./SapAgent.conf
      cat ./SapAgent.conf|egrep "BackupServer|ArchiveServer"
   else echo "DB type must be MSSQL or Oracle.. Please change the configuration manually"
fi
