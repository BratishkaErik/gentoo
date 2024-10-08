# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DIST_AUTHOR=STBEY
DIST_VERSION=6.4
inherit perl-module

DESCRIPTION="Gregorian calendar date calculations"

LICENSE="|| ( Artistic GPL-1+ ) LGPL-2"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x64-solaris"

RDEPEND="
	>=dev-perl/Bit-Vector-7.400.0
	>=dev-perl/Carp-Clan-6.40.0
"
BDEPEND="${RDEPEND}
	virtual/perl-ExtUtils-MakeMaker
"

mydoc="ToDo"
