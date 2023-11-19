#!/bin/sh
#
#   File    : ThermostatPlusBasic.sh
#   Purpose : Install websocket libraries so ThermostatPlusBasic
#               can be replaced by ThermostatPlus which uses
#               websockets to communicate between web page and app.
#   Usage   : Use/simulate : echo external-thermostatPlusBasic>/tmp/tsc.command
#               and tsc will take care of execution.
#
log=/qmf/qml/apps/thermostatPlusBasic/thermostatPlusBasic.log
# make sure we have a sane environment
. /etc/profile
# function which is called at the end of this script
do_it () {
    echo "---------------------------"
    date
    echo " Try to install websockets"
# make sure we have the latest update-rooted.sh
    cd /root
    echo " ----- Get / update update-rooted.sh"
    wget https://github.com/ToonSoftwareCollective/update-rooted/blob/main/update-rooted.sh
    echo " ----- Open VPN"
# try to open vpn
    attempts=0
    # started will be 0 when the vpn is started.
    started=1
    while [ $attempts -lt 5 ] && [ $started -ne 0 ]
    do
        attempts=$((attempts+1))
        sh ./update-rooted.sh -o -u
        sleep 5
        grep -e 'If you are done with manual package downloading, just reboot and the VPN should be closed again.'  $log >/dev/null 2>&1
        started=$?
        # started will be 0 when the vpn is started.
    done
    if [ $attempts -gt 1 ]
    then
        /qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Negeer de melding(en) dat er iets mis ging." >/dev/null 2>&1
    fi
# when vpn is open, update package list, install/update websockets, check number of libraries and reboot
    # started will be 0 when the vpn is started.
    if [ $started -eq 0 ]
    then
        echo " ----- Update Package List"
        opkg update
        sleep 5
        echo " ----- Install / Update websocket libraries"
        opkg install libqt5websockets5
        sleep 5
        echo " ----- Check number of websocket libraries"
        nr_libs=$(opkg list-installed | grep libqt5web | wc -l)
        if [ $nr_libs -eq 3 ]
        then
            echo "Successfully installed / updated websockets."
        else
            echo "Failed to install websockets."
            /qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Verwijderd de meldingen. Binnenkort wordt het updaten opnieuw geprobeerd." >/dev/null 2>&1
        fi
        # make sure everything is saved before we reboot.
        sync
        sync
        sleep 5
        init 6
    else
        echo "Failed to open vpn so websockets are not installed."
        /qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Verwijderd de meldingen. Binnenkort wordt het updaten opnieuw geprobeerd." >/dev/null 2>&1
    fi
    echo "---------------------------"
}

do_it > $log
