# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=   Quantic Kernel installer v2.0 by Ayrton990@XDA
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=cepheus
device.name2=cepheus-user
device.name3=Mi 9
device.name4=Xiaomi
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;


## AnyKernel install
dump_boot;

# begin ramdisk changes

# end ramdisk changes

ui_print "-> Disabling FOD dim layer";
QuanticMagisk=/data/adb/modules/Quantic
# Place Quantic options
rm -rf $QuanticMagisk
mkdir -p $QuanticMagisk
cp -Rf /tmp/anykernel/common/* $QuanticMagisk
chmod 755 $QuanticMagisk/system.prop

write_boot;
## end install

ui_print " ";
ui_print " ";
ui_print "   Quantic has been succesfully installed!";
ui_print "   If you have any bug please report to";
ui_print "   @Ayrton990 on telegram";
ui_print " ";
ui_print "   Follow @QuanticKernel for support, @ayrton990mods on Telegram ";
ui_print " ";
ui_print " ";

