#x750 Powering on /reboot /full shutdown through hardware
#!/bin/bash

    sudo sed -e '/shutdown/ s/^#*/#/' -i /etc/rc.local

    echo '#!/bin/bash

SHUTDOWN=4
REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600
echo "$SHUTDOWN" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio$SHUTDOWN/direction
BOOT=17
echo "$BOOT" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio$BOOT/direction
echo "1" > /sys/class/gpio/gpio$BOOT/value

echo "X750 Shutting down..."

while [ 1 ]; do
  shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
  if [ $shutdownSignal = 0 ]; then
    /bin/sleep 0.2
  else  
    pulseStart=$(date +%s%N | cut -b1-13)
    while [ $shutdownSignal = 1 ]; do
      /bin/sleep 0.02
      if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMAXIMUM ]; then
        echo "X750 Shutting down", SHUTDOWN, ", halting Rpi ..."
        sudo poweroff
        exit
      fi
      shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
    done
    if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMINIMUM ]; then 
      echo "X750 Rebooting", SHUTDOWN, ", recycling Rpi ..."
      sudo reboot
      exit
    fi
  fi
done' > /etc/x750pwr.sh
sudo chmod +x /etc/x750pwr.sh
sudo sed -i '$ i /etc/x750pwr.sh &' /etc/rc.local 


#X750 full shutdown through Software
#!/bin/bash

    sudo sed -e '/button/ s/^#*/#/' -i /etc/rc.local

    echo '#!/bin/bash

BUTTON=18

echo "$BUTTON" > /sys/class/gpio/export;
echo "out" > /sys/class/gpio/gpio$BUTTON/direction
echo "1" > /sys/class/gpio/gpio$BUTTON/value

SLEEP=${1:-4}

re='^[0-9\.]+$'
if ! [[ $SLEEP =~ $re ]] ; then
   echo "error: sleep time not a number" >&2; exit 1
fi

echo "X750 Shutting down..."
/bin/sleep $SLEEP

#restore GPIO 18
echo "0" > /sys/class/gpio/gpio$BUTTON/value
' > /usr/local/bin/x750shutdown.sh
sudo chmod +x /usr/local/bin/x750shutdown.sh

#X750 Battery voltage & precentage reading
#!/bin/bash

    sudo sed -e '/shutdown/ s/^#*/#/' -i /etc/rc.local

    echo '#!/usr/bin/env python
import struct
import smbus
import sys
import time
import os
import subprocess

def readVoltage(bus):
    address = 0x36
    read = bus.read_word_data(address, 2)
    swapped = struct.unpack("<H", struct.pack(">H", read))[0]
    voltage = swapped * 1.25 /1000/16
    return voltage

def readCapacity(bus):
    address = 0x36
    read = bus.read_word_data(address, 4)
    swapped = struct.unpack("<H", struct.pack(">H", read))[0]
    capacity = swapped/256
    return capacity
	
def powerLog(logFile):
	logInfo = time.strftime("%Y%m%j_%H%M%S",time.localtime()) + ",{:.2f}".format(tempVoltage) + ",{:.1f}\n".format(tempCapacity)
	logFile.write(logInfo)

bus = smbus.SMBus(1) # 0 = /dev/i2c-0 (port I2C0), 1 = /dev/i2c-1 (port I2C1)

try:
    #start_time variable
    start_time = time.time()
	
	#parse command line arguments
    logArgument = True
	
    currentStatus = ""
    dateString = time.strftime("X750Log_%Y%m%j_%H%M%S.csv", time.localtime())
	logFile = open(dateString,'w')

    previousVoltage = readVoltage(bus)
    previousCapacity = readCapacity(bus)
    
    logFile.write("Date_Time,Voltage,Capacity/n")

    while True:
        print ("******************")
        tempVoltage  = readVoltage(bus)
        tempCapacity = readCapacity(bus)
        
        if(tempCapacity > previousCapacity):
            currentStatus = "Charging"
        elif(tempCapacity < previousCapacity):
            currentStatus = "Discharging"
        
        print (currentStatus)
        print ('Voltage:%5.2f V' % tempVoltage)
        print ("Battery: {:.1f} %".format(tempCapacity))
        
		if(logArgument == True)
			powerLog(logFile)

        if readCapacity(bus) >= 100:
            print ("Battery FULL")

        if readCapacity(bus) < 20:
            print ("Battery LOW")
        
        print ("******************")
		
        previousVoltage  = tempVoltage
        previousCapacity = tempCapacity
        time.sleep(2)
        os.system('clear')
        
except KeyboardInterrupt:
    #output starting voltage & battery percentage
    #output ending voltage & battery percentage
    
    end_time = time.time()
    
    #output runtime (end_time - start_time)
    print ('\nRuntime = %5.2fs' % (end_time - start_time))
' > /home/pi/x750ups.py
sudo chmod +x /home/pi/x750ups.py

