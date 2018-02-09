#!/bin/bash
 ##############################################################################
 #                      parabola-riscv64-bootstrap                            #
 #                                                                            #
 #    Copyright (C) 2018  Andreas Grapentin                                   #
 #                                                                            #
 #    This program is free software: you can redistribute it and/or modify    #
 #    it under the terms of the GNU General Public License as published by    #
 #    the Free Software Foundation, either version 3 of the License, or       #
 #    (at your option) any later version.                                     #
 #                                                                            #
 #    This program is distributed in the hope that it will be useful,         #
 #    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
 #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
 #    GNU General Public License for more details.                            #
 #                                                                            #
 #    You should have received a copy of the GNU General Public License       #
 #    along with this program.  If not, see <http://www.gnu.org/licenses/>.   #
 ##############################################################################

set -eu

_pkgname=gcc-libs-shim
_pkgver=$(pacman -Qi $_target-gcc | grep '^Version' | cut -d':' -f2 | tr -d [:space:])
_pkgdir="$_makepkgdir"/$_pkgname/pkg/$_pkgname

msg "makepkg: $_pkgname-$_pkgver-$_arch.pkg.tar.xz"

mkdir -pv "$_makepkgdir"/$_pkgname
pushd "$_makepkgdir"/$_pkgname >/dev/null

# to produce gcc-libs shim from gcc, we need the package
pacman -Sw --noconfirm --cachedir . $_target-gcc
mkdir tmp && bsdtar -C tmp -xf $_target-gcc-$_pkgver-*.pkg.tar.xz

# install libraries
mkdir -p "$_pkgdir"/usr
cp -a tmp/usr/$_target/lib "$_pkgdir"/usr/lib

# produce .PKGINFO file
cat > "$_pkgdir"/.PKGINFO << EOF
pkgname = $_pkgname
pkgver = $_pkgver
pkgdesc = Runtime libraries shipped by GCC (extracted from $_target-gcc)
url = https://github.com/riscv/riscv-gnu-toolchain
builddate = $(date '+%s')
size = $(( $(du -sk --apparent-size "$_pkgdir" | cut -d'	' -f1) * 1024 ))
arch = $_arch
provides = ${_pkgname%-*}
conflicts = ${_pkgname%-*}
EOF

# package
cd "$_pkgdir"
env LANG=C bsdtar -czf .MTREE \
  --format=mtree \
  --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \
  .PKGINFO *
env LANG=C bsdtar -cf - .MTREE .PKGINFO * | xz -c -z - > \
  "$_chrootdir"/packages/$_arch/$_pkgname-$_pkgver-$_arch.pkg.tar.xz

popd >/dev/null

# rm -rf "$_makepkgdir"/$_pkgname

rm -rf "$_chrootdir"/var/cache/pacman/pkg/*
rm -rf "$_chrootdir"/packages/$_arch/repo.{db,files}*
repo-add -R "$_chrootdir"/packages/$_arch/{repo.db.tar.gz,*.pkg.tar.xz}
pacman --noconfirm --config "$_chrootdir"/etc/pacman.conf -r "$_chrootdir" -Syy $_pkgname
