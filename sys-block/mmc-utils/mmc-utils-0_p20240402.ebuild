# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="Userspace tools for MMC/SD devices"
HOMEPAGE="https://git.kernel.org/pub/scm/utils/mmc/mmc-utils.git/"

MY_COMMIT="f757f413dea4a143ad7c3b48b8264176f0499a82"

SRC_URI="https://git.kernel.org/pub/scm/utils/mmc/mmc-utils.git/snapshot/mmc-utils-${MY_COMMIT}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/${PN}-${MY_COMMIT}"

LICENSE="GPL-2 BSD"
SLOT="0"

KEYWORDS="amd64 ~arm64"

RDEPEND="!dev-lang/mercury"

src_prepare() {
	default
	sed -i \
		-e 's/-Werror //' \
		-e 's/-D_FORTIFY_SOURCE=2 //' \
		-e "s/-DVERSION=.*/-DVERSION=\\\\\"gentoo-${PVR}\\\\\"/" \
		Makefile || die
}

src_configure() {
	tc-export CC
}

src_install() {
	dosbin mmc
	dodoc README
	doman man/mmc.1
}
