# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="NCurses Disk Usage"
HOMEPAGE="https://dev.yorhel.nl/ncdu/"

SRC_URI="
	amd64? ( https://dev.yorhel.nl/download/ncdu-${PV}-linux-x86_64.tar.gz )
	arm? ( https://dev.yorhel.nl/download/ncdu-${PV}-linux-arm.tar.gz )
	arm64? ( https://dev.yorhel.nl/download/ncdu-${PV}-linux-aarch64.tar.gz )
	x86? ( https://dev.yorhel.nl/download/ncdu-${PV}-linux-i386.tar.gz )"

LICENSE="MIT"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm ~arm64 ~x86"

RDEPEND="!!sys-fs/ncdu"

S="${WORKDIR}"

QA_PREBUILT="/usr/bin/ncdu"

src_install() {
	dobin ncdu
}
