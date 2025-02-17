# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..13} )

inherit distutils-r1 git-r3

DESCRIPTION="Python CPIO library"
HOMEPAGE="https://github.com/desultory/pycpio/"
EGIT_REPO_URI="https://github.com/desultory/${PN}"

LICENSE="GPL-2"
SLOT="0"

RDEPEND="
	>=dev-python/zenlib-3.0.2[${PYTHON_USEDEP}]
	>=dev-python/zstd-1.5.6.1[${PYTHON_USEDEP}]
"

distutils_enable_tests unittest

python_test() {
	eunittest tests
}
