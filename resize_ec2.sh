#!/bin/bash

START=`fdisk -u -l /dev/xvda |tail -n 1|awk '{print $3}'`
echo "Start is $START"

expect <<- DONE
	spawn fdisk -u /dev/xvda
	expect "*m for help):"
	send "d\r"
	expect "*m for help):"
	send "n\r"
	send "p\r"
	expect "*(1-4):"
	send "1\r"
	expect "*default*"
	send "$START\r"
	expect "*default*"
	send "\r"
	expect "*m for help):"
	send "a\r"
	expect "*(1-4):"
	send "1\r"
	expect "*m for help):"
	send "w\r"
DONE

reboot


