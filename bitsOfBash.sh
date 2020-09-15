#!/bin/bash
#------------------------------------------------------------------------------------------
#   Last update: September_15_2020_0054
#   Description -   This script aims to provide the user with a modular structure for 
#                   creating interactive bash scripts. Instead of having several scripts, 
#                   simply create a function using the "_bonesMalone" function as your guide. 
#                   Once the function is complete, add an entry to the menu or submenu of 
#                   your choice so that the option can be presented to the user. 
#                   This script has samples of making menus using whiptail and dialog.
#------------------------------------------------------------------------------------------
#   "Everything is code." - A. Russo
#   "Who looks outside dreams; who looks inside awakes." - Dr. Carl Jung
#   "Today will be better." - K. Miletic
#   "The sweet ain't the sweet without the sour." - R. Murphy
#   "A ship in harbor is safe, but that is not what ships are built for." - John A. Shedd
#------------------------------------------------------------------------------------------


#==========================================================================================
# MAIN AND SUPPORT FUNCTIONS -START-
#==========================================================================================

#------------------------------ < Script Switches > --------------------------------
#   Switch      |   Description
#------------------------------------------------------------------------------------------
#   -d          |   Debug Mode. Used for progressing through the main and sub menus 
#               |   without performing the core actions of the selected function.
#------------------------------------------------------------------------------------------
#   -b          |   Bypass root/sudo requirement for running the script. 
#               |   Useful for functions that do not require elevated previliges.
#------------------------------------------------------------------------------------------
#   -e          |   Sets the working environment. Useful when determining options 
#               |   such as network adapter name or package manager.    
#------------------------------------------------------------------------------------------
#   -q          |   Runs the _quickConfig function then exits the script. 
#------------------------------------------------------------------------------------------
#   -s          |   Sets the working user and environment with predefined values.
#------------------------------------------------------------------------------------------
#   -u          |   Sets the working user. When needed, file ownership is set to this user.
#------------------------------------------------------------------------------------------

#------------------------------ < Global Variables >-----------------------------
#set -o errexit
#set -o pipefail
#set -o nounset
#set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" #Script directory.
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")" #Script name with file extension.
__base="$(basename ${__file} .sh)" #Script name without file extension.
__root=${__dir} #Root folder.
__certFolder="SSL_Certificates"
__activeUser=""
__activeHome=""
__activeENV=""
__activeDomain=""
__terminalHeight=$(tput lines) || {
    __terminalHeight=20
}
__terminalWidth=$(tput cols) || {
    __terminalWidth=60
}
__terminalLines=15
__outputLOG="${__dir}/log_BitsOfBash.txt"
__data=()
__isDebug=0
__debugBanner=""
__exitToMain=""
__isSuperUser="false"
__sslRoot="/etc/ssl"
__sslCertificateDir="${__sslRoot}/${__activeDomain}"
__tempDirectory="/tmp/bitsOfBash"
__ipDATA=""

__lightSpeed="nope"
__userEmail="user@email.com"
#------------------------------------------------------------------------------------------

_main(){
    _logStamp -s _main
    _setupScript
    
    while true;
    do
        __menuOption=$(whiptail --title "Main Menu ${__debugBanner}" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "Lab" "Lab config options" OFF \
        "Server" "Server config options" OFF \
        "NVPN" "Install NordVPN" OFF \
        "WGUARD" "Wireguard Admin" OFF \
        "SSH" "Configure SSH Server on VM or desktop." OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Main menu option not selected." | _log
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit close
        else
            echo "User selected: ${__menuOption}" | _log
            case ${__menuOption} in
                Lab) _menuLab ;;
                Server) _menuServer ;;
                NVPN) _cfgNordVPN ;;
                WGUARD) _cfgWireguard ;;
                SSH) _cfgSSH ;;
            esac
        fi
    done    
}

_debug(){
#------------------------------------------------------------------------------------------
#   Description -   Creates a pause in execution to check the output of pervious commands.     
#------------------------------------------------------------------------------------------
    _logStamp -s _debug
    echo "-- DEBUG MODE --\n-- PRESS ENTER TO CONTINUE --" | _log; read __debugPause
    _logStamp -e _debug
}

_log(){
#------------------------------------------------------------------------------------------
#   Description -   Wites the output of a comand to the specified log file.
#   Warning     -   Issues when trying to log a command that has graphical output to the terminal.     
#------------------------------------------------------------------------------------------
    while read __input
    do 
        __time=`date "+%Y-%m-%d %H:%M:%S"`
        touch ${__outputLOG}; chown ${__activeUser}:${__activeUser} ${__outputLOG}
        echo ${__time}": ${__input}" |& tee -a ${__outputLOG}
    done
}

_completePrompt(){
#------------------------------------------------------------------------------------------
#   Description -   General prompt.     
#------------------------------------------------------------------------------------------
    __promptDetails=$1 || {
        __promptDetails="Done!"
    }
    echo "Press enter to continue.."; read __userWait
    echo "Finishing up..."; sleep 3
    whiptail --title "* -INFO- *" --msgbox "${__promptDetails}" 8 ${__terminalWidth}
}

_scriptSwitches(){ 
#------------------------------------------------------------------------------------------
#   Description -   Checks the values passed into the script by the user.
#                   This will check for a valid flag then process the value that 
#                   follows the flag or set the value for a global variable.
#
#   Issues/ToDo -   No support yet for validating the input.
#------------------------------------------------------------------------------------------
    mkdir -p ${__tempDirectory}

    local __swithcVal
    local OPTIND
    local OPTARG
    while getopts e:u:bdqs __swithcVal
    do
        case ${__swithcVal} in
            b) __isSuperUser="true" ;;
            d)  
                __isDebug=1;
                __debugBanner="*DEBUG-MODE*"; echo "+ ${__debugBanner} +" | _log
            ;;
            e) __activeENV=${OPTARG} ;;
            q) _quickConfig; exit 0 ;;
            s) __activeUser="root"; __activeENV="ADMIN" ;;
            u) __activeUser=${OPTARG} ;;
            *) echo "script usage: $(basename $0) [-e Environment] [-u User] [-d Debug] [-b Bypass root]" ; exit 1 ;;   
        esac
    done
}


_exit(){
#------------------------------------------------------------------------------------------
#   Description -   Manages exiting from functions, menus and the script itself. 
#                   Presents a prompt to the user when needed.
#------------------------------------------------------------------------------------------
    __exitToMain=false
    case $1 in
        chkMain)
            if (whiptail --title "*WARNING*" --yesno "No option selected or invalid input. Return to the main menu?" 8 78); then
                echo "User selected Yes" | _log; __exitToMain=true;
            else
                echo "User selected No" #Try again. Other actions could be added here.
            fi
        ;;
        toMain) whiptail --title "Info" --msgbox "Returing to main menu" 8 40 ;;
        close)
            if (whiptail --title "*WARNING*" --yesno "Exit the script?" 8 40); then
                _logStamp -s _main; rm -r ${__tempDirectory}; clear; echo "*** Arrivederci! ***" | _log; exit 0
            fi
        ;;
        dbg) whiptail --title "-- DEBUG --" --msgbox "DEBUG!!! Returing to main menu" 8 40 ;;
    esac
}

_setupScript(){
#------------------------------------------------------------------------------------------
#   Description -   Sets global variables and perform checks before presenting main menu.   
#------------------------------------------------------------------------------------------
    #Check if script is being run as privileged user or the bypass is being used.
    if [ "$__isSuperUser" != "true" ]; then
        if [[ $EUID -ne 0 ]]; then
            clear; echo "Please run as a privileged user or use \"-b\" to proceed. The \"-b\" switch is only for actions that does not require elevated privileges."; exit 1
        fi
    fi

    rm -r ${__tempDirectory} || {
        echo "Please wait..."
    }
    mkdir -p ${__tempDirectory}

    #Check if pkg dialog is installed. This is currently the only dependency.
    __isReady=$(which dialog) || {
        clear; echo "+++ Installing dependencies +++"; sleep 1; 
        sudo apt update && sudo apt install dialog whiptail -y || {
            echo "*ERROR* Dependencies could not be installed. Exiting..." | _log; exit 0
        }
        echo "+++ Dependencies installed +++" | _log
    }
    
    if [ "${__activeUser}" != "root" ]; then
        #Check if a working environment has been set
        if [ ${#__activeENV} = 0 ]; then
            _cfgEnvironment
        fi
        
        #Check if a user has been set
        if [ ${#__activeUser} = 0 ]; then
            _cfgUser
        fi
        __activeHome="/home/${__activeUser}"
    else
        __activeHome="/root"
    fi
    clear; echo "+++ Loading main menu +++"; sleep 1
}

_cfgEnvironment(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the global variable for the working environment of the script.
#                   This is useful for creating functions that may need changes depending
#                   on the working environment. Eg. Switching to yum or apt.
#------------------------------------------------------------------------------------------
    while true
    do
        __activeENV=$(whiptail --title "Environment ${__debugBanner}" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "PRX" "Proxmox Virtual Machine or HV" OFF \
        "LAB" "VM or Desktop Env." OFF \
        "VPS" "Cloud VPS provider (Linode,Google)" OFF \
        "AWS" "AWS node." OFF \
        "VBox" "VirtualBox VM" OFF \
        "DOCR" "Docker Container" OFF \
        "XCP-HV" "XCP-NG Hypervisor" OFF \
        "XCP-VM" "XCP-NG Virtual Machine" OFF 3>&1 1>&2 2>&3) || {
            echo "Environment not selected." | _log;
        }
        
        if [ ${#__activeENV} = 0 ]; then 
            whiptail --title "Error" --msgbox "An environment must be selected." 8 40
            _exit close
        else
            echo "Environment selected: ${__activeENV}"  | _log; break
        fi
    done
}

_cfgUser(){ 
#------------------------------------------------------------------------------------------
#   Description -   Sets the working user for the script. Can be used to 
#                   set a user quickly based on the environment or have the user
#                   select a username that currently has a home directory.
#                   Eg. For AWS the user is hardcoded as "ubuntu"
#------------------------------------------------------------------------------------------
    local __swithcVal
    local OPTIND
    local OPTARG
    local __validUser=false

    while getopts c: __swithcVal
    do
        case ${__swithcVal} in
            c) 
                _search -u
                for i in "${__data[@]}"
                do
                    if [ "$i" == "${OPTARG}" ] ; then
                        __validUser=true
                    fi
                done

                if [ "${__validUser}" == "true" ] ; then
                    __activeUser=${OPTARG}; return
                else
                    echo "*ERROR* Invalid user ${OPTARG}. Exiting..."; sleep 3; exit 1
                fi                
            ;;
        esac
    done
    
    while true
    do
        case ${__activeENV} in
            AWS)
                __activeUser="ubuntu"
                echo "User selected: ${__activeUser}" | _log; return
            ;;
            *)
                _search -u    
                menuMSG="Please select a user:"
                __activeUser=$(whiptail --title "User Select" --menu "${menuMSG}" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} "${__data[@]}" 3>&1 1>&2 2>&3) || {
                    echo "*WARNING* User not selected." | _log;
                }
                     
                if [ ${#__activeUser} = 0 ]; then 
                    whiptail --title "*Error*" --msgbox "A user must be selected." 8 40
                    _exit close
                else
                    echo "User selected: ${__activeUser}" | _log; return
                fi
            ;;
        esac 
    done
}

_cfgDomain(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the working domain name for script activities.  
#------------------------------------------------------------------------------------------
    local __swithcVal
    local OPTIND
    local OPTARG
    
    while getopts :i:j:n: __swithcVal
    do
        case ${__swithcVal} in
        i) __activeDomain="example1.dev"; return ;;
        j) __activeDomain="example2.dev"; return ;;
        n) __activeDomain="example3.dev"; return ;;
        esac
    done

    while true
    do
        __menuOption=$(whiptail --title "Set Domain" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "S1" "Site: example1.dev" OFF \
        "S2" "Site: example2.dev" OFF \
        "S3" "Site: example3.dev" OFF \
        "ENT" "Enter a domain" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Domain not set." | _log
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                return
            fi
        else
            echo "User selected: ${__menuOption}" | _log
            case ${__menuOption} in
                S1) __activeDomain="example1.dev" ;;
                S2) __activeDomain="example2.dev" ;;
                S3) __activeDomain="example3.dev" ;;
                ENT)
                    __menuMSG="Please enter a valid domain name. eg. \"example.com\""
                    __activeDomain=$(whiptail --inputbox "${__menuMSG}" ${__terminalHeight} ${__terminalWidth} example.com --title "Domain Name" 3>&1 1>&2 2>&3) || {
                        echo "*WARNING* Domain not set. Setting default to defaultsite.com... Press Enter" | _log;  __activeDomain="defaultsite.com"; read __userWait
                    }
                ;;
            esac
            
            __certDir=$(sudo find $__root/SSL_Certificates -type d -iname \*${__activeDomain}\*) || {
                echo "*WARNING* Cert directory not found."
            }

            if [ ${#__certDir} = 0 ]; then 
                whiptail --title "*WARNING*" --msgbox "Certs not found in $__root/SSL_Certificates." 8 ${__terminalWidth}
            else
                __sslCertificateDir="${__sslRoot}/$__activeDomain"
                sudo mkdir -p $__sslCertificateDir;
                sudo cp -r $__root/SSL_Certificates/$__activeDomain/* $__sslCertificateDir
                ls $__root/SSL_Certificates/$__activeDomain;
                cd $__sslCertificateDir; cp privkey1.pem privkey1.key; cp cert1.pem cert1.crt; cp fullchain1.pem fullchain1.crt; cp chain1.pem chain1.crt
                whiptail --title "*WARNING*" --msgbox "Certs copied to $__root/SSL_Certificates." 8 ${__terminalWidth}
            fi  

            return
        fi       
    done 
}

_search(){
#------------------------------------------------------------------------------------------
#   Description -   Performs a search based on the flag or values passed in.
#                   The results will be added to a temp txt file then entered into the
#                   global data array used for presenting the results as a list to the user.
#------------------------------------------------------------------------------------------
    clear
    echo "--------------------------------------------------"
    echo "Searching......"
    echo "--------------------------------------------------"

    rm ${__tempDirectory}/tempDATA.txt || {
        echo "Please wait..." | _log;
    }
    __data=()
    
    case $1 in
        -f) find $2 -type f -iname "*.$3" >> ${__tempDirectory}/tempDATA.txt ;;
        -d) find $2 -type d -iname \*$3\* >> ${__tempDirectory}/tempDATA.txt ;; #sudo find /etc/ssl -type d -iname *example.com*
        -s) find $2 -iname \*$3\*.$4 >> ${__tempDirectory}/tempDATA.txt ;;
        -u) echo "$(getent passwd {1000..60000} | cut -d: -f1)" >> ${__tempDirectory}/tempDATA.txt ;;
        -m)
            find /home/ -type f -name "*.iso" >> ${__tempDirectory}/tempDATA.txt
            find /media/${__activeUser} -type f -name "*.iso" >> ${__tempDirectory}/tempDATA.txt
            find /home/ -type f -name "*.img" >> ${__tempDirectory}/tempDATA.txt
            find /media/${__activeUser} -type f -name "*.img" >> ${__tempDirectory}/tempDATA.txt
        ;;
        -i)
            echo "${__ipDATA}" >> ${__tempDirectory}/tempDATA.txt
            cat ${__tempDirectory}/tempDATA.txt;
        ;;
        -dev) lsblk -o NAME,SIZE -e7 | grep ^sd >> ${__tempDirectory}/tempDATA.txt ;;
        -ndev) netstat -i | grep $2 >> ${__tempDirectory}/tempDATA.txt ;;
    esac        

    if [[ -s ${__tempDirectory}/tempDATA.txt ]]; then
        cat ${__tempDirectory}/tempDATA.txt | _log;    
        while IFS= read line
        do
            __data+=("${line}")
            __data+=("")
        done < ${__tempDirectory}/tempDATA.txt        
    else
        __data+=("No_Data_Found")
        __data+=("")
    fi
}

_logStamp(){
#------------------------------------------------------------------------------------------
#   Description -   Adds date and time info to the logs about when a function
#                   started and ended. Useful for checking previous activities.
#------------------------------------------------------------------------------------------
    case $1 in
        -s) scriptState="START" ;;
        -e) scriptState="END" ;;
    esac

    echo " " | _log
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | _log
    echo "+++ $2 ${scriptState}: $(date) +++" | _log
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | _log
    echo " " | _log
}

_bonesMalone(){
#------------------------------------------------------------------------------------------
#   Description -   The basic format for the functions used in this script.
#
#   Step 1      -   Apply starting _logStamp.
#   Step 2      -   Check for debug. Will exit to the main menu if the debug value is set.
#   Step 3      -   Main body/loop for the function. If the loop is used, it will continue 
#                   until the user selects a valid menu option or choses to exit by selecting cancel.
#   Step 4      -   Check if the function call is a part of a chain of function calls.
#                   (Multiple calls. eg. _cfgNordVPN chFctnCall -> _sysConfig)
#                   This means that the function will not exit to the main menu if another
#                   function is being called after completing the current one. 
#   Step 5      -   Apply the ending _logStamp.
#------------------------------------------------------------------------------------------
    #Step 1
    _logStamp -s _bonesMalone

    #Step 2
    if [ ${__isDebug} = 1 ]; then
        _exit dbg; return
    fi    

    #Step 3
    #Run some commands. This is a sample menu with whiptail.
    while true
    do
        __menuOption=$(whiptail --title "Skeleton Function" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "OP1" "Skeleton Option #1" OFF \
        "OP2" "Skeleton Option #2" OFF 3>&1 1>&2 2>&3) || {
            echo "Option not selected."
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                break
            fi
        else
            echo "__menuOption: ${__menuOption}" | _log
            case ${__menuOption} in
                OP1)
                    __funcActionLoopCTL=0
                    while [ ${__funcActionLoopCTL} -eq 0 ]
                    do
                        __funcActionLoopCTL=1;  read __debugPause
                    done                    
                ;;
                OP2)
                    read __debugPause
                ;;
            esac

            #Step 4
            if [ "${__lightSpeed}" == "nope" ];then
                _completePrompt "Action ${__menuOption} complete."
            fi
            
            break
        fi
    done

    #Step 5
    _logStamp -e _bonesMalone
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

_menuLab(){
#------------------------------------------------------------------------------------------
#   Description -   The menu for Desktop and Lab VM config
#------------------------------------------------------------------------------------------
    while true
    do
        __menuOption=$(whiptail --title "DSK Options ${__debugBanner}" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "ENV-LAUNCH" "NordVPN & System config" OFF \
        "SYSCO" "System config" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Option not selected." | _log
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                return
            fi
        else
            echo "User selected: ${__menuOption}" | _log
            case ${__menuOption} in
                ENV-LAUNCH)
                    __lightSpeed="true"; #Skip the end prompts.
                    _cfgNordVPN; 
                    __lightSpeed="nope"; #Stop skipping the end prompts.
                    _sysConfig;
                ;;
                SYSCO) _sysConfig ;;
            esac
            return
        fi
    done    
}

_sysConfig(){
#------------------------------------------------------------------------------------------
#   Description -   Performs system update, installs the specified packages and
#                   creates a basic script for quick manual updating and clean up.
#
#   Issues/ToDo -   Logging snap package installs with the current logging method does not work.
#------------------------------------------------------------------------------------------
    _logStamp -s _sysConfig
    
    if [ ${__isDebug} = 1 ]; then
        _exit dbg; return
    fi

    if (whiptail --title "SNAP Packages" --yesno "Install SNAP packages?" ${__terminalHeight} ${__terminalWidth}); then
        snap install spotify; snap install vlc; snap install electron-mail; snap install signal-desktop
    fi

    apt update && apt upgrade -y | _log
    apt install net-tools -y | _log
    apt install exfat-fuse exfat-utils -y | _log
    apt install screenfetch -y | _log
    apt install git -y | _log
    apt install filezilla -y | _log
    apt install dnsutils -y | _log
    apt install htop -y | _log
    apt install gparted -y | _log
    apt install cmatrix -y | _log
    apt install tmux -y | _log 
    apt install iperf -y | _log 
    
    apt clean; apt autoremove -y
    _writeScript -u

    if [ "${__lightSpeed}" == "nope" ];then
        _completePrompt "Sysconfig complete."
    fi

    _logStamp -e _sysConfig
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

_menuServer(){
#------------------------------------------------------------------------------------------
#   Description -   The menu used for the functions related to Server VM's.
#------------------------------------------------------------------------------------------
    if [ ${#__activeDomain} = 0 ]; then
        _cfgDomain
    fi
    
    while true
    do
        __menuOption=$(whiptail --title "SRVR Options ${__debugBanner}" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "DB" "Install MariaDB, MySQL or Mongo DB." OFF \
        "SMB" "Install SAMBA file server." OFF \
        "JITSI" "Jitsi meet options." OFF \
        "SET-IP" "VM IP config" OFF \
        "REG-IP" "Assign registered IP" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Server option not selected." | _log
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                return
            fi            
        else
            echo "User selected: ${__menuOption}" | _log
            
            case ${__menuOption} in
                DB) _cfgDatabase ;;
                SMB) _cfgSMB ;;
                JITSI) _cfgJitsiMeet ;;
                SET-IP) _setIPVM ;;
                REG-IP) _setIPRegistered ;;
            esac
            
            return
        fi        
    done
}

_cfgDatabase(){
#------------------------------------------------------------------------------------------
#   Description -   Install a database.
#------------------------------------------------------------------------------------------
    _logStamp -s _cfgDatabase
    
    if [ ${__isDebug} = 1 ]; then
        _exit dbg; return
    fi 
    
    while true
    do
        __menuOption=$(whiptail --title "Database Menu" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "MongoDB" "Basic install" OFF \
        "MariaDB" "With utf8 charset" OFF \
        "MySQL"  "With utf8 charset" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Option not selected."
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                break
            fi  
        else
            echo "User selected: ${__menuOption}" | _log
            __menuMSG="DB Type selected: ${__menuOption}\nDB port Examples: 27000 for MongoDB, 65101 for MariaDB & MySQL."
            __portNumber=$(whiptail --inputbox "${__menuMSG}" 8 78 --title "Enter DB Port Number" 3>&1 1>&2 2>&3) || {
                echo "*WARNING* No user input." | _log
            }
            
            if [ ${#__portNumber} != 0 ]; then
                if (whiptail --title "WARNING!!!: Is this correct?" --yesno "DB Type: ${__menuOption}\nPort: ${__portNumber}" ${__terminalHeight} ${__terminalWidth}); then
                    echo "__portNumber: ${__portNumber}" | _log
                    case ${__menuOption} in
                        MariaDB) _cfgMariaDB ${__portNumber} ;;
                        MongoDB) _cfgMongoDB ${__portNumber} ;;
                        *) _cfgMySQL ${__portNumber} ;;    
                    esac

                    sudo ufw allow ${__portNumber}; sudo ufw enable; sudo ufw status verbose | _log

                    _completePrompt "${__menuOption} installed. Test the connection:\nmysql -u username -h 192.168.X.XXX -P ${__portNumber}\nmongo localhost:${__portNumber}"
                    if [ "${__lightSpeed}" == "nope" ];then
                        _completePrompt "Database ${__menuOption} complete."
                    fi

                    break
                fi                                                  
            fi             
        fi
    done    

    _logStamp -e _cfgDatabase 
}

_cfgMariaDB(){
#------------------------------------------------------------------------------------------
#   Description -   _cfgDatabase support function installing MariaDB
#------------------------------------------------------------------------------------------
    apt install mariadb-server -y | _log
    case ${__activeENV} in
        DOCR) service mysql stop ;;
        *) systemctl stop mysql ;;
    esac 

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

    case ${__activeENV} in
        DOCR) service mysql start; mysql_secure_installation; service mysql restart  ;;
        *) systemctl start mysql; mysql_secure_installation; systemctl restart mysql ;;
    esac 
}

_cfgMySQL(){
#------------------------------------------------------------------------------------------
#   Description -   _cfgDatabase support function installing MySQL
#------------------------------------------------------------------------------------------
    sudo apt install mysql-server -y | _log
    case ${__activeENV} in
        DOCR) service mysql stop ;;
        *) sudo systemctl stop mysql ;;
    esac 

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
#bind-address		= 0.0.0.0
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

    echo "[client]" >> /etc/mysql/my.cnf;
    echo "default-character-set=utf8" >> /etc/mysql/my.cnf;
    echo "[mysql]" >> /etc/mysql/my.cnf;
    echo "default-character-set=utf8" >> /etc/mysql/my.cnf;
    echo "[mysqld]" >> /etc/mysql/my.cnf;
    echo "collation-server = utf8_unicode_ci" >> /etc/mysql/my.cnf;
    echo "init-connect='SET NAMES utf8'" >> /etc/mysql/my.cnf;
    echo "character-set-server = utf8" >> /etc/mysql/my.cnf;
    
    case ${__activeENV} in
        DOCR) service mysql start; mysql_secure_installation; mysql_ssl_rsa_setup --uid=mysql; service mysql restart ;;
        *) systemctl start mysql; mysql_secure_installation; mysql_ssl_rsa_setup --uid=mysql; systemctl restart mysql ;;
    esac 
}

_cfgMongoDB(){
#------------------------------------------------------------------------------------------
#   Description -   _cfgDatabase support function installing MongoDB
#------------------------------------------------------------------------------------------
    sudo apt install mongodb -y | _log
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
    
    case ${__activeENV} in
        DOCR) service mongodb restart ;;
        *) systemctl restart mongodb ;;
    esac 
}

_cfgSMB(){ 
#------------------------------------------------------------------------------------------
#   Description -   Install and secure a SAMBA file server.
#------------------------------------------------------------------------------------------
    _logStamp -s _cfgSMB
    
    if [ ${__isDebug} = 1 ];then
        _exit dbg; return
    fi
    
    sudo apt install libcups2 samba samba-common cups -y | _log
    mv /etc/samba/smb.conf /etc/samba/smb.conf_bak$(date "+%F-%T")
    mkdir -p /home/shared
    chown -R root:users /home/shared
    chmod -R 770 /home/shared
    cat > /etc/samba/smb.conf <<EOFSAMBA
[global]
workgroup = WORKGROUP
server string = Samba Server %v
netbios name = SMBX123
security = user
map to guest = bad user
dns proxy = no

[shared]
comment = VM_SMB_SHARE
path = /home/shared
valid users = @users
force group = users
create mask = 0660
directory mask = 0771
writable = yes
EOFSAMBA
    
    systemctl restart smbd
    echo "Creating user smbuser."
    useradd -m -p $(openssl passwd -1 uhytg7hh96gbh7fbzsa#@1DEer4) smbuser
    usermod -a -G users smbuser
    echo "Please set SMB password for smbuser."
    smbpasswd -a smbuser
    systemctl restart smbd
    ufw allow samba; ufw enable

    if [ "${__lightSpeed}" == "nope" ];then
        _completePrompt "SMB install complete."
    fi

    _logStamp -e _cfgSMB; 
}

_cfgJitsiMeet(){
#------------------------------------------------------------------------------------------
#   Description -   Install, stop or remove Jitsi Meet.
#------------------------------------------------------------------------------------------
    _logStamp -s _cfgJitsiMeet

    if [ ${__isDebug} = 1 ]; then
        _exit dbg; return
    fi

    while true
    do
        __menuOption=$(whiptail --title "Jitsi Meet" --radiolist \
        "Please select an option:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "FULL" "Install with Turnserver" OFF \
        "NO-TURN" "Install without Turnserver" OFF \
        "ST" "Stop Jitsi Meeting Services except Nginx" OFF \
        "REM" "Remove Jitsi Meet and Nginx" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Option not selected."
        }

        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                return
            fi 
        else
            echo "User selected: ${__menuOption}" | _log
            if [ "${__menuOption}" = "FULL" ] || [ "${__menuOption}" = "NO-TURN" ]; then
                __workingHostname=$(whiptail --inputbox "Please enter a valid Hostname. eg: meet.example.com" 8 78 meet.example.com --title "Server Hostname" 3>&1 1>&2 2>&3)
                wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | apt-key add - ;
                sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list";
                apt-get -y update; apt-get -y install apt-transport-https; 
                
                __certDir=$(sudo find ${__sslRoot} -type d -iname \*${__activeDomain}\*) || {
                    echo "*WARNING* Cert directory not found." | _log
                }

                if [ ${#__certDir} = 0 ]; then 
                    whiptail --title "*WARNING*" --msgbox "Certs not found in ${__sslRoot}. Select the option to generate certs when prompted." 8 40
                else
                    cd ${__sslCertificateDir}; 
                    cp privkey1.pem ${__sslRoot}/${__workingHostname}.key || {
                        echo "*WARNING* Key not found." | _log
                    } 
                    cp fullchain1.pem ${__sslRoot}/${__workingHostname}.crt || {
                        echo "*WARNING* Cert not found." | _log
                    }
                fi               
                
                case ${__menuOption} in
                    FULL) apt -y install jitsi-meet ;;
                    NO-TURN)
                        apt -y install --no-install-recommends jitsi-meet;
                        wget https://raw.githubusercontent.com/otalk/mod_turncredentials/master/mod_turncredentials.lua
                        cp mod_turncredentials.lua /usr/lib/prosody/modules/
                    ;;
                esac
                    
                whiptail --title "Secure Jitsis Meet" --msgbox "Modify authentication for VirtualHost ${__workingHostname}\nChange \"authentication = anonymous\" to \"authentication = internal_hashed\"" ${__terminalHeight} ${__terminalWidth}
                nano /etc/prosody/conf.d/${__workingHostname}.cfg.lua 
                echo -e "\nVirtualHost \"guest.${__workingHostname}\"\n    authentication = \"anonymous\"\n    modules_enabled = {\n     \"turncredentials\";\n    }\n    c2s_require_encryption = false" >> /etc/prosody/conf.d/${__workingHostname}.cfg.lua
                systemctl reload prosody
                
                whiptail --title "Secure Jitsis Meet" --msgbox "Modify: anonymousdomain: 'guest.${__workingHostname}'" ${__terminalHeight} ${__terminalWidth}
                nano /etc/jitsi/meet/${__workingHostname}-config.js
                echo "--- Set Moderator password ---"; echo "Moderator: moduser@${__workingHostname}"
                prosodyctl adduser moduser@${__workingHostname}

                echo -e "#ssl_trusted_certificate ${__sslCertificateDir}/chain1.pem;" >> /etc/nginx/sites-available/${__workingHostname}.conf
                echo -e "#ssl_dhparam /etc/ssl/dhparam.pem;" >> /etc/nginx/sites-available/${__workingHostname}.conf
                
                if (whiptail --title "NAT Setting" --yesno "Configure for NAT traversal?" ${__terminalHeight} ${__terminalWidth}); then
                    whiptail --title "Config Modification" --msgbox "Comment the line \"org.ice4j.ice.harvest.STUN_MAPPING_HARVESTER_ADDRESSES\" " ${__terminalHeight} ${__terminalWidth}
                    nano /etc/jitsi/videobridge/sip-communicator.properties
                    __localIP=$(hostname -I)
                    __publicIP=$(dig +short myip.opendns.com @resolver1.opendns.com) #Issues if you have a VPN connection active.
                    echo "org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=${__localIP}" >> /etc/jitsi/videobridge/sip-communicator.properties
                    echo "org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=${__publicIP}" >> /etc/jitsi/videobridge/sip-communicator.properties
                    echo "org.jitsi.jicofo.auth.URL=XMPP:${__workingHostname}" >> /etc/jitsi/jicofo/sip-communicator.properties
                fi       

                if (whiptail --title "Final Config Check *RECOMMENDED*" --yesno "Perform final check?\nThis will open a few config files (7 files) related to the Jitsi meet install." ${__terminalHeight} ${__terminalWidth}); then
                    nano /etc/jitsi/jicofo/sip-communicator.properties;nano /etc/jitsi/jicofo/config;nano /etc/jitsi/meet/${__workingHostname}-config.js;nano /etc/jitsi/videobridge/config;
                    nano /etc/jitsi/videobridge/sip-communicator.properties;nano /etc/nginx/sites-available/${__workingHostname}.conf;
                    nano /etc/prosody/conf.avail/${__workingHostname}.cfg.lua; nano /etc/nginx/modules-enabled/60-jitsi-meet.conf;
                    if [ "${__menuOption}" = "FULL" ]; then
                        nano /etc/turnserver.conf
                    fi                 
                fi
                
                ufw allow 443; 
                ufw allow 4443;
                ufw allow in 10000/udp; 
                ufw enable; 
                ufw status verbose;
                systemctl reload prosody jicofo jitsi-videobridge2 cotrun nginx || {
                    echo "catch error."
                } 
                systemctl restart prosody jicofo jitsi-videobridge2 coturn nginx || {
                    echo "catch error."
                } 
                
                systemctl status prosody jicofo jitsi-videobridge2 coturn nginx || {
                    echo "catch error."
                }
            fi
            
            case ${__menuOption} in
                ST) systemctl stop prosody jicofo jitsi-videobridge2 cotrun ;;
                REM) apt purge jitsi* jigasi prosody* coturn* nginx* jicofo* -y; apt autoremove -y; apt clean ;;
            esac 
            
            if [ "${__lightSpeed}" == "nope" ];then
                _completePrompt "Jitis meet installed."
            fi

            break       
        fi
    done 

    _logStamp -e _cfgJitsiMeet
}

_cfgWireguard(){ 
#------------------------------------------------------------------------------------------
#   Description -   Wireguard VPN
#------------------------------------------------------------------------------------------
    _logStamp -s _cfgWireguard

    if [ ${__isDebug} = 1 ];then
        _exit dbg; return
    fi

    local __network="10.10.40.0/24"
    local __oct1="$(echo ${__network} | cut -d \. -f 1)"
    local __oct2=$(echo ${__network} | cut -d \. -f 2)
    local __oct3=$(echo ${__network} | cut -d \. -f 3)
    local __srvrAddress="1"
    local __netMask=$(echo ${__network} | cut -d \/ -f 2)
    local __net1="131"
    local __net2="151"
    local __net3="181"
    local __clientIPAddress=""
    local __workingPUBKey=""
    local __remoteServer="0.0.0.0:51820"
    
    _pkgInstall(){
        sudo apt update; sudo apt install software-properties-common -y
        sudo add-apt-repository ppa:wireguard/wireguard -y
        sudo apt install ufw openresolv wireguard wireguard-tools wireguard-dkms -y
    }

    _setNetIP(){
        __oct1=$(echo $1 | cut -d \. -f 1)
        __oct2=$(echo $1 | cut -d \. -f 2)
        __oct3=$(echo $1 | cut -d \. -f 3)
        __oct4=$(echo $(echo $1 | cut -d \. -f 4) | cut -d \/ -f 1)
        __netMask=$(echo $1 | cut -d \/ -f 2)
        __network=${__oct1}.${__oct2}.${__oct3}.${__oct4}/${__netMask}
    }

    _setNetwork(){
        __menuOption=$(whiptail --title "Network Options" --radiolist \
        "Please select a network or enter one:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "N1" "${__oct1}.${__oct2}.$__net1.0/${__netMask}" OFF \
        "N2" "${__oct1}.${__oct2}.$__net2.0/${__netMask}" OFF \
        "N3" "${__oct1}.${__oct2}.$__net3.0/${__netMask}" OFF \
        "ENTER" "Enter a different network" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Network not selected." 
        }
      
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                return
            fi 
        else
            echo "User selected: ${__menuOption}" 
          
            case ${__menuOption} in
                N1) __newNetIP="${__oct1}.${__oct2}.${__net1}.0/${__netMask}" ;;
                N2) __newNetIP="${__oct1}.${__oct2}.${__net2}.0/${__netMask}" ;;
                N3) __newNetIP="${__oct1}.${__oct2}.${__net3}.0/${__netMask}" ;;
                ENTER)
                    __menuMSG="Enter an address. eg. \"10.10.77.0/24\""
                    __newNetIP=$(whiptail --inputbox "${__menuMSG}" ${__terminalHeight} ${__terminalWidth} 10.10.77.0/24 --title "Network" 3>&1 1>&2 2>&3) || {
                        echo "*WARNING* Network not set. Exiting..."; return
                    }
                ;;
            esac          
            _setNetIP ${__newNetIP}
        fi
    }

    _setWorkingPUBKey(){
        clear
        echo "******************************************"
        echo "Please enter the public key for the $1:"
        read __workingPUBKey || {
            echo "No key entered. Exiting..."; sleep 5; return
        }
    }

    _setRemoteServer(){
        __menuMSG="PleaseEnter an address for the remote server with the port. eg. \"0.0.0.0:51820\""
        __remoteServer=$(whiptail --inputbox "${__menuMSG}" ${__terminalHeight} ${__terminalWidth} 0.0.0.0:51820 --title "Remote Server" 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Remote server not set. Exiting..."; sleep 5; return
        }
    }
    
    while true
    do
        __menuOption=$(whiptail --title "Wireguard" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "SI" "Install Wireguard SERVER" OFF \
        "SA-User" "Add a user to the server" OFF \
        "SR-User" "Remove a user from the server" OFF \
        "CI" "Install Wireguard CLIENT" OFF \
        "CA-Server" "Add a Server to the client config." OFF \
        "CR-Server" "Remove a Server from the client config." OFF 3>&1 1>&2 2>&3) || {
            echo "Option not selected."
        }
      
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                return;
            fi
        else
            __wgAction=${__menuOption} 
            case ${__menuOption} in
                SI)
                    _setNetwork
                    _pkgInstall
                    wg genkey | sudo tee /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key
                    __srvrPUBKey=$(cat /etc/wireguard/server_public.key)
                    __srvrPRIKey=$(cat /etc/wireguard/server_private.key)   
                    sudo cat > /etc/wireguard/wg0.conf <<EOFWGS
[Interface]
Address = ${__oct1}.${__oct2}.${__oct3}.$__srvrAddress/${__netMask}
SaveConfig = true
PrivateKey = ${__srvrPRIKey}
ListenPort = 51820

#sample
#[Peer]
#PublicKey = CLIENT-PUBLIC-KEY
#AllowedIPs = ${__oct1}.${__oct2}.${__oct3}.0/${__netMask}
#sample

EOFWGS
                    sudo chmod 600 /etc/wireguard/ -R   
                    whiptail --title "*INFO*" --msgbox "Set net.ipv4.ip_forward = 1" 10 ${__terminalWidth}
                    sudo nano /etc/sysctl.conf
                    sudo sysctl -p || {
                        echo "Catch Error"
                    }
                    whiptail --title "*INFO*" --msgbox "Set the default forward policy from \"DROP\" to \"ACCEPT\"\nDEFAULT_FORWARD_POLICY=\"ACCEPT\"" 10 ${__terminalWidth}
                    sudo nano /etc/default/ufw
                    
                    clear; ip addr
                    echo "******************************************"
                    echo "Please enter the interface name. Example: eth0"
                    read __interfaceName || {
                        echo "No key entered. Exiting"; sleep 5; return
                    }

                    echo -e "# NAT table rules" >> /etc/ufw/before.rules
                    echo -e "*nat" >> /etc/ufw/before.rules
                    echo -e ":POSTROUTING ACCEPT [0:0]" >> /etc/ufw/before.rules
                    echo -e "-A POSTROUTING -o ${__interfaceName} -j MASQUERADE" >> /etc/ufw/before.rules
                    echo -e "# End each table with the 'COMMIT' line or these rules won't be processed" >> /etc/ufw/before.rules
                    echo -e "COMMIT" >> /etc/ufw/before.rules

                    sudo ufw enable || {
                        echo "UFW not installed."
                    }         
                    
                    sudo iptables -t nat -L POSTROUTING || {
                        echo "Catch error"
                    }  

                    sudo apt install bind9 -y
                    systemctl start bind9 || {
                        service bind9 start
                    }
                    
                    sed -i "/listen-on-v6/a allow-recursion { 127.0.0.1; ${__network}; };" /etc/bind/named.conf.options
                    systemctl restart bind9 || {
                        service bind9 restart
                    }

                    clear
                    sudo ufw insert 1 allow in from ${__network}
                    sudo ufw allow 51820/udp
                    
                    systemctl restart ufw || {
                        service ufw restart || {
                            echo "UFW not installed."
                        }
                    } 

                    sudo systemctl start wg-quick@wg0 || {
                        service wg-quick@wg0 start
                    }

                    sudo systemctl enable wg-quick@wg0 || {
                        echo "No systemd"
                    }

                    clear;wg
                ;;
                SA-User)
                    _setNetwork
                    __menuMSG="Enter an address for this client. eg. \"10.10.131.7/32\""
                    __targetIP=$(whiptail --inputbox "${__menuMSG}" ${__terminalHeight} ${__terminalWidth} 10.10.131.7/32 --title "Network" 3>&1 1>&2 2>&3) || {
                        echo "*WARNING* Network not set. Exiting..."; return
                    }
                    _setWorkingPUBKey CLIENT
                    wg set wg0 peer ${__workingPUBKey} allowed-ips ${__targetIP}; wg
                ;;
                SR-User)
                    _setWorkingPUBKey CLIENT
                    wg set wg0 peer ${__workingPUBKey} remove; wg
                ;;
                CI)
                    __menuMSG="Enter an address for this client. eg. \"10.10.131.2/24\""
                    __clientIPAddress=$(whiptail --inputbox "${__menuMSG}" ${__terminalHeight} ${__terminalWidth} 10.10.131.2/24 --title "Wireguard Client Address" 3>&1 1>&2 2>&3) || {
                        echo "*WARNING* Client IP not set. Exiting..."; sleep 5; return
                    }
                    _setNetIP ${__clientIPAddress}
                    _pkgInstall
                    wg genkey | sudo tee /etc/wireguard/client_private.key | wg pubkey | sudo tee /etc/wireguard/client_public.key
                    __clientPRIKey=$(cat /etc/wireguard/client_private.key)
                    __workingPUBKey=$(cat /etc/wireguard/client_public.key)
                    clear
                    echo "Client public key: ${__workingPUBKey}"
                    sudo cat > /etc/wireguard/wg-client0.conf <<EOFWGC
[Interface]
Address = ${__network}
SaveConfig = true
DNS = ${__oct1}.${__oct2}.${__oct3}.${__srvrAddress}/${__netMask}
PrivateKey = $__clientPRIKey

#sample
#[Peer]
#PublicKey = REMOTE_SERVER_PUBLIC_KEY
#AllowedIPs = 0.0.0.0/0
#Endpoint = REMOTE_SERVER_ADDRESS
#PersistentKeepalive = 25 
#sample
EOFWGC
                    sudo chmod 600 /etc/wireguard/ -R
                ;;
                CA-Server)
                    _setRemoteServer
                    _setWorkingPUBKey SERVER
                    wg set wg-client0 peer ${__workingPUBKey} endpoint $__remoteServer allowed-ips 0.0.0.0/0 persistent-keepalive 25; wg
                ;;
                CR-Server)
                    _setWorkingPUBKey SERVER
                    wg set wg-client0 peer ${__workingPUBKey} remove; wg
                ;;                
            esac

            _completePrompt "Wireguard ${__wgAction} complete."
            break
        fi
    done

    _logStamp -e _cfgWireguard
}

_setIPVM(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the IP address of a VM using Netplan.
#------------------------------------------------------------------------------------------
    _logStamp -s _setIPVM
    
    if [ ${__isDebug} = 1 ];then
        _exit dbg
        return
    fi
    
    __newIPAddress=""
    __newGateway=""
    __newDNS=""
    __validInput=0
        
    case ${__activeENV} in
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
    
    while true
    do
        __adaptOption=$(whiptail --title "Networking" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "DHCP" "Reset to DHCP" OFF \
        "Set-IP" "Set adapter 1 IP address" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Option not seleced." | _log
        }

        if [ ${#__adaptOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                break;
            fi  
        else
            echo "User selected: ${__adaptOption}" | _log
            if [ "${__adaptOption}" != "DHCP" ];then
                __formMessage="Current IP:$(hostname -I)\nUser selected: ${__adaptOption}\n\nPlease enter the following details:"
                __menuOption=$(dialog --ok-label "Submit" \
                    --backtitle "IP Configuration" \
                    --title "Set VM IP Address" \
                    --form "${__formMessage}" \
                    15 50 0 \
                    "IP: (192.168.1.77/24)" 1 1	"${__newIPAddress}" 	1 23 20 0 \
                    "Gateway: (192.168.1.7)"    2 1	"${__newGateway}"  	2 23 20 0 \
                    "DNS: (1.1.1.1)"    3 1	"${__newDNS}"  	3 23 20 0 \
                3>&1 1>&2 2>&3) || {
                    echo "*WARNING* No user input." | _log; break
                }
                
                if [ ${#__menuOption} -lt 25 ]; then 
                    _exit chkMain
                    if [ "${__exitToMain}" = "true" ]; then 
                        break;
                    fi 
                else
                    __oldIP=$(hostname -I)
                    __ipDATA=${__menuOption}
                    _search -i
                    __newIPAddress=${__data[0]}
                    __newGateway=${__data[2]}
                    __newDNS=${__data[4]}
                    
                    #Confirm the input
                    if (whiptail --title "WARNING!!!: Is this correct?" --yesno "IP: ${__newIPAddress}\nGateway: ${__newGateway}\nDNS: ${__newDNS}" ${__terminalHeight} ${__terminalWidth}); then
                        __validInput=1
                    else
                        break;
                    fi                    
                fi
            fi

            #Apply the settings
            if [ ${__validInput} -eq 1 ] || [ "${__adaptOption}" == "DHCP" ];then
                echo "------------------------------------------------"
                echo "Applying changes..."
                cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml_BCKUP$(date "+%F-%T") || {
                    touch /etc/netplan/50-cloud-init.yaml
                }
                        
                case ${__adaptOption} in
                    "DHCP")
                        cat > /etc/netplan/50-cloud-init.yaml <<EOFIPDEFAULT
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
network:
    ethernets:
        $ad1:
            addresses: [$__newIPAddress]
            dhcp4: false
            gateway4: $__newGateway
            nameservers:
                addresses: [$__newDNS]
            optional: true
    version: 2    
EOFIPVPN
                    ;;
                esac
            
                    netplan --debug generate | _log || {
                    echo "*ERROR* Restoring default config" | _log
                    whiptail --title "*Error*" --msgbox "Invalid input. Default setting will be applied." 8 40
                    
                    cat > /etc/netplan/50-cloud-init.yaml <<EOFIPDEFAULT
network:
    ethernets:
        $ad1:
            dhcp4: true
            optional: true
    version: 2    
EOFIPDEFAULT
        
                netplan --debug generate | _log
                }
                
                netplan apply; sleep 3; 
                
                if [ "${__adaptOption}" != "DHCP" ]; then
                    echo "Old IP: ${__oldIP}" | _log
                    echo "New IP: ${__newIPAddress}" | _log
                    echo "New Gateway: ${__newGateway}" | _log
                    echo "New DNS: ${__newDNS}" | _log

                    whiptail --title "*INFO*" --msgbox "Old IP: ${__oldIP} \
                    New IP: ${__newIPAddress} \
                    New Gateway: ${__newGateway} \
                    New DNS: ${__newDNS}" 10 40
                else
                    whiptail --title "*INFO*" --msgbox "DHCP settings restored." 8 40
                fi
                
                _completePrompt "IP config complete."
                break
            fi
        fi
    done

    _logStamp -e _setIPVM
}

_setIPRegistered(){
#------------------------------------------------------------------------------------------
#   Description -   Sets the IP address of a VM from a hardcoded value.
#------------------------------------------------------------------------------------------
    _logStamp -s _setIPRegistered
    
    if [ $__isDebug = 1 ]; then
        _exit dbg; return
    fi

    while true
    do
        __menuOption=$(whiptail --title "Set IP" --radiolist \
        "Please select one of the following:" $__terminalHeight $__terminalWidth $__terminalLines \
        "PROXY" "Local Nginx proxy." OFF \
        "DB" "Database server." OFF \
        "CLOUD" "Nextcloud" OFF \
        "SMB" "Local SMB" OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* No option selected." | _log
        }

        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "$__exitToMain" = "true" ]; then 
                break;
            fi 
        else
            echo "User selected: ${__menuOption}" | _log
            case $__activeENV in
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

            cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml_BCKUP$(date "+%F-%T") || {
                touch /etc/netplan/50-cloud-init.yaml
            }

            case ${__menuOption} in
                PROXY) __ipAdd="192.168.1.45/24" ;;
                DB) __ipAdd="192.168.1.46/24" ;;
                CLOUD) __ipAdd="192.168.1.47/24" ;; 
                SMB) __ipAdd="192.168.1.48/24" ;;
            esac
            
            __oldIP=$(hostname -I)
            echo "Old IP address: $__oldIP" | _log
            echo "New IP address: $__ipAdd" | _log
            echo "Interface name: $ad1" | _log
            
            cat > /etc/netplan/50-cloud-init.yaml <<EOFSETIP
network:
    ethernets:
        $ad1:
            addresses: [$__ipAdd]
            dhcp4: false
            gateway4: 192.168.1.1
            nameservers:
                addresses: [192.168.1.1]
            optional: true
    version: 2    
EOFSETIP
            netplan --debug generate | _log || {
            echo "*ERROR* Restoring default config" | _log
            whiptail --title "*Error*" --msgbox "Invalid input. Default setting will be applied." 8 40
            
            cat > /etc/netplan/50-cloud-init.yaml <<EOFIPDEFAULT
network:
    ethernets:
        $ad1:
            dhcp4: true
            optional: true
    version: 2    
EOFIPDEFAULT
        
            netplan --debug generate | _log
            }            
            
            netplan apply; sleep 3        
            whiptail --title "*INFO*" --msgbox "Old IP address: $__oldIP\nIP address: $__ipAdd\nInterface name: $ad1" 10 40
            
        fi
    done

    _logStamp -e _setIPRegistered
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

_cfgSSH(){
#------------------------------------------------------------------------------------------
#   Description -   Install SSH server with key access only.
#   Issues/ToDo -   1. FIX port number passing to copy key
#                   2. Create a way to check which port SSH is running on.
#------------------------------------------------------------------------------------------
    _logStamp -s _cfgSSH
    
    if [ ${__isDebug} = 1 ]; then
        _exit dbg; return
    fi

    _copyKeySSH(){
    __sshPortNum=2207
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config_bak$(date "+%F-%T")
    cat > /etc/ssh/sshd_config <<EOFLSSH1VM
#************* ${__activeUser} $(date "+%F-%T") *************
Port ${__sshPortNum}
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem	sftp	/usr/lib/openssh/sftp-server
EOFLSSH1VM
    
    case ${__activeENV} in
        XCP-HV) sudo systemctl restart sshd; sudo system-config-firewall-tui ;;
        *)
            sudo ufw allow ${__sshPortNum} | _log
            sudo ufw enable | _log
            sudo ufw status verbose | _log
            sudo systemctl restart sshd
        ;;
    esac

__menuMSG="Copy your SSH key to this host: $(hostname -I)\n
Port: ${__sshPortNum} \n
IP: $(hostname -I)
ssh-copy-id username@ipAddress -p ${__sshPortNum}\n
To generate a key on your host use: ssh-keygen -b 4096 or\n
ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/id_ed25519 -C \"your@email.com\"\n
Press OK when the key has been coppied."

    whiptail --title "SSH Key Copy" --msgbox --scrolltext "${__menuMSG}" ${__terminalHeight} ${__terminalWidth}
    
    cat > /etc/ssh/sshd_config <<EOFLSSH2VM
#************* ${__activeUser} $(date "+%F-%T") *************
Port ${__sshPortNum}
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
ClientAliveInterval 3600
ClientAliveCountMax 0
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server
EOFLSSH2VM

        sudo systemctl restart sshd
    }

    while true
    do
        __menuOption=$(whiptail --title "SSH" --radiolist \
        "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
        "Install" "Fresh install of SSH server." OFF \
        "GEN" "Generate SSH key on this host." OFF \
        "Add-Key" "Add SSH key to this host." OFF 3>&1 1>&2 2>&3) || {
            echo "*WARNING* Option not selected."
        }
        
        if [ ${#__menuOption} = 0 ]; then 
            _exit chkMain
            if [ "${__exitToMain}" = "true" ]; then 
                break;
            fi 
        else
            echo "User selected: ${__menuOption}" | _log
            
            case ${__menuOption} in
                Install)
                    case ${__activeENV} in
                        XCP-HV) yum install -y openssh-server | _log ;; 
                        *) sudo apt install openssh-server -y | _log ;; 
                    esac
                    
                    if (whiptail --title "SSH Key Copy" --yesno "Would you like to copy a key now?" ${__terminalHeight} ${__terminalWidth}); then
                        _copyKeySSH
                    fi
                ;;
                Add-Key) _copyKeySSH ;;
                GEN) 
                    mkdir -p ${__activeHome}/.ssh; 

                    __menuOption=$(whiptail --title "Generate SSH Key" --radiolist \
                    "Please select one of the following:" ${__terminalHeight} ${__terminalWidth} ${__terminalLines} \
                    "1" "RSA 4096 bit key" OFF \
                    "2" "Ed25519" OFF 3>&1 1>&2 2>&3) || {
                        echo "*WARNING* Menu option not selected." | _log
                    }
                    
                    if [ ${#__menuOption} = 0 ] ; then 
                        echo "Skipping VM Lab specific config." | _log
                    else
                        echo "User selected: ${__menuOption}" | _log
                        sudo apt update
                        case ${__menuOption} in
                            1) ssh-keygen -b 4096  ;;
                            2) ssh-keygen -o -a 100 -t ed25519 -f ${__activeHome}/.ssh/id_ed25519 -C "${__userEmail}";ssh-add ;;
                        esac
                    fi 
                    eval `ssh-agent -s`;ssh-add
                    chown -R ${__activeUser}:${__activeUser} ${__activeHome}/.ssh
                ;;
            esac

            if [ "${__lightSpeed}" == "nope" ];then
                _completePrompt "SSH ${__menuOption} complete."
            fi

            break;
        fi
    done

    _logStamp -e _cfgSSH
}

_cfgNordVPN(){
#------------------------------------------------------------------------------------------
#   Description -   Install NordVPN and create a script thats is used for quick connections.
#------------------------------------------------------------------------------------------
    _logStamp -s _cfgNordVPN

    if [ ${__isDebug} = 1 ]; then
        _exit dbg; return
    fi

    sudo apt update; sudo apt install unzip -y;
    sudo mkdir -p /etc/openvpn
    wget -P ${__tempDirectory}/NordVPN https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb;
    wget -P ${__tempDirectory}/NordVPN https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip;
    sudo unzip ${__tempDirectory}/NordVPN/ovpn.zip -d /etc/openvpn;
    
    dpkg -i ${__tempDirectory}/NordVPN/nordvpn-release_1.0.0_all.deb
    sudo apt update; sudo apt install nordvpn -y | _log

    if (whiptail --title "NordVPN Login" --yesno "Would you like to login now?" ${__terminalHeight} ${__terminalWidth}); then
        clear; echo "-Login-"; sudo nordvpn login || {
            echo "*WARNING*  Login failed."
        }
    fi
    
    _writeScript -n
    
    if [ "${__lightSpeed}" == "nope" ];then
        _completePrompt "Nord installed."
    fi
    
    _logStamp -e _cfgNordVPN
}

_writeScript(){
#------------------------------------------------------------------------------------------
#   Description -   Create a specific bash alias or script.
#------------------------------------------------------------------------------------------
    _logStamp -s _writeScript
    
    __userScripts=${__activeHome}/userScripts; mkdir -p ${__userScripts}
    chown -R ${__activeUser}:${__activeUser} ${__userScripts}

    local __swithcVal
    local OPTIND
    local OPTARG

    __aliasForUpdate="uu"
    __aliasForNordConnect="nv-c"
    __aliasForNordDisconnect="nv-d"
    __aliasForNordStatus="nv-s"
    
    while getopts nu __swithcVal
    do
        case ${__swithcVal} in
            n)
                cat > ${__userScripts}/nord.sh << EOFNORD
#!/bin/bash
#-------- Script Variables ----------
    __terminalHeight=\$(tput lines)
    __terminalWidth=\$(tput cols)
    __terminalLines=10
    __funcMenuLoopCTL=0
#------------------------------------

#---------- Quick Connect/Disconnect -----------
    case \$1 in
        -c) nordvpn connect ca991; nordvpn status; exit 0 ;;
        -cc) nordvpn connect \$2; nordvpn status; exit 0 ;;
        -u) nordvpn connect us2931; nordvpn status; exit 0 ;;
        -se) nordvpn connect se384; nordvpn status; exit 0 ;;
        -uk) nordvpn connect uk814; nordvpn status; exit 0 ;;
        -d) nordvpn disconnect; nordvpn status; exit 0 ;;
        -s) nordvpn status; exit 0 ;;
    esac
#------------------------------------

#----------- Main Menu --------------
    while true
    do
        __menuOption=\$(whiptail --title "NordVPN Menu" --radiolist \\
        "Please select one of the following:" \$__terminalHeight \$__terminalWidth \$__terminalLines \\
        "LI" "Login or switch accounts" OFF \\
        "LO" "Logout" OFF \\
        "CA" "Connect to Canada" OFF \\
        "US" "Connect to United States" OFF \\
        "SE" "Connect to Sweeden" OFF \\
        "UK" "Connect to United Kingdom" OFF \\
        "DIS" "Disconnect an active connection" OFF 3>&1 1>&2 2>&3)
        menuExitStatus=\$?

        if [ \${#__menuOption} = 0 ] || [ \$menuExitStatus != 0 ]; then #If an option was not selected or the user chose cancel.
            if !(whiptail --title "Warning" --yesno "No option selected. Try again?" 8 78); then
                return
            fi
        else
            clear
            case \${__menuOption} in
                LI) nordvpn logout;nordvpn login ;;
                LO) nordvpn logout ;;
                CA) nordvpn connect ca928 ;;
                US) nordvpn connect us5009 ;;
                SE) nordvpn connect se384 ;;
                UK) nordvpn connect uk814 ;;
                DIS) nordvpn disconnect;;
            esac
            return
        fi
        
    nordvpn status;
    echo "*** Arrivederci! ***"
EOFNORD
                __aliasSet=$(grep -c ${__aliasForNordConnect} ${__activeHome}/.bashrc ) || {
                    echo "*WARNING* Alias not found."
                }

                if [ "${__aliasSet}" == "0" ]; then
                    echo -e "alias ${__aliasForNordConnect}='sudo bash ${__userScripts}/nord.sh -c'" >> ${__activeHome}/.bashrc
                    echo -e "alias ${__aliasForNordDisconnect}='sudo bash ${__userScripts}/nord.sh -d'" >> $__activeHome/.bashrc
                    echo -e "alias ${__aliasForNordStatus}='sudo bash ${__userScripts}/nord.sh -s'" >> ${__activeHome}/.bashrc
                    echo "Script nord.sh added to ${__userScripts}/" | _log
                fi
            ;;
            u)
                cat > ${__userScripts}/update.sh << EOFUPSH
#!/bin/bash
apt update;apt upgrade -y; apt autoremove -y; apt clean;
EOFUPSH
                __aliasSet=$(grep -c ${__aliasForUpdate} ${__activeHome}/.bashrc ) || {
                    echo "*WARNING* Alias not found."
                }
                
                if [ "${__aliasSet}" == "0" ]; then
                    echo -e "alias ${__aliasForUpdate}='sudo bash ${__userScripts}/update.sh'" >> ${__activeHome}/.bashrc
                    echo -e "alias byee='sudo bash ${__userScripts}/update.sh; shutdown -h now'" >> ${__activeHome}/.bashrc
                    echo "Script update.sh added to ${__userScripts}/" | _log
                fi
            ;;
            *) echo "[CHECK SYNTAX!!!!!!!!] for _writeScript" ; exit 1 ;;   
        esac

        chown -R ${__activeUser}:${__activeUser} ${__userScripts}
    done
    
    _logStamp -e _writeScript
}

_quickConfig(){
    apt update | _log
    apt install net-tools -y | _log
    apt install dnsutils -y | _log
    apt install vim -y | _log
    apt install nano -y | _log
    apt install git -y | _log
    apt install tmux -y | _log
    apt install screenfetch -y | _log
    apt install openssh-server -y | _log
    apt install nginx -y
    echo "--- Pkgs installed ---"
}
#==============================================================================================================================================================
# GENERAL FUNCTIONS -END-
#==============================================================================================================================================================

# - - - - - - - - - - - - - - - - -
_scriptSwitches $*
_main
# - - - - - - - - - - - - - - - - -