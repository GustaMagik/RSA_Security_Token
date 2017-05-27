#!/bin/bash

# this script is not really tested
sudo ls /dev/tty*
echo "*I" | sudo tee -a /dev/ttyACM0 &
sudo tail -f /dev/ttyXRUSB0

