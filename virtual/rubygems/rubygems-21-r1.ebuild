# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
USE_RUBY="ruby31 ruby32 ruby33 ruby34"

inherit ruby-ng

DESCRIPTION="Virtual ebuild for rubygems"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86 ~amd64-linux ~x86-linux ~arm64-macos ~ppc-macos ~x64-macos ~x64-solaris"

RDEPEND="
	ruby_targets_ruby31? ( >=dev-ruby/rubygems-3.3.26[ruby_targets_ruby31] )
	ruby_targets_ruby32? ( >=dev-ruby/rubygems-3.4.19[ruby_targets_ruby32] )
	ruby_targets_ruby33? ( >=dev-ruby/rubygems-3.5.22[ruby_targets_ruby33] )
	ruby_targets_ruby34? ( >=dev-ruby/rubygems-3.6.2[ruby_targets_ruby34] )
"

pkg_setup() { :; }
src_unpack() { :; }
src_prepare() { eapply_user; }
src_compile() { :; }
src_install() { :; }
pkg_preinst() { :; }
pkg_postinst() { :; }
