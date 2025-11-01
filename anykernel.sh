### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## cyberknight777 @ xda-developers
## Modified by dopaemon (DoraCore GKI build) — fixed vendor_dlkm repack logic and space detection

### AnyKernel setup
# global properties
properties() { '
kernel.string=DoraCore GKI 5.10 by dopaemon
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=mayfly
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;
NO_MAGISK_CHECK=true;
AK3_DEBUG=1;
# import functions/variables and setup patching - do not remove
. tools/ak3-core.sh;

$BOOTMODE || umount /vendor_dlkm
export magisk_patched
$BOOTMODE || setenforce 0

# boot install
split_boot
flash_boot

# vendor_boot shell variables
BLOCK=vendor_boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# reset for vendor_boot patching
reset_ak;

# vendor_boot install
split_boot


# ---------- Helper functions ----------

get_size() {
	local _path=$1
	local _size
	if [ -d "$_path" ]; then
		du -bs "$_path" | awk '{print $1}'
		return
	fi
	if [ -b "$_path" ]; then
		_size=$(blockdev --getsize64 "$_path" 2>/dev/null) && {
			echo "$_size"
			return
		}
	fi
	wc -c < "$_path"
}

bytes_to_mb() {
	echo "$1" | awk '{printf "%.1fM", $1 / 1024 / 1024}'
}

# ---------- vendor_boot content update ----------
if [ -f $AKHOME/modules/dlkm.cpio.lz4 ]; then
	ui_print " "
	ui_print "- [V] LZ4 CPIO archive found. Starting vendor_ramdisk modules update..."
	ui_print "- [•] Decompressing the archive..."
	magiskboot decompress $AKHOME/modules/dlkm.cpio.lz4 $AKHOME/dlkm.cpio || abort "[X] Failed to decompress LZ4 archive"
	ui_print "- [•] Updating vendor_ramdisk modules..."
	mv $AKHOME/dlkm.cpio $SPLITIMG/vendor_ramdisk/dlkm.cpio || abort "[X] Updating vendor_ramdisk modules failed"
fi

if [ -f $AKHOME/config/modules.load.recovery ]; then
	ui_print " "
	ui_print "- [V] Recovery modules.load found. Updating ramdisk..."
	magiskboot cpio $SPLITIMG/vendor_ramdisk/ramdisk.cpio "add 0644 lib/modules/modules.load.recovery $AKHOME/config/modules.load.recovery" || abort "[X] Updating ramdisk.cpio failed"
fi

ui_print "- [V] Flashing new vendor_boot image..."
flash_boot


# ---------- vendor_dlkm update ----------
if [ -f $AKHOME/modules/dlkm.tar.xz ]; then
	reset_ak;

	ui_print " "
	ui_print "/dev/block/mapper/vendor_dlkm${SLOT}"
	ui_print " " "- [V] Starting /vendor_dlkm update..."

	ui_print "- [•] Pulling /vendor_dlkm from current slot (${SLOT})..."
	dd if=/dev/block/mapper/vendor_dlkm${SLOT} of=${AKHOME}/vendor_dlkm.img &>/dev/null || \
		abort "[X] Failed to pull vendor_dlkm${SLOT}.img"

	extract_vendor_dlkm_dir=${AKHOME}/_extract_vendor_dlkm
	mkdir -p "$extract_vendor_dlkm_dir" || abort "[X] Failed to create $extract_vendor_dlkm_dir"

	ui_print "- [•] Mount /vendor_dlkm image (ro)..."
	mount ${AKHOME}/vendor_dlkm.img ${extract_vendor_dlkm_dir} -o ro -t ext4 &>/dev/null || \
		abort "[X] Failed to mount vendor_dlkm image (ro)"
	sync

	ui_print "- [•] Preparing new modules..."
	mkdir -p ${AKHOME}/vdlkm
	extract_vendor_dlkm_modules_dir=${extract_vendor_dlkm_dir}/lib/modules
	vendor_dlkm_stock_modules_size=$(get_size ${extract_vendor_dlkm_modules_dir})

	busybox tar -xpf ${AKHOME}/modules/dlkm.tar.xz -C ${AKHOME}/vdlkm || \
		abort "[X] Failed to extract dlkm.tar.xz"

	# --- robust space calculation (no df) ---
	loop_dev=$(mount | awk -v mp="$extract_vendor_dlkm_dir" '$0 ~ mp {print $1; exit}')
	[ -z "$loop_dev" ] && loop_dev=$(mount | grep "$extract_vendor_dlkm_dir" | awk '{print $1; exit}')

	vendor_dlkm_full_space=0
	vendor_dlkm_used_space=0
	vendor_dlkm_free_space=0

	# full: blockdev or .img
	if [ -b "$loop_dev" ] && command -v blockdev >/dev/null 2>&1; then
		vendor_dlkm_full_space=$(blockdev --getsize64 "$loop_dev" 2>/dev/null || echo 0)
	fi
	if [ "$vendor_dlkm_full_space" -eq 0 ] && [ -f "${AKHOME}/vendor_dlkm.img" ]; then
		vendor_dlkm_full_space=$(get_size "${AKHOME}/vendor_dlkm.img")
	fi

	# used: du
	vendor_dlkm_used_space=$(du -sk "$extract_vendor_dlkm_dir" 2>/dev/null | awk '{print $1 * 1024}' || echo 0)

	# free = full - used
	if [ "$vendor_dlkm_full_space" -gt "$vendor_dlkm_used_space" ]; then
		vendor_dlkm_free_space=$((vendor_dlkm_full_space - vendor_dlkm_used_space))
	else
		vendor_dlkm_free_space=0
	fi
	# ----------------------------------------

	ui_print "- vendor/dlkm space info:"
	ui_print "  - total: $(bytes_to_mb $vendor_dlkm_full_space)"
	ui_print "  - used:  $(bytes_to_mb $vendor_dlkm_used_space)"
	ui_print "  - free:  $(bytes_to_mb $vendor_dlkm_free_space)"
	ui_print "  raw bytes => total=$vendor_dlkm_full_space used=$vendor_dlkm_used_space free=$vendor_dlkm_free_space"

	umount $extract_vendor_dlkm_dir

	vendor_dlkm_new_modules_size=$(get_size ${AKHOME}/vdlkm)
	vendor_dlkm_need_size=$((vendor_dlkm_used_space - vendor_dlkm_stock_modules_size + vendor_dlkm_new_modules_size + 10*1024*1024))

	if [ "$vendor_dlkm_need_size" -ge "$vendor_dlkm_full_space" ]; then
		${bin}/e2fsck -f -y ${AKHOME}/vendor_dlkm.img
		vendor_dlkm_resized_size=$(echo $vendor_dlkm_need_size | awk '{printf "%dM", ($1 / 1024 / 1024 + 1)}')
		${bin}/resize2fs ${AKHOME}/vendor_dlkm.img $vendor_dlkm_resized_size || \
			abort "! Can't resize vendor_dlkm image"
		ui_print "- Resized vendor_dlkm to: ${vendor_dlkm_resized_size}"
		${bin}/e2fsck -f -y ${AKHOME}/vendor_dlkm.img
		unset vendor_dlkm_resized_size
	else
		ui_print "- Not need to resize vendor_dlkm"
	fi

	mount ${AKHOME}/vendor_dlkm.img ${extract_vendor_dlkm_dir} -o rw -t ext4 &>/dev/null || \
		abort "[X] Failed to mount vendor_dlkm image (rw)"
	sync

	ui_print "- [•] Removing old vendor_dlkm modules..."
	rm -rf ${extract_vendor_dlkm_modules_dir}/* || abort "[X] Failed to remove old modules"

	ui_print "- [•] Copying new kernel modules..."
	cp -r ${AKHOME}/vdlkm/* ${extract_vendor_dlkm_modules_dir}/
	set_perm 0 0 0644 ${extract_vendor_dlkm_modules_dir}/*
	[ -x "$(command -v chcon)" ] && chcon u:object_r:vendor_file:s0 ${extract_vendor_dlkm_modules_dir}/* || true

	ui_print "- [•] Unmount vendor_dlkm..."
	umount ${extract_vendor_dlkm_dir}
	unset extract_vendor_dlkm_dir extract_vendor_dlkm_modules_dir

	ui_print "- [V] Flashing new vendor_dlkm image..."
	flash_generic vendor_dlkm
fi
