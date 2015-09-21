#!/sbin/sh
OUTFD=$2
ZIP=$3
BUSYBOX=$4
chmod 755 $BUSYBOX
mkdir /tmp


SYSTEMLIB=/system/lib

ui_print() {
  echo -n -e "ui_print $1\n" > /proc/self/fd/$OUTFD
}

ch_con() {
  LD_LIBRARY_PATH=$SYSTEMLIB /system/toolbox chcon -h u:object_r:system_file:s0 $1
  LD_LIBRARY_PATH=$SYSTEMLIB /system/bin/toolbox chcon -h u:object_r:system_file:s0 $1
  chcon -h u:object_r:system_file:s0 $1
  LD_LIBRARY_PATH=$SYSTEMLIB /system/toolbox chcon u:object_r:system_file:s0 $1
  LD_LIBRARY_PATH=$SYSTEMLIB /system/bin/toolbox chcon u:object_r:system_file:s0 $1
  chcon u:object_r:system_file:s0 $1
}

ch_con_ext() {
  LD_LIBRARY_PATH=$SYSTEMLIB /system/toolbox chcon $2 $1
  LD_LIBRARY_PATH=$SYSTEMLIB /system/bin/toolbox chcon $2 $1
  chcon $2 $1
}

ln_con() {
  LD_LIBRARY_PATH=$SYSTEMLIB /system/toolbox ln -s $1 $2
  LD_LIBRARY_PATH=$SYSTEMLIB /system/bin/toolbox ln -s $1 $2
  ln -s $1 $2
  ch_con $2
}

set_perm() {
  chown $1.$2 $4
  chown $1:$2 $4
  chmod $3 $4
  ch_con $4
  ch_con_ext $4 $5
}

cp_perm() {
  rm $5
  if [ -f "$4" ]; then
    cat $4 > $5
    set_perm $1 $2 $3 $5 $6
  fi
}

ui_print "*****************"
ui_print "SuperSU installer"
ui_print "*****************"

ui_print "- Mounting /system, /data and rootfs"
mount /system
mount /data
mount -o rw,remount /system
mount -o rw,remount /system /system
mount -o rw,remount /
mount -o rw,remount / /

cat /system/bin/toolbox > /system/toolbox
chmod 0755 /system/toolbox
ch_con /system/toolbox

API=$(cat /system/build.prop | grep "ro.build.version.sdk=" | dd bs=1 skip=21 count=2)
ABI=$(cat /system/build.prop /default.prop | grep -m 1 "ro.product.cpu.abi=" | dd bs=1 skip=19 count=3)
ABILONG=$(cat /system/build.prop /default.prop | grep -m 1 "ro.product.cpu.abi=" | dd bs=1 skip=19)
ABI2=$(cat /system/build.prop /default.prop | grep -m 1 "ro.product.cpu.abi2=" | dd bs=1 skip=20 count=3)
SUMOD=06755
SUGOTE=false
SUPOLICY=false
INSTALL_RECOVERY_CONTEXT=u:object_r:system_file:s0
MKSH=/system/bin/mksh
PIE=
ARCH=arm
APKFOLDER=false
APKNAME=/system/app/Superuser.apk
APPPROCESS=false
APPPROCESS64=false
if [ "$ABI" = "x86" ]; then ARCH=x86; fi;
if [ "$ABI2" = "x86" ]; then ARCH=x86; fi;
if [ "$API" -eq "$API" ]; then
  if [ "$API" -ge "17" ]; then
    SUGOTE=true
    PIE=.pie
    if [ "$ABILONG" = "armeabi-v7a" ]; then ARCH=armv7; fi;
    if [ "$ABI" = "mip" ]; then ARCH=mips; fi;
    if [ "$ABILONG" = "mips" ]; then ARCH=mips; fi;
  fi
  if [ "$API" -ge "18" ]; then
    SUMOD=0755
  fi
  if [ "$API" -ge "20" ]; then
    if [ "$ABILONG" = "arm64-v8a" ]; then ARCH=arm64; SYSTEMLIB=/system/lib64; APPPROCESS64=true; fi;
    if [ "$ABILONG" = "mips64" ]; then ARCH=mips64; SYSTEMLIB=/system/lib64; APPPROCESS64=true; fi;
    if [ "$ABILONG" = "x86_64" ]; then ARCH=x64; SYSTEMLIB=/system/lib64; APPPROCESS64=true; fi;
    APKFOLDER=true
    APKNAME=/system/app/SuperSU/SuperSU.apk
  fi
  if [ "$API" -ge "19" ]; then
    SUPOLICY=true
    if [ "$(LD_LIBRARY_PATH=$SYSTEMLIB /system/toolbox ls -lZ /system/bin/toolbox | grep toolbox_exec > /dev/null; echo $?)" -eq "0" ]; then 
      INSTALL_RECOVERY_CONTEXT=u:object_r:toolbox_exec:s0
    fi
  fi
  if [ "$API" -ge "21" ]; then
    APPPROCESS=true
  fi
fi
if [ ! -f $MKSH ]; then
  MKSH=/system/bin/sh
fi

#ui_print "DBG [$API] [$ABI] [$ABI2] [$ABILONG] [$ARCH] [$MKSH]"

ui_print "- Extracting files"
cd /tmp
mkdir supersu
cd supersu

if [ -z "$BIN" ]; then
  $BUSYBOX unzip -o "$ZIP"

  BIN=/tmp/supersu/$ARCH
  COM=/tmp/supersu/common
fi

ui_print "- Disabling OTA survival"
chmod 0755 $BIN/chattr$PIE
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/bin/su
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/xbin/su
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/bin/.ext/.su
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/xbin/daemonsu
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/xbin/sugote
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/xbin/sugote_mksh
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/xbin/supolicy
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/lib/libsupol.so
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/lib64/libsupol.so
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/etc/install-recovery.sh
LD_LIBRARY_PATH=$SYSTEMLIB $BIN/chattr$PIE -i /system/bin/install-recovery.sh

ui_print "- Removing old files"

if [ -f "/system/bin/install-recovery.sh" ]; then
  if [ ! -f "/system/bin/install-recovery_original.sh" ]; then
    mv /system/bin/install-recovery.sh /system/bin/install-recovery_original.sh
    ch_con /system/bin/install-recovery_original.sh
  fi
fi
if [ -f "/system/etc/install-recovery.sh" ]; then
  if [ ! -f "/system/etc/install-recovery_original.sh" ]; then
    mv /system/etc/install-recovery.sh /system/etc/install-recovery_original.sh
    ch_con /system/etc/install-recovery_original.sh
  fi
fi

rm -f /system/bin/su
rm -f /system/xbin/su
rm -f /system/xbin/daemonsu
rm -f /system/xbin/sugote
rm -f /system/xbin/sugote-mksh
rm -f /system/xbin/supolicy
rm -f /system/lib/libsupol.so
rm -f /system/lib64/libsupol.so
rm -f /system/bin/.ext/.su
rm -f /system/bin/install-recovery.sh
rm -f /system/etc/install-recovery.sh
rm -f /system/etc/init.d/99SuperSUDaemon
rm -f /system/etc/.installed_su_daemon

rm -f /system/app/Superuser.apk
rm -f /system/app/Superuser.odex
rm -rf /system/app/Superuser
rm -f /system/app/SuperUser.apk
rm -f /system/app/SuperUser.odex
rm -rf /system/app/SuperUser
rm -f /system/app/superuser.apk
rm -f /system/app/superuser.odex
rm -rf /system/app/superuser
rm -f /system/app/Supersu.apk
rm -f /system/app/Supersu.odex
rm -rf /system/app/Supersu
rm -f /system/app/SuperSU.apk
rm -f /system/app/SuperSU.odex
rm -rf /system/app/SuperSU
rm -f /system/app/supersu.apk
rm -f /system/app/supersu.odex
rm -rf /system/app/supersu
rm -f /system/app/VenomSuperUser.apk
rm -f /system/app/VenomSuperUser.odex
rm -rf /system/app/VenomSuperUser
rm -f /data/dalvik-cache/*com.noshufou.android.su*
rm -f /data/dalvik-cache/*/*com.noshufou.android.su*
rm -f /data/dalvik-cache/*com.koushikdutta.superuser*
rm -f /data/dalvik-cache/*/*com.koushikdutta.superuser*
rm -f /data/dalvik-cache/*com.mgyun.shua.su*
rm -f /data/dalvik-cache/*/*com.mgyun.shua.su*
rm -f /data/dalvik-cache/*com.m0narx.su*
rm -f /data/dalvik-cache/*/*com.m0narx.su*
rm -f /data/dalvik-cache/*Superuser.apk*
rm -f /data/dalvik-cache/*/*Superuser.apk*
rm -f /data/dalvik-cache/*SuperUser.apk*
rm -f /data/dalvik-cache/*/*SuperUser.apk*
rm -f /data/dalvik-cache/*superuser.apk*
rm -f /data/dalvik-cache/*/*superuser.apk*
rm -f /data/dalvik-cache/*VenomSuperUser.apk*
rm -f /data/dalvik-cache/*/*VenomSuperUser.apk*
rm -f /data/dalvik-cache/*eu.chainfire.supersu*
rm -f /data/dalvik-cache/*/*eu.chainfire.supersu*
rm -f /data/dalvik-cache/*Supersu.apk*
rm -f /data/dalvik-cache/*/*Supersu.apk*
rm -f /data/dalvik-cache/*SuperSU.apk*
rm -f /data/dalvik-cache/*/*SuperSU.apk*
rm -f /data/dalvik-cache/*supersu.apk*
rm -f /data/dalvik-cache/*/*supersu.apk*
rm -f /data/dalvik-cache/*.oat
rm -f /data/app/com.noshufou.android.su*
rm -f /data/app/com.koushikdutta.superuser*
rm -f /data/app/com.mgyun.shua.su*
rm -f /data/app/com.m0narx.su*
rm -f /data/app/eu.chainfire.supersu-*
rm -f /data/app/eu.chainfire.supersu.apk

ui_print "- Placing files"

mkdir /system/bin/.ext
set_perm 0 0 0777 /system/bin/.ext
cp_perm 0 0 $SUMOD $BIN/su /system/bin/.ext/.su
cp_perm 0 0 $SUMOD $BIN/su /system/xbin/su
cp_perm 0 0 0755 $BIN/su /system/xbin/daemonsu
if ($SUGOTE); then
  cp_perm 0 0 0755 $BIN/su /system/xbin/sugote u:object_r:zygote_exec:s0
  cp_perm 0 0 0755 $MKSH /system/xbin/sugote-mksh
fi
if ($SUPOLICY); then
  cp_perm 0 0 0755 $BIN/supolicy /system/xbin/supolicy
  cp_perm 0 0 0644 $BIN/libsupol.so $SYSTEMLIB/libsupol.so
fi
if ($APKFOLDER); then
  mkdir /system/app/SuperSU
  set_perm 0 0 0755 /system/app/SuperSU
fi
cp_perm 0 0 0644 $COM/Superuser.apk $APKNAME
cp_perm 0 0 0755 $COM/install-recovery.sh /system/etc/install-recovery.sh
ln_con /system/etc/install-recovery.sh /system/bin/install-recovery.sh
if ($APPPROCESS); then
  rm /system/bin/app_process
  ln_con /system/xbin/daemonsu /system/bin/app_process
  if ($APPPROCESS64); then
    if [ ! -f "/system/bin/app_process64_original" ]; then
      mv /system/bin/app_process64 /system/bin/app_process64_original
    else
      rm /system/bin/app_process64
    fi
    ln_con /system/xbin/daemonsu /system/bin/app_process64
    if [ ! -f "/system/bin/app_process_init" ]; then
      cp_perm 0 2000 0755 /system/bin/app_process64_original /system/bin/app_process_init
    fi
  else
    if [ ! -f "/system/bin/app_process32_original" ]; then
      mv /system/bin/app_process32 /system/bin/app_process32_original
    else
      rm /system/bin/app_process32
    fi
    ln_con /system/xbin/daemonsu /system/bin/app_process32
    if [ ! -f "/system/bin/app_process_init" ]; then
      cp_perm 0 2000 0755 /system/bin/app_process32_original /system/bin/app_process_init
    fi
  fi
fi
cp_perm 0 0 0744 $COM/99SuperSUDaemon /system/etc/init.d/99SuperSUDaemon
echo 1 > /system/etc/.installed_su_daemon
set_perm 0 0 0644 /system/etc/.installed_su_daemon

ui_print "- Post-installation script"
rm /system/toolbox
LD_LIBRARY_PATH=$SYSTEMLIB /system/xbin/su --install

ui_print "- Unmounting /system and /data"
umount /system
umount /data
rm -rf /tmp

ui_print "- Done !"
exit 0
