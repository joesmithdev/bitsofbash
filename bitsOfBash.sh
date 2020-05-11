#!/bin/bash
#------------------------------------------------------------------------------------------
#   Last update: May_10_2020_0303       
#   Description -   This script aims to provide the user with a modular structure for 
#                   creating interactive bash scripts. Instead of having several scripts, 
#                   simply create a function using the "bonesMalone" function as your guide. 
#                   Once the function is complete, add an entry to the menu or submenu of 
#                   your choice so that the option can be presented to the user. 
#                   This script has samples of making menus using whiptail and dialog.
#------------------------------------------------------------------------------------------
#   "Everything is code." - A. Russo
#   "Who looks outside dreams; who looks inside awakes." - Dr. Carl Jung
#   "Today will be better." - K. Miletic
#   "A ship in harbor is safe, but that is not what ships are built for." - John A. Shedd
#------------------------------------------------------------------------------------------


#==========================================================================================
# MAIN AND SUPPORT FUNCTIONS -START-
#==========================================================================================

#------------------------------ < Script Switches > --------------------------------
#   Switch    |   Description
#------------------------------------------------------------------------------------------
#   -d      |   Debug Mode. Used for progressing through the main and sub menus 
#           |   without performing the core actions of the selected function.
#------------------------------------------------------------------------------------------
#   -br     |   Bypass root/sudo requirement for running the script. 
#           |   Useful for functions that do not require elevated previliges.
#------------------------------------------------------------------------------------------
#   -e      |   Sets the working environment. Useful when determining options 
#           |   such as network adapter name or package manager.    
#------------------------------------------------------------------------------------------
#   -u      |   Sets the working user. When needed, file ownership is set to this user.
#------------------------------------------------------------------------------------------

#------------------------------ < Global Variables >-----------------------------
workingENV=""
workingUSER=""
debugSwitch=0
bypassRootSWITCH=0

termHeight=$(tput lines)
termWidth=$(tput cols)
linesToShow=10 

dataArray=()
menuActionLoopCTL=0
funcMenuLoopCTL=0
funcActionLoopCTL=0
outputLOG=log_bitsOfBash.txt
tempFileDir="/tmp/bitsOfBash"
#------------------------------------------------------------------------------------------

__main(){
    timeStamp -s __main
    mkdir -p $tempFileDir
            
    #Check if the script is being run as a privileged user or the bypass is being used.
    if [ "$bypassRootSWITCH" != "1" ];then
        if [[ $EUID -ne 0 ]]; then
            clear; echo "This script must be run by privileged user."; exit 1
        fi
    fi

    #Check if the pkg dialog is installed. This is currently the only dependency.
    isReady=$(which dialog)
    if [ ${#isReady} = 0 ];then
        echo "+++ Installing dependencies +++"; sleep 1; 
        apt update; apt install dialog -y |& tee -a /home/$workingUSER/.$outputLOG
        echo "+++ Ready +++"; sleep 3
    fi

    #Check if a working environment has been set.
    if [ ${#workingENV} = 0 ];then
        setEnvironment
    fi
    
    #Check if a user has been set
    if [ ${#workingUSER} = 0 ];then
        setUser
    fi

    #Infinite loop for the main menu.
    while true;
    do
        menuAction=$(whiptail --title "Main Menu" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "Desktop" "Desktop config options" OFF \
        "Server" "Server config options" OFF \
        "NVPN" "Install NordVPN" OFF \
        "SSH" "Configure SSH Server on VM or desktop." OFF 3>&1 1>&2 2>&3)
        menuActionExitStatus=$?

        if [ ${#menuAction} = 0 ] || [ $menuActionExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction close
        else
            echo "User selected: $menuAction" |& tee -a /home/$workingUSER/.$outputLOG
            menuActionLoopCTL=0
            while [ $menuActionLoopCTL -eq 0 ]
            do
                case $menuAction in
                    Desktop) desktopMenu ;;
                    Server) serverMenu ;;
                    NVPN) installNordVPN ;;
                    SSH) installSSHSERVER ;;
                esac
            done
        fi
    done    
}

function debugMethod(){
#------------------------------------------------------------------------------------------
#   Description -   Creates a pause in execution to check the output of pervious commands.     
#------------------------------------------------------------------------------------------
    timeStamp -s debugMethod
    echo "-- DEBUG MODE --" |& tee -a /home/$workingUSER/.$outputLOG
    echo "-- PRESS ENTER TO CONTINUE --" |& tee -a /home/$workingUSER/.$outputLOG
    read debugPause
    timeStamp -e debugMethod
}

function checkSwitches(){
#------------------------------------------------------------------------------------------
#   Description -   Checks the values passed into the script by the user.
#                   This will check for a valid flag then process the value that 
#                   follows the flag or set the value for a global variable.
#
#   Issues/ToDo      -   No support yet for validating the input.
#------------------------------------------------------------------------------------------
    for (( i=1; i<=$#; i++)){
        eval switchVal='$'$i
        case $switchVal in
            -e) eval workingENV='$'$(( i + 1 )) ;; 
            -u) eval workingUSER='$'$(( i + 1 )) ;; 
            -d) debugSwitch=1 ;;
            -br) bypassRootSWITCH=1 ;;
        esac
    }
}

function setEnvironment(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the global variable for the working environment of the script.
#                   This is useful for creating functions that may need changes depending
#                   on the working environment. Eg. Switching to yum or apt.
#------------------------------------------------------------------------------------------
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        workingENV=$(whiptail --title "Script Environment" --radiolist \
        "Please select an environment:" $termHeight $termWidth $linesToShow \
        "PRX" "Proxmox Virtual Machine" OFF \
        "XCP-HV" "XCP-NG Hypervisor" OFF \
        "XCP-VM" "XCP-NG Virtual Machine" OFF \
        "VBox" "VirtualBox VM" OFF \
        "AWS" "AWS node." OFF \
        "LINODE" "LINODE node." OFF \
        "DSK-LAB" "Debian/Ubuntu VM or Desktop Env." OFF 3>&1 1>&2 2>&3)
        envExitStatus=$?

        echo "User selected: $workingENV" |& tee -a /home/$workingUSER/.$outputLOG
        if [ ${#workingENV} = 0 ] || [ $envExitStatus != 0 ]; then 
            whiptail --title "Error" --msgbox "An environment must be selected." 8 40
            exitFunction close
        else
            funcMenuLoopCTL=1
            echo "workingENV: $workingENV" |& tee -a /home/$workingUSER/.$outputLOG   
        fi
    done
}

function setUser(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the working user for the script. Can be used to 
#                   set a user quickly based on the environment or have the user
#                   select a username that currently has a home directory.
#                   Eg. For AWS the user is hardcoded as "ubuntu"
#------------------------------------------------------------------------------------------
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        case $workingENV in
            AWS) workingUSER="ubuntu"; funcMenuLoopCTL=1 ;;
            *)
                srchResultsToArray -u    
                menuMSG="Please select a user:"
                workingUSER=$(whiptail --title "User Select" --menu "$menuMSG" $termHeight $termWidth $linesToShow "${dataArray[@]}" 3>&1 1>&2 2>&3)
                workingUSERExitStatus=$?
                echo "workingUSER: $workingUSER" |& tee -a /home/$workingUSER/.$outputLOG      
                if [ ${#workingUSER} = 0 ] || [ $workingUSERExitStatus != 0 ]; then 
                    whiptail --title "Error" --msgbox "A user must be selected." 8 40
                    exitFunction close
                else
                    funcMenuLoopCTL=1; echo "workingUSER: $workingUSER" |& tee -a /home/$workingUSER/.$outputLOG
                fi
            ;;
        esac 
    done
}

function srchResultsToArray(){
#------------------------------------------------------------------------------------------
#   Description -   Performs a search based on the flag or values passed in.
#                   The results will be added to a temp txt file then entered into the
#                   global data array used for presenting the results as a list to the user.
#
#   Issues/ToDo -   No support yet for prompting the user when no files/results are found.
#                   Whiptail menu will break.
#------------------------------------------------------------------------------------------
    case $1 in
        -f)
            echo "Searching in: $2" |& tee -a /home/$workingUSER/.$outputLOG
            find $2 -type f -iname "*.$3" >> $tempFileDir/tempDATA.txt
        ;;
        -d)
            echo "Searching in: $2" |& tee -a /home/$workingUSER/.$outputLOG
            find $2 -type d -iname \*$3\* >> $tempFileDir/tempDATA.txt
        ;;
        -s)
            echo "Searching in: $2" |& tee -a /home/$workingUSER/.$outputLOG
            find $2 -iname \*$3\*.$4 >> $tempFileDir/tempDATA.txt
        ;;
        -u)
            echo "$(ls /home/)" >> $tempFileDir/tempDATA.txt
        ;;
        -m)
            find /home/ -type f -name "*.iso" >> $tempFileDir/tempDATA.txt
            find /media/$workingUSER -type f -name "*.iso" >> $tempFileDir/tempDATA.txt
            find /home/ -type f -name "*.img" >> $tempFileDir/tempDATA.txt
            find /media/$workingUSER -type f -name "*.img" >> $tempFileDir/tempDATA.txt
        ;;
    esac
    
    dataArray=()
    while IFS= read line
    do
        dataArray+=("$line")
        dataArray+=("")
    done < $tempFileDir/tempDATA.txt
    rm $tempFileDir/tempDATA.txt
}

function exitFunction(){
#------------------------------------------------------------------------------------------
#   Description -   Manages exiting from functions, menus and the script itself.
#------------------------------------------------------------------------------------------
    case $1 in
        chkMain)
            if (whiptail --title "Warning" --yesno "No option selected or invalid input. Try again?" 8 78); then
                echo "User selected Yes" #Try again. Other actions could be added here.
            else
                echo "User selected No"; funcMenuLoopCTL=1; menuActionLoopCTL=1 #Return to the main menu
            fi
        ;;
        toMain)
            echo "-- Press Enter to continue --"
            read userWait; funcMenuLoopCTL=1; menuActionLoopCTL=1
            whiptail --title "Info" --msgbox "Returing to main menu" 8 40
        ;;
        close)
            if (whiptail --title "Warning!!!" --yesno "Exit the script?" 8 40); then
                clear; echo "*** Arrivederci! ***"; exit 1
            fi
        ;;
        dbg) funcMenuLoopCTL=1; whiptail --title "-- DEBUG --" --msgbox "DEBUG!!! Returing to main menu" 8 40 ;;
    esac
}

function timeStamp(){
#------------------------------------------------------------------------------------------
#   Description -   Adds date and time info to the logs about when a function
#                   started and ended. Useful for checking previous activities.
#------------------------------------------------------------------------------------------
    case $1 in
        -s) scriptState="START" ;;
        -e) scriptState="END" ;;
    esac

    echo " " |& tee -a /home/$workingUSER/.$outputLOG
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" |& tee -a /home/$workingUSER/.$outputLOG
    echo "+++ $2 $scriptState: $(date) +++" |& tee -a /home/$workingUSER/.$outputLOG
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" |& tee -a /home/$workingUSER/.$outputLOG
    echo " " |& tee -a /home/$workingUSER/.$outputLOG
}

function bonesMalone(){
#------------------------------------------------------------------------------------------
#   Description -   The basic format for the functions used in this script.
#
#   Step 1 - Apply starting timestamp
#   Step 2 - Check for debug. Will exit to the main menu if the debug value is set.
#   Step 3 - Main body/loop for the function. If the loop is used, it will continue 
#            until the user selects a valid menu option or choses to exit by selecting cancel.
#   Step 4 - Check if the function call is a part of a chain of function calls.
#            (Multiple calls. eg. installNordVPN chFctnCall -> updatesAndPkgs)
#            This means that the function will not exit to the main menu if another
#            function is being called after completing the current one. 
#            Apply the ending timestamp if the function call is not being chained.
#------------------------------------------------------------------------------------------
    #Step 1
    timeStamp -s bonesMalone

    #Step 2
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi    

    #Step 3
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "Skeleton Function" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "OP1" "Skeleton Option #1" OFF \
        "OP2" "Skeleton Option #2" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            case $menuOption in
                OP1)
                    funcActionLoopCTL=0
                    while [ $funcActionLoopCTL -eq 0 ]
                    do
                        funcActionLoopCTL=1; funcMenuLoopCTL=1; echo "menuOption: $menuOption"; read debugPause
                    done
                ;;
                OP2)
                    funcMenuLoopCTL=1; echo "menuOption: $menuOption"; read debugPause
                ;;
            esac
        fi
    done

    #Step 4
    if [ "$1" != "chFctnCall" ];then
        timeStamp -e bonesMalone; exitFunction toMain
    fi
}

#==============================================================================================================================================================
# MAIN AND SUPPORT FUNCTIONS -END-
#==============================================================================================================================================================
#-
#--
#---
#----
#-----
#------
#-------
#--------
#---------
#----------
#---------
#--------
#-------
#------
#-----
#----
#---
#--
#-
#==============================================================================================================================================================
# DESKTOP MENU -START- 
#==============================================================================================================================================================

function desktopMenu(){
#------------------------------------------------------------------------------------------
#   Description -   The menu used for the functions related to Desktop or Lab VM's.
#------------------------------------------------------------------------------------------
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "Desktop/Lab VM Menu" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "ENV-LAUNCH" "Install NordVPN & PKGS" OFF \
        "PKGS" "System update and package install" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            funcMenuLoopCTL=1
            case $menuOption in
                ENV-LAUNCH)
                    installNordVPN chFctnCall; updatesAndPkgs;
                ;;
                PKGS) updatesAndPkgs ;;
            esac
        fi
    done    
}

function updatesAndPkgs(){
#------------------------------------------------------------------------------------------
#   Description -   Performs system update, installs the specified packages and
#                   creates a basic script for quick manual updating and clean up.
#
#   Issues/ToDo -   Logging snap package installs with the current logging method does not work.
#------------------------------------------------------------------------------------------
    timeStamp -s updatesAndPkgs
    
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi

    if (whiptail --title "SNAP Packages" --yesno "Install SNAP packages?" $termHeight $termWidth); then
        snap install spotify; snap install vlc; snap install electron-mail; snap install signal-desktop
    fi

    #add-apt-repository ppa:peek-developers/stable
    apt update && apt upgrade -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install wireshark -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install net-tools -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install exfat-fuse exfat-utils -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install screenfetch -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install git -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install filezilla -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install dnsutils -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install htop -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install zenmap -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install gparted -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install mysql-client-core-5.7 -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install cmatrix -y |& tee -a /home/$workingUSER/.$outputLOG
    apt install tmux -y |& tee -a /home/$workingUSER/.$outputLOG 
    apt install mongodb-clients -y |& tee -a /home/$workingUSER/.$outputLOG
    #apt install peek -y |& tee -a /home/$workingUSER/.$outputLOG
        
    cat > /root/update.sh << EOFUPSH
#!/bin/bash
apt update;apt upgrade -y; apt autoremove -y; apt clean;
EOFUPSH

    if [ "$1" != "chFctnCall" ];then
        timeStamp -e updatesAndPkgs; exitFunction toMain
    fi
}

#==============================================================================================================================================================
# DESKTOP MENU -END-
#==============================================================================================================================================================
#-
#--
#---
#----
#-----
#------
#-------
#--------
#---------
#----------
#---------
#--------
#-------
#------
#-----
#----
#---
#--
#-
#==============================================================================================================================================================
# SERVER MENU -START- 
#==============================================================================================================================================================

function serverMenu(){
#------------------------------------------------------------------------------------------
#   Description -   The menu used for the functions related to Server VM's.
#------------------------------------------------------------------------------------------
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "Server Menu" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "DB" "Install MariaDB, MySQL or Mongo DB." OFF \
        "SMB" "Install SAMBA file server." OFF \
        "SPLUNK" "Install Splunk Server or Forwarder" OFF \
        "JITSI" "Jitsi meet options." OFF \
        "SET-IP" "VM IP config" OFF \
        "REG-IP" "Assign registered IP" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            funcMenuLoopCTL=1
            case $menuOption in
                DB) installDatabase ;;
                SMB) installSMB ;;
                SPLUNK) installSPLUNK ;;
                JITSI) installJitsi ;;
                SET-IP) setVMIP ;;
                REG-IP) assignRegIP ;;
            esac
        fi        
    done
}

function installDatabase(){
#------------------------------------------------------------------------------------------
#   Description -   Install the selected database on the specified port number.
#------------------------------------------------------------------------------------------
    timeStamp -s installDatabase
    
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi 
    
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "Database Menu" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "MongoDB" "Basic install" OFF \
        "MariaDB" "With utf8 charset" OFF \
        "MySQL"  "With utf8 charset" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            funcActionLoopCTL=0
            while [ $funcActionLoopCTL -eq 0 ]
            do
                menuMSG="DB Type selected: $menuOption\nDB port Examples: 27000 for MongoDB, 65101 for MariaDB & MySQL."
                portNumber=$(whiptail --inputbox "$menuMSG" 8 78 --title "Enter DB Port Number" 3>&1 1>&2 2>&3)
                portNumberExitStatus=$?

                echo "portNumber: $portNumber" |& tee -a /home/$workingUSER/.$outputLOG
                
                if [ ${#portNumber} = 0 ] || [ $portNumberExitStatus != 0 ]; then
                    if (whiptail --title "Warning" --yesno "Port number was too short or selected cancel. Try again?" 8 78); then
                        echo "User selected Yes, exit status was $?."
                    else
                        echo "User selected No, exit status was $?."; funcActionLoopCTL=1
                    fi
                else
                    if (whiptail --title "WARNING!!!: Is this correct?" --yesno "DB Type: $menuOption\nPort: $portNumber" $termHeight $termWidth); then
                        funcActionLoopCTL=1; funcMenuLoopCTL=1

                        case $menuOption in
                            MariaDB) installMARIADB $portNumber ;;
                            MongoDB) installMongoDB $portNumber ;;
                            *) installMYSQL $portNumber ;;    
                        esac

                        ufw allow $portNumber; ufw enable; ufw status verbose |& tee -a /home/$workingUSER/.$outputLOG
                        echo "------------------------------------------------"
                        echo "Test the connection:"
                        echo "mysql -u username -h 192.168.X.XXX -P $portNumber "
                        echo "mongo localhost:$portNumber"
                        echo "------------------------------------------------"
                        echo ""
                        echo "$menuOption action complete."
                    else
                        funcActionLoopCTL=1
                    fi                                                  
                fi 
            done
        fi
    done

    if [ "$1" != "chFctnCall" ];then
        timeStamp -e installDatabase; exitFunction toMain
    fi
}

function installMARIADB(){
#------------------------------------------------------------------------------------------
#   Description -   installDatabase support function installing MariaDB
#------------------------------------------------------------------------------------------
    apt install mariadb-server -y|& tee -a /home/$workingUSER/.$outputLOG
    systemctl stop mysql
    cp -ip /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf_BCKUP$(date "+%F-%T")
    cat > /etc/mysql/mariadb.conf.d/50-server.cnf  <<EOFDBMARIADB
[server]

# this is only for the mysqld standalone daemon
[mysqld]

user		= mysql
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
port		= $1
basedir		= /usr
datadir		= /var/lib/mysql
tmpdir		= /tmp
lc-messages-dir	= /usr/share/mysql
skip-external-locking
#bind-address		= 127.0.0.1
key_buffer_size		= 16M
max_allowed_packet	= 16M
thread_stack		= 192K
thread_cache_size       = 8
myisam_recover_options  = BACKUP
query_cache_limit	= 1M
query_cache_size        = 16M
log_error = /var/log/mysql/error.log
expire_logs_days	= 10
max_binlog_size   = 100M
character-set-server  = utf8mb4
[embedded]

[mariadb]

[mariadb-10.1]
EOFDBMARIADB
    systemctl start mysql; systemctl restart mysql
}

function installMYSQL(){
#------------------------------------------------------------------------------------------
#   Description -   installDatabase support function installing MySQL
#------------------------------------------------------------------------------------------
    apt install mysql-server -y |& tee -a /home/$workingUSER/.$outputLOG
    systemctl stop mysql
    cp -ip /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf_BCKUP$(date "+%F-%T")
    cat > /etc/mysql/mysql.conf.d/mysqld.cnf <<EOFDBMYSQL
[mysqld_safe]
socket		= /var/run/mysqld/mysqld.sock
nice		= 0

[mysqld]
user		= mysql
local-infile=0
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
port		= $1
basedir		= /usr
datadir		= /var/lib/mysql
tmpdir		= /tmp
lc-messages-dir	= /usr/share/mysql
skip-external-locking
#bind-address		= $newAddress
key_buffer_size		= 16M
max_allowed_packet	= 16M
thread_stack		= 192K
thread_cache_size       = 8
myisam-recover-options  = BACKUP
query_cache_limit	= 1M
query_cache_size        = 16M
log_error = /var/log/mysql/error.log
expire_logs_days	= 10
EOFDBMYSQL

    ufw allow $1; ufw enable; ufw status verbose
    systemctl start mysql; mysql_secure_installation; mysql_ssl_rsa_setup --uid=mysql; systemctl restart mysql;
}

function installMongoDB(){
#------------------------------------------------------------------------------------------
#   Description -   installDatabase support function installing MongoDB
#------------------------------------------------------------------------------------------
    apt install mongodb -y |& tee -a /home/$workingUSER/.$outputLOG
    cp /etc/mongodb.conf /etc/mongodb.conf_BCKUP$(date "+%F-%T")
    cat > /etc/mongodb.conf <<EOFDB
# mongodb.conf
# Where to store the data.
dbpath=/var/lib/mongodb
#where to log
logpath=/var/log/mongodb/mongodb.log
logappend=true
bind_ip = 0.0.0.0
port = $1
# Enable journaling, http://www.mongodb.org/display/DOCS/Journaling
journal=true
EOFDB
    systemctl restart mongodb
}

function installSMB(){
#------------------------------------------------------------------------------------------
#   Description -   Install and secure a SAMBA file server.
#------------------------------------------------------------------------------------------
    timeStamp -s installSMB
    
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi
    
    apt install libcups2 samba samba-common cups -y |& tee -a /home/$workingUSER/.$outputLOG
    mv /etc/samba/smb.conf /etc/samba/smb.conf_bak$(date "+%F-%T")
    mkdir -p /home/shared
    chown -R root:users /home/shared
    chmod -R 770 /home/shared
    cat > /etc/samba/smb.conf <<EOFSAMBA
[global]
workgroup = WORKGROUP
server string = Samba Server %v
netbios name = NETWRKSTRG
security = user
map to guest = bad user
dns proxy = no

[shared]
comment = LOCAL_SMB_SHARE
path = /home/shared
valid users = @users
force group = users
create mask = 0660
directory mask = 0771
writable = yes
EOFSAMBA
    
    systemctl restart smbd.service
    echo "Creating user smbuser."
    useradd -m -p $(openssl passwd -1 uhytg7hh96gbh7fbzsa#@1DEer4) smbuser
    usermod -a -G users smbuser
    echo "Please set SMB password for smbuser."
    smbpasswd -a smbuser
    systemctl restart smbd.service
    ufw allow samba; ufw enable |& tee -a /home/$workingUSER/.$outputLOG

    if [ "$1" != "chFctnCall" ];then
        timeStamp -e installSMB; exitFunction toMain
    fi
}

function installSPLUNK(){
#------------------------------------------------------------------------------------------
#   Description -   Install a SPLUNK Server or Forwarder. 
#------------------------------------------------------------------------------------------
    timeStamp -s installSPLUNK
    
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi

    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "Splunk Options" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "SRVR" "SPLUNK Server" OFF \
        "FWRDR" "SPLUNK Forwarder" OFF \
        "UPDATE" "Update SPLUNK Forwarder Index" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            case $menuOption in
                SRVR)
                    funcActionLoopCTL=0
                    while [ $funcActionLoopCTL -eq 0 ]
                    do
                        srchResultsToArray -s /home/ splunk deb
                        
                        menuMSG="Please select the Splunk Server .deb file from the following:"
                        fileSelected=$(whiptail --title "Splunk Server Setup" --menu "$menuMSG" $termHeight $termWidth $linesToShow "${dataArray[@]}" 3>&1 1>&2 2>&3)
                        fileSelectedExitStatus=$?
                        echo "fileSelected: $fileSelected" |& tee -a /home/$workingUSER/.$outputLOG

                        if [ $fileSelectedExitStatus = 0 ]; then
                            if (whiptail --title "WARNING!!!: Is this correct?" --yesno "File:$fileSelected\n" $termHeight $termWidth); then
                                funcMenuLoopCTL=1; funcActionLoopCTL=1
                                dpkg -i $fileSelected |& tee -a /home/$workingUSER/.$outputLOG
                                ufw allow 8000; ufw allow 9997; ufw status verbose |& tee -a /home/$workingUSER/.$outputLOG
                                /opt/splunk/bin/splunk start --accept-license --answer-yes |& tee -a /home/$workingUSER/.$outputLOG
                                /opt/splunk/bin/splunk enable boot-start |& tee -a /home/$workingUSER/.$outputLOG

                                echo "-------------------------"
                                hostname -I |& tee -a /home/$workingUSER/.$outputLOG
                                echo "-------------------------"
                            fi
                        else
                            funcActionLoopCTL=1   
                        fi              
                    done
                ;;
                FWRDR)
                    whiptail --title "Info" --msgbox "Make sure the log index has already been created on the splunk server and linked to the admin account." $termHeight $termWidth
                    funcActionLoopCTL=0
                    while [ $funcActionLoopCTL -eq 0 ]
                    do       
                        srvrAddress=$(whiptail --inputbox "Please enter a valid address with the port. eg 99.99.99.99:9997" 8 78 --title "Forwarder Address" 3>&1 1>&2 2>&3)
                        srvrAddressExitStatus=$?

                        if [ $srvrAddressExitStatus = 0 ]; then
                            indexName=$(whiptail --inputbox "Please enter a the Splunk index name." 8 78 --title "Forwarder Index" 3>&1 1>&2 2>&3)
                            indexNameExitStatus=$?

                            if [ $indexNameExitStatus = 0 ]; then
                                echo "srvrAddress: $srvrAddress" |& tee -a /home/$workingUSER/.$outputLOG
                                echo "indexName: $indexName" |& tee -a /home/$workingUSER/.$outputLOG
                                
                                if [ ${#srvrAddress} = 0 -o $srvrAddressExitStatus != 0 -o ${#indexName} = 0 -o $indexNameExitStatus != 0 ]; then
                                    if (whiptail --title "Warning" --yesno "Name was too short or selected cancel. Try again?" 8 78); then
                                        echo "User selected Yes, exit status was $?."
                                    else
                                        echo "User selected No, exit status was $?."; funcActionLoopCTL=1
                                    fi
                                else
                                    funcActionLoopCTL=1; funcMenuLoopCTL=1

                                    srchResultsToArray -s /home/ splunk deb
                                    menuMSG="Please select the Splunk Forwarder .deb file from the following:"
                                    fileSelected=$(whiptail --title "Splunk Forwarder Setup" --menu "$menuMSG" $termHeight $termWidth $linesToShow "${dataArray[@]}" 3>&1 1>&2 2>&3)
                                    echo "fileSelected: $fileSelected"  
                                    
                                    dpkg -i $fileSelected |& tee -a /home/$workingUSER/.$outputLOG
                                    /opt/splunkforwarder/bin/splunk start --accept-license --answer-yes
                                    /opt/splunkforwarder/bin/splunk add forward-server $srvrAddress
                                    /opt/splunkforwarder/bin/splunk enable boot-start
                                    
                                    srchResultsToArray -s /home/ splunk tgz                        
                                    menuMSG="Please select the Splunk the splunk add-on file from the following:"
                                    fileSelected=$(whiptail --title "Splunk Add-On Setup" --menu "$menuMSG" $termHeight $termWidth $linesToShow "${dataArray[@]}" 3>&1 1>&2 2>&3)
                                    fileSelectedExitStatus=$?
                                    echo "fileSelected: $fileSelected" |& tee -a /home/$workingUSER/.$outputLOG

                                    tar -zxvf $fileSelected -C $tempFileDir; chown -R splunk:splunk $tempFileDir/Splunk_TA_nix/;
                                    cp -ipr $tempFileDir/Splunk_TA_nix/ /opt/splunkforwarder/etc/apps/; 
                                    setSplunkIndex $indexName
                                    /opt/splunkforwarder/bin/splunk restart
                                fi 
                            else
                                funcActionLoopCTL=1
                            fi
                        else
                            funcActionLoopCTL=1
                        fi                    
                    done
                ;;
                UPDATE)
                    funcActionLoopCTL=0
                    while [ $funcActionLoopCTL -eq 0 ]
                    do
                        indexName=$(whiptail --inputbox "Please enter a the Splunk index name." 8 78 --title "Forwarder Index" 3>&1 1>&2 2>&3)
                        indexNameExitStatus=$?
                        echo "indexName: $indexName" |& tee -a /home/$workingUSER/.$outputLOG

                        if [ ${#indexName} = 0 -o $indexNameExitStatus != 0 ]; then
                            if (whiptail --title "Warning" --yesno "Name was too short or selected cancel. Try again?" 8 78); then
                                echo "User selected Yes, exit status was $?."
                            else
                                echo "User selected No, exit status was $?."; funcActionLoopCTL=1
                            fi
                        else
                            funcActionLoopCTL=1; funcMenuLoopCTL=1

                            setSplunkIndex $indexName  
                            /opt/splunkforwarder/bin/splunk restart
                        fi
                    done
                ;;
            esac
        fi
    done

    if [ "$1" != "chFctnCall" ];then
        timeStamp -e installSPLUNK; exitFunction toMain
    fi
}

function setSplunkIndex(){
#------------------------------------------------------------------------------------------
#   Description -   installSPLUNK support function for setting the 
#                   Splunk Forwarder index inputs.
#------------------------------------------------------------------------------------------
    indexName=$1
    cat > /opt/splunkforwarder/etc/apps/Splunk_TA_nix/default/inputs.conf <<EOFSPLF
# Copyright (C) 2019 Splunk Inc. All Rights Reserved.
[script://./bin/vmstat.sh]
interval = 60
sourcetype = vmstat
source = vmstat
disabled = 1

[script://./bin/iostat.sh]
interval = 60
sourcetype = iostat
source = iostat
disabled = 1

[script://./bin/nfsiostat.sh]
interval = 60
sourcetype = nfsiostat
source = nfsiostat
disabled = 1

[script://./bin/ps.sh]
interval = 600
sourcetype = ps
source = ps
index = $indexName
disabled = 0

[script://./bin/top.sh]
interval = 60
sourcetype = top
source = top
disabled = 1

[script://./bin/netstat.sh]
interval = 600
sourcetype = netstat
source = netstat
index = $indexName
disabled = 0

[script://./bin/bandwidth.sh]
interval = 60
sourcetype = bandwidth
source = bandwidth
disabled = 1

[script://./bin/protocol.sh]
interval = 60
sourcetype = protocol
source = protocol
disabled = 1

[script://./bin/openPorts.sh]
interval = 600
sourcetype = openPorts
source = openPorts
index = $indexName
disabled = 1

[script://./bin/time.sh]
interval = 21600
sourcetype = time
source = time
disabled = 1

[script://./bin/lsof.sh]
interval = 600
sourcetype = lsof
source = lsof
disabled = 1

[script://./bin/df.sh]
interval = 300
sourcetype = df
source = df
disabled = 1

# Shows current user sessions
[script://./bin/who.sh]
sourcetype = who
source = who
index = $indexName
interval = 150
disabled = 0

# Lists users who could login (i.e., they are assigned a login shell)
[script://./bin/usersWithLoginPrivs.sh]
sourcetype = usersWithLoginPrivs
source = usersWithLoginPrivs
interval = 3600
disabled = 1

# Shows last login time for users who have ever logged in
[script://./bin/lastlog.sh]
sourcetype = lastlog
source = lastlog
interval = 3600
disabled = 0

# Shows stats per link-level Etherner interface (simply, NIC)
[script://./bin/interfaces.sh]
sourcetype = interfaces
source = interfaces
interval = 60
disabled = 1

# Shows stats per CPU (useful for SMP machines)
[script://./bin/cpu.sh]
sourcetype = cpu
source = cpu
interval = 30
disabled = 1

# This script reads the auditd logs translated with ausearch
[script://./bin/rlog.sh]
sourcetype = auditd
source = auditd
interval = 60
disabled = 1

# Run package management tool collect installed packages
[script://./bin/package.sh]
sourcetype = package
source = package
interval = 3600
disabled = 0

[script://./bin/hardware.sh]
sourcetype = hardware
source = hardware
interval = 36000
disabled = 1

[monitor:///Library/Logs]
disabled = 1

[monitor:///var/log]
whitelist=(\.log|log$|messages|secure|auth|mesg$|cron$|acpid$|\.out)
blacklist=(lastlog|anaconda\.syslog)
index = $indexName
disabled = 0

[monitor:///var/adm]
whitelist=(\.log|log$|messages)
disabled = 1

[monitor:///etc]
whitelist=(\.conf|\.cfg|config$|\.ini|\.init|\.cf|\.cnf|shrc$|^ifcfg|\.profile|\.rc|\.rules|\.tab|tab$|\.login|policy$)
disabled = 1

### bash history
[monitor:///root/.bash_history]
disabled = false
sourcetype = bash_history
index = $indexName

[monitor:///home/*/.bash_history]
disabled = false
sourcetype = bash_history
index = $indexName



##### Added for ES support
# Note that because the UNIX app uses a single script to retrieve information
# from multiple OS flavors, and is intended to run on Universal Forwarders,
# it is not possible to differentiate between OS flavors by assigning
# different sourcetypes for each OS flavor (e.g. Linux:SSHDConfig), as was
# the practice in the older deployment-apps included with ES. Instead,
# sourcetypes are prefixed with the generic "Unix".

# May require Splunk forwarder to run as root on some platforms.
[script://./bin/openPortsEnhanced.sh]
disabled = true
interval = 3600
source = Unix:ListeningPorts
sourcetype = Unix:ListeningPorts

[script://./bin/passwd.sh]
disabled = true
interval = 3600
source = Unix:UserAccounts
sourcetype = Unix:UserAccounts

# Only applicable to Linux
[script://./bin/selinuxChecker.sh]
disabled = true
interval = 3600
source = Linux:SELinuxConfig
sourcetype = Linux:SELinuxConfig

# Currently only supports SunOS, Linux, OSX.
# May require Splunk forwarder to run as root on some platforms.
[script://./bin/service.sh]
disabled = true
interval = 3600
source = Unix:Service
sourcetype = Unix:Service

# Currently only supports SunOS, Linux, OSX.
# May require Splunk forwarder to run as root on some platforms.
[script://./bin/sshdChecker.sh]
disabled = true
interval = 3600
source = Unix:SSHDConfig
sourcetype = Unix:SSHDConfig

# Currently only supports Linux, OSX.
# May require Splunk forwarder to run as root on some platforms.
[script://./bin/update.sh]
disabled = true
interval = 86400
source = Unix:Update
sourcetype = Unix:Update

[script://./bin/uptime.sh]
disabled = true
interval = 86400
source = Unix:Uptime
sourcetype = Unix:Uptime

[script://./bin/version.sh]
disabled = true
interval = 86400
source = Unix:Version
sourcetype = Unix:Version

# This script may need to be modified to point to the VSFTPD configuration file.
[script://./bin/vsftpdChecker.sh]
disabled = true
interval = 86400
source = Unix:VSFTPDConfig
sourcetype = Unix:VSFTPDConfig

EOFSPLF
}

function setVMIP(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the IP address of a VM using Netplan.
#------------------------------------------------------------------------------------------
    timeStamp -s setVMIP
    
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi
    
    newIPAddress=""
    newGateway=""
    newDNS=""
    validInput=0
        
    case $workingENV in
        XCP-VM)
            ad1="eth0"
            #ad2="eth1"
            #ad3="eth3"
        ;;
        PRX)
            ad1="ens18"
            #ad2="ens19"
            #ad3="ens20"        
        ;;    
        *)
            ad1="enp0s3"
            #ad2="enp0s8"
            #ad3="enp0s9" 
        ;;
    esac
    
    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        adaptOption=$(whiptail --title "Networking" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "DHCP" "Reset to DHCP" OFF \
        "Set-IP" "Set adapter 1 IP address" OFF 3>&1 1>&2 2>&3)
        adaptOptionExitStatus=$?

        if [ ${#adaptOption} = 0 ] || [ $adaptOptionExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $adaptOption" |& tee -a /home/$workingUSER/.$outputLOG
            if [ "$adaptOption" != "DHCP" ];then
                formMessage="Current IP:$(hostname -I)\nUser selected: $adaptOption\n\nPlease enter the following details:"
                menuOption=$(dialog --ok-label "Submit" \
                    --backtitle "IP Configuration" \
                    --title "Set VM IP Address" \
                    --form "$formMessage" \
                    15 50 0 \
                    "IP: (192.168.1.77/24)" 1 1	"$newIPAddress" 	1 23 20 0 \
                    "Gateway: (192.168.1.7)"    2 1	"$newGateway"  	2 23 20 0 \
                    "DNS: (1.1.1.1)"    3 1	"$newDNS"  	3 23 20 0 \
                3>&1 1>&2 2>&3) 
                menuExitStatus=$?
                
                echo "$menuOption" >> $tempFileDir/tempDATA.txt
                srchResultsToArray 

                newIPAddress=${dataArray[0]}
                newGateway=${dataArray[2]}
                newDNS=${dataArray[4]}

                if [ ${#newIPAddress} -lt 10 ] || [ ${#newGateway} -lt 7 ] || [ ${#newDNS} -lt 7 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
                    exitFunction chkMain
                else
                    #Confirm the input
                    if (whiptail --title "WARNING!!!: Is this correct?" --yesno "IP: $newIPAddress\nGateway: $newGateway\nDNS: $newDNS" $termHeight $termWidth); then
                        validInput=1
                    else
                        funcMenuLoopCTL=0
                    fi                    
                fi
            fi

            #Apply the settings
            if [ $validInput -eq 1 ] || [ "$adaptOption" == "DHCP" ];then
                funcMenuLoopCTL=1
                echo "------------------------------------------------"
                echo "Applying changes..."
                cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml_BCKUP$(date "+%F-%T")
                        
                case $adaptOption in
                    "DHCP")
                        cat > /etc/netplan/50-cloud-init.yaml <<EOFIPDEFAULT
# This file is generated from information provided by
# the datasource.  Changes to it will not persist across an instance.
# To disable cloud-init's network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        $ad1:
            dhcp4: true
            optional: true
    version: 2    
EOFIPDEFAULT
                    ;;
                    *)
                        cat > /etc/netplan/50-cloud-init.yaml <<EOFIPVPN
# This file is generated from information provided by
# the datasource.  Changes to it will not persist across an instance.
# To disable cloud-init's network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        $ad1:
            addresses: [$newIPAddress]
            dhcp4: false
            gateway4: $newGateway
            nameservers:
                addresses: [$newDNS]
            optional: true
    version: 2    
EOFIPVPN
                    ;;
                esac
            
                netplan --debug generate |& tee -a /home/$workingUSER/.$outputLOG; netplan apply
                echo "IP address changed. Verify the changes." |& tee -a /home/$workingUSER/.$outputLOG
                echo " "; cat /etc/netplan/50-cloud-init.yaml
            fi
        fi
    done
    
    hostname -I
    if [ "$1" != "chFctnCall" ];then
        timeStamp -e setVMIP; exitFunction toMain
    fi
}

function assignRegIP(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the IP address of a VM from a hardcoded value.
#------------------------------------------------------------------------------------------
    timeStamp -s assignRegIP
    
    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi

    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "Set IP" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "PROXY" "Local Nginx proxy." OFF \
        "DB" "Database server." OFF \
        "CLOUD" "Nextcloud" OFF \
        "SMB" "Local SMB" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            funcMenuLoopCTL=1
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            case $workingENV in
                XCP-VM)
                    ad1="eth0"
                    #ad2="eth1"
                    #ad3="eth3"
                ;;
                PRX)
                    ad1="ens18"
                    #ad2="ens19"
                    #ad3="ens20"        
                ;;    
                *)
                    ad1="enp0s3"
                    #ad2="enp0s8"
                    #ad3="enp0s9" 
                ;;
            esac

            cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml_BCKUP$(date "+%F-%T")
            case $menuOption in
                PROXY) ipAdd="192.168.1.45/24" ;;
                DB) ipAdd="192.168.1.46/24" ;;
                CLOUD) ipAdd="192.168.1.47/24" ;; 
                SMB) ipAdd="192.168.1.48/24" ;;
            esac

            cat > /etc/netplan/50-cloud-init.yaml <<EOFSETIP
# This file is generated from information provided by
# the datasource.  Changes to it will not persist across an instance.
# To disable cloud-init's network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        $ad1:
            addresses: [$ipAdd]
            dhcp4: false
            gateway4: 192.168.1.1
            nameservers:
                addresses: [192.168.1.1]
            optional: true
    version: 2    
EOFSETIP
            netplan --debug generate |& tee -a /home/$workingUSER/.$outputLOG; netplan apply        
        fi
    done

    hostname -I
    if [ "$1" != "chFctnCall" ];then
        timeStamp -e assignRegIP; exitFunction toMain
    fi
}

function installJitsi(){
#------------------------------------------------------------------------------------------
#   Description -   Install, stop or remove Jitsi Meet.
#------------------------------------------------------------------------------------------
    timeStamp -s installJitsi

    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi

    menuOption=$(whiptail --title "Jitsi Meet" --radiolist \
    "Please select an option:" $termHeight $termWidth $linesToShow \
    "FULL" "Install with Turnserver" OFF \
    "NO-TURN" "Install without Turnserver" OFF \
    "ST" "Stop Jitsi Meeting Services except Nginx" OFF \
    "REM" "Remove Jitsi Meet and Nginx" OFF 3>&1 1>&2 2>&3)
    menuExitStatus=$?

    if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
        exitFunction chkMain
    else
        echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
        if [ "$menuOption" = "FULL" ] || [ "$menuOption" = "NO-TURN" ];then
            workingHostname=$(whiptail --inputbox "Please enter a valid Hostname. eg: meet.example.com" 8 78 --title "Hostname Address" 3>&1 1>&2 2>&3)
            wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | apt-key add - ;
            sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list";
            apt-get -y update; apt-get -y install apt-transport-https; 

            case $menuOption in
                FULL) apt -y install jitsi-meet ;;
                NO-TURN)
                    apt -y install --no-install-recommends jitsi-meet;
                    wget https://raw.githubusercontent.com/otalk/mod_turncredentials/master/mod_turncredentials.lua
                    cp mod_turncredentials.lua /usr/lib/prosody/modules/
                ;;
            esac
                 
            whiptail --title "Secure Jitsis Meet" --msgbox "Modify authentication for VirtualHost $workingHostname\nChange \"authentication = anonymous\" to \"authentication = internal_plain\"" $termHeight $termWidth
            nano /etc/prosody/conf.d/$workingHostname.cfg.lua 
            echo -e "\nVirtualHost \"guest.$workingHostname\"\n    authentication = \"anonymous\"\n    modules_enabled = {\n     \"turncredentials\";\n    }\n    c2s_require_encryption = false" >> /etc/prosody/conf.d/$workingHostname.cfg.lua
            systemctl reload prosody
            
            whiptail --title "Secure Jitsis Meet" --msgbox "Modify: anonymousdomain: 'guest.meet.example.com'" $termHeight $termWidth
            nano /etc/jitsi/meet/$workingHostname-config.js
            echo "--- Set Moderator password ---"; echo "Moderator: moduser@$workingHostname"
            prosodyctl adduser moduser@$workingHostname

            if (whiptail --title "NAT Setting" --yesno "Configure for NAT traversal?" $termHeight $termWidth); then
                whiptail --title "Config Modification" --msgbox "Comment the line \"org.ice4j.ice.harvest.STUN_MAPPING_HARVESTER_ADDRESSES\" " $termHeight $termWidth
                nano /etc/jitsi/videobridge/sip-communicator.properties
                localIP=$(hostname -I)
                publicIP=$(dig +short myip.opendns.com @resolver1.opendns.com) #Issues if you have a VPN connection active.
                echo "org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=$localIP" >> /etc/jitsi/videobridge/sip-communicator.properties
                echo "org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=$publicIP" >> /etc/jitsi/videobridge/sip-communicator.properties
                echo "org.jitsi.jicofo.auth.URL=XMPP:$workingHostname" >> /etc/jitsi/jicofo/sip-communicator.properties
            fi       

            if (whiptail --title "Final Config Check" --yesno "Perform final check?\nThis will open each config file (7 files) related to the Jitsi meet install." $termHeight $termWidth); then
                nano /etc/jitsi/jicofo/sip-communicator.properties;nano /etc/jitsi/jicofo/config;nano /etc/jitsi/meet/$workingHostname-config.js;nano /etc/jitsi/videobridge/config;nano /etc/jitsi/videobridge/sip-communicator.properties;nano /etc/nginx/sites-available/$workingHostname.conf;nano /etc/prosody/conf.avail/$workingHostname.cfg.lua;
                if [ "$menuOption" = "FULL" ];then
                    nano /etc/turnserver.conf
                fi                 
            fi
            
            ufw allow 443; ufw allow in 4443:4446/udp; ufw allow in 10000:20000/udp; ufw enable; ufw status verbose;
            systemctl reload prosody jicofo jitsi-videobridge2 cotrun nginx; systemctl restart prosody jicofo jitsi-videobridge2 coturn nginx; systemctl status prosody jicofo jitsi-videobridge2 coturn nginx;
        fi
        
        case $menuOption in
            ST) systemctl stop prosody jicofo jitsi-videobridge2 cotrun ;;
            REM) apt purge jitsi* jigasi prosody* coturn* nginx* jicofo* -y; apt autoremove -y; apt clean ;;
        esac        
    fi
        
    if [ "$1" != "chFctnCall" ];then
        timeStamp -e installJitsi; exitFunction toMain
    fi
}
#==============================================================================================================================================================
# SERVER ADMIN -END-
#==============================================================================================================================================================
#-
#--
#---
#----
#-----
#------
#-------
#--------
#---------
#----------
#---------
#--------
#-------
#------
#-----
#----
#---
#--
#-
#==============================================================================================================================================================
# GENERAL FUNCTIONS -START-
#==============================================================================================================================================================

function installSSHSERVER(){
#------------------------------------------------------------------------------------------
#   Description -   Install SSH server with key access only.
#------------------------------------------------------------------------------------------
    timeStamp -s installSSHSERVER

    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi

    funcMenuLoopCTL=0
    while [ $funcMenuLoopCTL -eq 0 ]
    do
        menuOption=$(whiptail --title "SSH" --radiolist \
        "Please select one of the following:" $termHeight $termWidth $linesToShow \
        "Install" "Fresh install of SSH server" OFF \
        "Add-Key" "Add ssh key to this machine." OFF 3>&1 1>&2 2>&3)
        menuExitStatus=$?

        if [ ${#menuOption} = 0 ] || [ $menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            exitFunction chkMain
        else
            echo "User selected: $menuOption" |& tee -a /home/$workingUSER/.$outputLOG
            case $menuOption in
                Install)
                    funcMenuLoopCTL=1
                    case $workingENV in
                        XCP-HV) yum install -y openssh-server |& tee -a /home/$workingUSER/.$outputLOG ;;
                        *) apt install openssh-server -y |& tee -a /home/$workingUSER/.$outputLOG ;;
                    esac
                                        
                    if (whiptail --title "SSH Key Copy" --yesno "Would you like to copy a key now?" $termHeight $termWidth); then
                        sshCopyKey
                    fi
                ;;
                Add-Key) funcMenuLoopCTL=1; sshCopyKey ;;
            esac
        fi
    done
    
    if [ "$1" != "chFctnCall" ];then
        timeStamp -e installSSHSERVER; exitFunction toMain
    fi
}

function sshCopyKey(){
#------------------------------------------------------------------------------------------
#   Description -   installSSHSERVER support function for setting up the ssh key access.
#------------------------------------------------------------------------------------------
    sshPortNum=2202
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config_bak$(date "+%F-%T")
    cat > /etc/ssh/sshd_config <<EOFLSSH1VM
Port $sshPortNum
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem	sftp	/usr/lib/openssh/sftp-server
EOFLSSH1VM
    
    case $workingENV in
        XCP-HV) systemctl restart sshd; system-config-firewall-tui ;;
        *)
            ufw allow 2202 |& tee -a /home/$workingUSER/.$outputLOG
            ufw enable |& tee -a /home/$workingUSER/.$outputLOG
            ufw status verbose |& tee -a /home/$workingUSER/.$outputLOG
            systemctl restart sshd
        ;;
    esac

menuMSG="Copy your SSH key to this host: $(hostname -I)\n
Port: $sshPortNum \n
IP: $(hostname -I)
ssh-copy-id $workingUSER@ipAddress -p $sshPortNum\n
To generate a key on your host use: ssh-keygen -b 4096\n
Press OK when the key has been coppied."
                
    whiptail --title "SSH Key Copy" --msgbox --scrolltext "$menuMSG" $termHeight $termWidth
    cat > /etc/ssh/sshd_config <<EOFLSSH2VM
Port $sshPortNum
PermitRootLogin no
MaxAuthTries 3
PubkeyAuthentication yes
HostbasedAuthentication no
IgnoreRhosts yes
PasswordAuthentication no 
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no 
X11Forwarding no 
PrintMotd no
ClientAliveInterval 600
ClientAliveCountMax 0
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server
EOFLSSH2VM
    systemctl restart sshd
}

function installNordVPN(){
#------------------------------------------------------------------------------------------
#   Description -   Install NordVPN and create a script thats is used for quick connections.
#------------------------------------------------------------------------------------------
    timeStamp -s installNordVPN

    if [ $debugSwitch = 1 ];then
        exitFunction dbg; return
    fi

    wget -P $tempFileDir/NordVPN https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb;
    dpkg -i $tempFileDir/NordVPN/nordvpn-release_1.0.0_all.deb
    apt update; apt install nordvpn -y

    if (whiptail --title "NordVPN Login" --yesno "Would you like to login now?" $termHeight $termWidth); then
        clear; echo "-Login-"; nordvpn login
    fi

    cat > /home/$workingUSER/nord.sh << EOFNORD
#!/bin/bash
#-------- Script Variables ----------
    termHeight=\$(tput lines)
    termWidth=\$(tput cols)
    linesToShow=10
    funcMenuLoopCTL=0
#------------------------------------

#---------- Quick Connect/Disconnect -----------
    case \$1 in
        -c) nordvpn connect ca584; nordvpn status; exit 1 ;;
        -u) nordvpn connect us2931; nordvpn status; exit 1 ;;
        -se) nordvpn connect se384; nordvpn status; exit 1 ;;
        -uk) nordvpn connect uk814; nordvpn status; exit 1 ;;
        -d) nordvpn disconnect; nordvpn status; exit 1 ;;
    esac
#------------------------------------

#----------- Main Menu --------------
    while [ \$funcMenuLoopCTL -eq 0 ]
    do
        menuOption=\$(whiptail --title "NordVPN Menu" --radiolist \\
        "Please select one of the following:" \$termHeight \$termWidth \$linesToShow \\
        "LI" "Login or switch accounts" OFF \\
        "LO" "Logout" OFF \\
        "CA" "Connect to Canada" OFF \\
        "US" "Connect to United States" OFF \\
        "SE" "Connect to Sweeden" OFF \\
        "UK" "Connect to United Kingdom" OFF \\
        "DIS" "Disconnect an active connection" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=\$?

        if [ \${#menuOption} = 0 ] || [ \$menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            if !(whiptail --title "Warning" --yesno "No option selected. Try again?" 8 78); then
                funcMenuLoopCTL=1
            fi
        else
            funcMenuLoopCTL=1
            clear
            case \$menuOption in
                LI) nordvpn logout; nordvpn login ;;
                LO) nordvpn logout ;;
                CA) nordvpn connect ca584 ;;
                US) nordvpn connect us2931 ;;
                SE) nordvpn connect se384 ;;
                UK) nordvpn connect uk814 ;;
                DIS) nordvpn disconnect ;;
            esac
        fi
    done
#------------------------------------

nordvpn status;
echo "*** Arrivederci! ***"
EOFNORD

    echo "-Connection script created-"
    if [ "$1" != "chFctnCall" ];then
        timeStamp -e installNordVPN; exitFunction toMain
    fi
}

#==============================================================================================================================================================
# GENERAL FUNCTIONS -END-
#==============================================================================================================================================================

# - - - - - - - - - - - - - - - - -
checkSwitches $1 $2 $3 $4 $5 $6
__main
# - - - - - - - - - - - - - - - - -