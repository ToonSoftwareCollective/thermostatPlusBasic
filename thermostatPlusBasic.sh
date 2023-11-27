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
    # My Toon 1 has many apps installed and is slow during startup, especially after a reboot
    # I think this caused an 'out of resources' in update-rooted.sh -o 
    # during the update of iptables resulting in a hang of the update-rooted.sh script
    # This is why I introduced a wait of 5 minutes to avoid this after the reboot.
    # (I did not have this issue on Toon 2 or after a killall qt-gui)
    echo "---------------------------"
    date
    echo " Wait 5 minutes to let startup finish things"
    sleep 300
    date
    echo " Try to install websockets"
# make sure we have the latest update-rooted.sh
    cd /root
    echo " ----- Get / update update-rooted.sh"
    curl --compressed -Nks https://raw.githubusercontent.com/ToonSoftwareCollective/update-rooted/main/update-rooted.sh -o update-rooted.sh
    echo " ----- Open VPN"
# make sure that in case the update-rooted.sh hangs for some reason we at least kill the vpn within 15 minutes
    (sleep 900 ; killall openvpn) &
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
    # started will be 0 when the vpn is started.
    if [ $started -eq 0 ]
    then
        echo " ----- Update Package List"
# the next command seems to need something extra on Toon 2 (privileges ?) and I need to use su -c to execute the command
#        opkg update
        su -c 'opkg update'
        nr_errors=$(grep -e 'Signature check failed' $log | wc -l)
        echo "Status opkg update : $nr_errors"
        if [ $nr_errors -eq 0 ]
        then
            echo " ----- Install / Update websocket libraries"
# the next command seems to need something extra on Toon 2 (privileges ?) and I need to use su -c to execute the command
#            opkg install libqt5websockets5
            su -c 'opkg install libqt5websockets5'
            nr_errors=$(grep -e 'Cannot install package libqt5websockets5' $log | wc -l)
            echo "Status opkg install libqt5websockets5 : $nr_errors"
            if [ $nr_errors -eq 0 ]
            then
                echo "Successfully installed / updated websockets."
                sync
                sync
                sleep 5
                killall qt-gui
            else
                echo "Failed to install websockets."
                /qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Verwijderd de meldingen. Binnenkort wordt het updaten opnieuw geprobeerd." >/dev/null 2>&1
            fi
        else
            echo "Failed to update opkg packages list."
            /qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Verwijderd de meldingen. Binnenkort wordt het updaten opnieuw geprobeerd." >/dev/null 2>&1
        fi
        killall openvpn
    else
        echo "Failed to open vpn so websockets are not installed."
        /qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Verwijderd de meldingen. Binnenkort wordt het updaten opnieuw geprobeerd." >/dev/null 2>&1
    fi
    echo "---------------------------"
}

do_it > $log 2>&1
