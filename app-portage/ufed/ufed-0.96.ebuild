# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://anongit.gentoo.org/git/proj/ufed.git"
else
	SRC_URI="https://gitweb.gentoo.org/proj/ufed.git/snapshot/${P}.tar.bz2"
	KEYWORDS="~alpha amd64 arm ~arm64 ~hppa ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux"
fi

inherit autotools flag-o-matic out-of-source

DESCRIPTION="Gentoo Linux USE flags editor"
HOMEPAGE="https://wiki.gentoo.org/wiki/Ufed"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

RDEPEND="
	dev-lang/perl
	sys-libs/ncurses:0="
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_prepare() {
	default
	# Change the version number to reflect the ebuild version
	local REPLACEMENT_VERSION_STR="${PVR}"
	[[ ${PV} == *9999 ]] && REPLACEMENT_VERSION_STR+="-${EGIT_VERSION}"
	sed -i "s:,\[git\],:,\[${REPLACEMENT_VERSION_STR}\],:" configure.ac || die

	eautoreconf
}

my_src_configure() {
	# -Werror=lto-type-mismatch
	# https://bugs.gentoo.org/854864
	filter-lto

	default
}
