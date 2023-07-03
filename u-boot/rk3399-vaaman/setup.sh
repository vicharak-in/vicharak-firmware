#!/usr/bin/env bash

maskrom() {
	rkdeveloptool db "$SCRIPT_DIR/rkboot.bin"
}

maskrom_update_bootloader() {
	rkdeveloptool wl 64 "$SCRIPT_DIR/idbloader.img"
	if [[ -f "$SCRIPT_DIR/u-boot.itb" ]]; then
		rkdeveloptool wl 16384 "$SCRIPT_DIR/u-boot.itb"
	elif [[ -f "$SCRIPT_DIR/uboot.img" ]] && [[ -f "$SCRIPT_DIR/trust.img" ]]; then
		rkdeveloptool wl 16384 "$SCRIPT_DIR/uboot.img"
		rkdeveloptool wl 24576 "$SCRIPT_DIR/trust.img"
	else
		echo "Missing U-Boot binary!" >&2
		return 2
	fi
}

maskrom_dump() {
	local OUTPUT=${1:-dump.img}

	echo "eMMC dump will continue indefinitely."
	echo "Please manually interrupt the process (Ctrl+C)"
	echo "  once the image size is larger than your eMMC size."
	echo "Writting to $OUTPUT..."
	rkdeveloptool rl 0 -1 "$OUTPUT"
}

get_part_by_name() {
	part=$(parted -s "$DEVICE" print | grep "$1" | awk '{print $1}')

	if [[ -z "$part" ]]; then
		echo "Partition $1 not found!" 2>&1 | tee -a /tmp/rockchip_flash.log
		return 99
	fi

	# return part number
	echo "$part"
}

update_bootloader() {
	local DEVICE=$1

	if [ -f "$SCRIPT_DIR/idbloader.img" ]; then
		echo "Writing idbloader to $DEVICE..." 2>&1 | tee -a /tmp/rockchip_flash.log
		dd if="$SCRIPT_DIR/idbloader.img" of="${DEVICE}" seek=64
	elif [ -f "$SCRIPT_DIR/idblock.bin" ]; then
		echo "Writing idblock to $DEVICE..." 2>&1 | tee -a /tmp/rockchip_flash.log
		dd if="$SCRIPT_DIR/idblock.bin" of="${DEVICE}" seek=64
	else
		echo "Missing idbloader binary!" 2>&1 | tee -a /tmp/rockchip_flash.log
	fi

	if [[ -f "$SCRIPT_DIR/uboot.img" ]] && [[ -f "$SCRIPT_DIR/trust.img" ]]; then
		uboot_part=$(get_part_by_name uboot)
		trust_part=$(get_part_by_name trust)

		echo "Writing to partitions $uboot_part and $trust_part..." 2>&1 | tee -a /tmp/rockchip_flash.log

		if [[ "$uboot_part" == 99 ]] || [[ "$trust_part" == 99 ]]; then
			echo "Writing to raw device..." 2>&1 | tee -a /tmp/rockchip_flash.log

			dd conv=notrunc,fsync if="$SCRIPT_DIR/uboot.img" of="${DEVICE}" seek=16384
			dd conv=notrunc,fsync if="$SCRIPT_DIR/trust.img" of="${DEVICE}" seek=24576
		else
			echo "Writing to partitions $uboot_part and $trust_part..." 2>&1 | tee -a /tmp/rockchip_flash.log

			dd if="$SCRIPT_DIR/uboot.img" of="${DEVICE}${uboot_part}"
			dd if="$SCRIPT_DIR/trust.img" of="${DEVICE}${trust_part}"
		fi
	elif [[ -f "$SCRIPT_DIR/u-boot.itb" ]]; then
		dd conv=notrunc,fsync if="$SCRIPT_DIR/u-boot.itb" of="${DEVICE}" bs=512 seek=16384
	else
		echo "Missing U-Boot binary!" 2>&1 | tee -a /tmp/rockchip_flash.log
		return 2
	fi
	sync
}

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

ACTION="$1"
shift

if [[ $(type -t "$ACTION") == function ]]; then
	$ACTION "$@"
else
	echo "Unsupported action: '$ACTION'" >&2
	exit 1
fi
