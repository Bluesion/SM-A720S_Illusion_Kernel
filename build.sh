#!/bin/bash
# Build Script By Tkkg1994 and djb77
# Modified by TheFlash & Illusion / XDA Developers

# ---------
# VARIABLES
# ---------
VERSION_NUMBER=v1
ARCH=arm64
BUILD_CROSS_COMPILE=~/toolchains/arm64/bin/aarch64-linux-gnu-
BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`
RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include
PAGE_SIZE=2048
DTB_PADDING=0
KERNELNAME=Illusion_Kernel
ZIPLOC=zip

# Colours
bldred=${txtbld}$(tput setaf 1) # red
bldblu=${txtbld}$(tput setaf 4) # blue
bldcya=${txtbld}$(tput setaf 6) # cyan
txtrst=$(tput sgr0) # Reset

# ---------
# FUNCTIONS
# ---------

FUNC_CLEAN()
{
make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
	CROSS_COMPILE=$BUILD_CROSS_COMPILE clean
make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
	CROSS_COMPILE=$BUILD_CROSS_COMPILE mrproper
rm -f $RDIR/build/build.log
rm -f $RDIR/build/build-A720S.log
rm -rf $RDIR/arch/arm64/boot/dtb
rm -f $RDIR/arch/$ARCH/boot/dts/*.dtb
rm -f $RDIR/arch/$ARCH/boot/boot.img-dtb
rm -f $RDIR/arch/$ARCH/boot/boot.img-zImage
rm -f $RDIR/build/boot.img
rm -f $RDIR/build/*.zip
rm -f $RDIR/build/AIK/image-new.img
rm -f $RDIR/build/AIK/ramdisk-new.cpio.gz
rm -f $RDIR/build/AIK/split_img/boot.img-dtb
rm -f $RDIR/build/AIK/split_img/boot.img-zImage
rm -f $RDIR/build/AIK/image-new.img
rm -f $RDIR/build/flash/*.zip
rm -f $RDIR/build/flash/*.img
}

FUNC_BUILD_DTB()
{
[ -f "$DTCTOOL" ] || {
	echo "You need to run ./build.sh first!"
	exit 1
}
case $MODEL in
a7y17lteskt)
	DTSFILES="exynos7880-a7y17lte_kor_all_00 exynos7880-a7y17lte_kor_all_01
		exynos7880-a7y17lte_kor_all_02 exynos7880-a7y17lte_kor_all_03
		exynos7880-a7y17lte_kor_all_04 exynos7880-a7y17lte_kor_all_06"
	;;
*)
	echo "Unknown device: $MODEL"
	exit 1
	;;
esac
mkdir -p $OUTDIR $DTBDIR
cd $DTBDIR || {
	echo "Unable to cd to $DTBDIR!"
	exit 1
}
rm -f ./*
echo "Processing dts files."
for dts in $DTSFILES; do
	echo "=> Processing: ${dts}.dts"
	${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
	echo "=> Generating: ${dts}.dtb"
	$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
done
echo "Generating dtb.img."
$RDIR/scripts/dtbTool/dtbTool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE
echo "Done."
}

FUNC_BUILD_ZIMAGE()
{
echo ""
echo "build common config="$KERNEL_DEFCONFIG ""
echo "build variant config="$MODEL ""
make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
	CROSS_COMPILE=$BUILD_CROSS_COMPILE \
	$KERNEL_DEFCONFIG || exit -1
make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
	CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
echo ""
}

FUNC_BUILD_RAMDISK()
{
# check if kernel build ok
if [ ! -e $RDIR/arch/$ARCH/boot/Image ]; then
	echo -e "\n${bldred}Kernel Not build! Check Build.log ${txtrst}\n"
	grep -B 3 -C 6 -r error: $RDIR/build/build.log
	grep -B 3 -C 6 -r warn $RDIR/build/build.log
	read -n 1 -s -p "Press any key to continue"
else if [ ! -e $RDIR/arch/$ARCH/boot/dtb.img ]; then
	echo -e "\n${bldred}DTB Not Built! Check Build.log${txtrst}\n"
	grep -B 3 -C 6 -r error:$RDIR/build/build.loguild/build.log
	grep -B 3 -C 6 -r warn $RDIR/build/build.log
	read -n 1 -s -p "Press any key to continue"
fi
fi

if [ ! -f "$RDIR/build/AIK/ramdisk/config" ]; then
	mkdir $RDIR/build/AIK/ramdisk/acct
	mkdir $RDIR/build/AIK/ramdisk/cache
	mkdir $RDIR/build/AIK/ramdisk/config
	mkdir $RDIR/build/AIK/ramdisk/d
	mkdir $RDIR/build/AIK/ramdisk/data
	mkdir $RDIR/build/AIK/ramdisk/dev
	mkdir $RDIR/build/AIK/ramdisk/lib/modules
	mkdir $RDIR/build/AIK/ramdisk/mnt
	mkdir $RDIR/build/AIK/ramdisk/proc
	mkdir $RDIR/build/AIK/ramdisk/storage
	mkdir $RDIR/build/AIK/ramdisk/sys
	mkdir $RDIR/build/AIK/ramdisk/system
	chmod 500 $RDIR/build/AIK/ramdisk/config
fi

mv $RDIR/arch/$ARCH/boot/Image $RDIR/arch/$ARCH/boot/boot.img-zImage
mv $RDIR/arch/$ARCH/boot/dtb.img $RDIR/arch/$ARCH/boot/boot.img-dtb
case $MODEL in
a7y17lteskt)
	rm -f $RDIR/build/AIK/split_img/boot.img-zImage
	rm -f $RDIR/build/AIK/split_img/boot.img-dtb
	mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/build/AIK/split_img/boot.img-zImage
	mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/build/AIK/split_img/boot.img-dtb
	cd $RDIR/build/AIK
	./repackimg.sh
	echo SEANDROIDENFORCE >> image-new.img
	;;
*)
	echo "Unknown device: $MODEL"
	exit 1
	;;
esac
}

FUNC_BUILD_BOOTIMG()
{
	(
	FUNC_BUILD_ZIMAGE
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	) 2>&1	 | tee -a $RDIR/build/build.log
}

FUNC_BUILD_ZIP()
{
echo ""
echo "Building Zip File"
cd $ZIP_FILE_DIR
zip -gq $ZIP_NAME -r META-INF/ -x "*~"
zip -gq $ZIP_NAME -r system/ -x "*~" 
[ -f "$RDIR/build/flash/boot.img" ] && zip -gq $ZIP_NAME boot.img -x "*~"
chmod a+r $ZIP_NAME
mv -f $ZIP_FILE_TARGET $RDIR/build/$ZIP_NAME
cd $RDIR
}

OPTION_1()
{
rm -f $RDIR/build/build.log
MODEL=a7y17lteskt
KERNEL_DEFCONFIG=illusion_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/build/AIK/image-new.img $RDIR/build/flash/boot.img
mv -f $RDIR/build/build.log $RDIR/build/build-A720S.log
ZIP_FILE_DIR=$RDIR/build/flash
ZIP_NAME=Illusion_Kernel_$VERSION_NUMBER.zip
ZIP_FILE_TARGET=$ZIP_FILE_DIR/$ZIP_NAME
FUNC_BUILD_ZIP
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Build Successful"
echo ""
echo "Compiled in $ELAPSED_TIME seconds"
echo ""
}

OPTION_0()
{
echo "${bldred} Cleaning Workspace ${txtrst}"
FUNC_CLEAN
}

if [ "$1" == 0 ]; then
	OPTION_0
fi
if [ "$1" == 1 ]; then
	OPTION_1
fi

# Program Start
rm -rf ./build/build.log
clear
echo "${bldred}"
echo "${txtrst}"
echo " ${bldblu} 0) Clean Workspace ${txtrst}"
echo ""
echo " ${bldblu} 1) Build Illusion Kernel boot.img for A7 2017 ${txtrst}"
echo ""
read -p " ${bldcya}Please select an option: ${txtrst}" prompt
echo ""
if [ $prompt == "0" ]; then
	OPTION_0
	echo ""
	echo ""
	echo ""
	echo ""
	. build.sh
elif [ $prompt == "1" ]; then
	OPTION_1
	echo ""
	echo ""
	echo ""
	echo ""
	read -n 1 -s -p "Press any key to continue"
fi
