#!/bin/bash

detect_platform() {
	if grep -q "Raspberry Pi Compute Module 5" /proc/cpuinfo 2>/dev/null; then
		echo "cm5"
	elif grep -q "Radxa Zero 3" /proc/device-tree/model 2>/dev/null; then
		echo "radxa-zero3"
	elif grep -q "ArmSom-CM5" /proc/device-tree/model 2>/dev/null; then
		echo "armsom-cm5"
	else
		echo "unknown"
	fi
}

detect_platform
