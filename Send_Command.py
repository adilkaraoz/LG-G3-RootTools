#!/usr/bin/python
#
# LG Download Mode Console
#
# This tool was reverse engineered from Korean developer Only's Send_Command tool
# The code is poor quality with unfinished parts.  It works, barely.  If you make improvements
# please let me know.
#
# dev@jacobstoner.com
#

import subprocess
import serial
import time
import binascii
import sys
import os

def call(cmd,hide_stderr=True):
	return subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE).stdout.read().strip().split("\n")

#make sure we are root
if not call('whoami')[0] == 'root':
	print "run as root"
	sys.exit()
	
#validate port
if not 'ttyUSB' in sys.argv[-1] or not os.path.exists(sys.argv[-1]):
	print '''Usage: python qcdlcomm.py /dev/ttyUSB1
	
Before using this utility you must unload the cdc_acm module and reload the 
usbserial module with your device id:
rmmod cdc_acm
rmmod usbserial
modprobe usbserial vendor=0x1004 product=0x633e

Adjust the product id to match your phone.  You can find it with lsusb.
If usbserial fails to unload, then you must first unload any other modules that 
are using it.

Check the tty devices:
ls /dev/ttyUSB*
Multiple tty devices may be loaded, try the highest numbered one first.'''
	sys.exit()

ser = serial.Serial(
	port=sys.argv[-1],
	baudrate=115200,
	parity=serial.PARITY_NONE,
	stopbits=serial.STOPBITS_ONE,
	bytesize=serial.EIGHTBITS
)

commands = {
	'ENTER' : ':\xa1n~',
	'LEAVE' : 'CTRLRSET\x00\x00\x00\x00\xc7\xeb\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xbc\xab\xad\xb3'
}

def rawcmd(input):
	ser.write(input)
	out = ''
	response = False
	while ser.inWaiting() > 0 or response is False:
		response = True
		out += ser.read(1)
	return out
	
def prefix(input):
	prefix = 'EXEC'+'\x00'*16
	length = binascii.a2b_hex('{0:0{1}x}'.format(len(input)+1,2))
	while len(length) < 4:
		length += '\x00'
	prefix += length
	if input == 'echo':
		crc = '\x13\xdd'
	else:
		crc = '\x5d\x35'
	prefix += crc #I believe this is a crc16, but I can't figure it out so it's hardcoded incorrectly; please help me fix this
	prefix += '\x00\x00\xba\xa7\xba\xbc'
	return prefix
	
def cmd(input):
	if input in commands:
		rawcmd(commands[input])
	else:
		rawcmd(prefix('echo')+'echo'+'\x00\x00') #workaround for incorrect CRC; don't know why this works
		output = rawcmd(prefix(input)+input+'\x00\x00') #that last 0x00 bit should probably be a checksum
		if output:
			print output.split('\xba\xa7\xba\xbc')[1][:-1]
		
print "Special commands: "+", ".join(sorted(commands))+", exit"
while(True):
	input = raw_input("# ").strip()
	if input == 'exit':
		break
	else:
		cmd(input)
ser.close()