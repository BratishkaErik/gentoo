# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit multilib multilib-build

DESCRIPTION="Meta-ebuild for clang runtime libraries"
HOMEPAGE="https://clang.llvm.org/"
S=${WORKDIR}

LICENSE="metapackage"
SLOT="${PV%%.*}"
KEYWORDS="~amd64 ~arm ~arm64 ~loong ~mips ~ppc ~ppc64 ~riscv ~sparc ~x86 ~amd64-linux ~arm64-macos ~ppc-macos ~x64-macos"
IUSE="
	+compiler-rt libcxx offload openmp +sanitize
	default-compiler-rt default-libcxx default-lld llvm-libunwind polly
"
REQUIRED_USE="
	sanitize? ( compiler-rt )
"

RDEPEND="
	compiler-rt? (
		~llvm-runtimes/compiler-rt-${PV}:${SLOT}[abi_x86_32(+)?,abi_x86_64(+)?]
		sanitize? (
			~llvm-runtimes/compiler-rt-sanitizers-${PV}:${SLOT}[abi_x86_32(+)?,abi_x86_64(+)?]
		)
	)
	libcxx? ( >=llvm-runtimes/libcxx-${PV}[${MULTILIB_USEDEP}] )
	openmp? (
		>=llvm-runtimes/openmp-${PV}[${MULTILIB_USEDEP}]
		offload? (
			>=llvm-runtimes/offload-${PV}
		)
	)

	llvm-core/clang-common
	default-compiler-rt? (
		~llvm-runtimes/compiler-rt-${PV}:${SLOT}[abi_x86_32(+)?,abi_x86_64(+)?]
		llvm-libunwind? ( llvm-runtimes/libunwind[static-libs] )
		!llvm-libunwind? ( sys-libs/libunwind[static-libs] )
	)
	!default-compiler-rt? ( sys-devel/gcc )
	default-libcxx? ( >=llvm-runtimes/libcxx-${PV}[static-libs] )
	!default-libcxx? ( sys-devel/gcc )
	default-lld? ( ~llvm-core/lld-${PV} )
	!default-lld? ( sys-devel/binutils )
	polly? ( ~llvm-core/polly-${PV} )
"

_doclang_cfg() {
	local triple="${1}"

	local tool
	for tool in ${triple}-clang{,++,-cpp}; do
		newins - "${tool}.cfg" <<-EOF
			# This configuration file is used by ${tool} driver.
			@../${tool}.cfg
			@gentoo-plugins.cfg
			@gentoo-runtimes.cfg
		EOF
	done

	# Install symlinks for triples with other vendor strings since some
	# programs insist on mangling the triple.
	local vendor
	for vendor in gentoo pc unknown; do
		local vendor_triple="${triple%%-*}-${vendor}-${triple#*-*-}"
		for tool in clang{,++,-cpp}; do
			if [[ ! -f "${ED}/etc/clang/${SLOT}/${vendor_triple}-${tool}.cfg" ]]; then
				dosym "${triple}-${tool}.cfg" "/etc/clang/${SLOT}/${vendor_triple}-${tool}.cfg"
			fi
		done
	done
}

doclang_cfg() {
	local triple=$(get_abi_CHOST "${abi}")

	_doclang_cfg ${triple}

	# LLVM may have different arch names in some cases. For example in x86
	# profiles the triple uses i686, but llvm will prefer i386 if invoked
	# with "clang" on x86 or "clang -m32" on x86_64. The gentoo triple will
	# be used if invoked through ${CHOST}-clang{,++,-cpp} though.
	#
	# To make sure the correct triples are installed,
	# see Triple::getArchTypeName() in llvm/lib/TargetParser/Triple.cpp
	# and compare with CHOST values in profiles.

	local abi=${triple%%-*}
	case ${abi} in
		armv4l|armv4t|armv5tel|armv6j|armv7a)
			_doclang_cfg ${triple/${abi}/arm}
			;;
		i686)
			_doclang_cfg ${triple/${abi}/i386}
			;;
		sparc)
			_doclang_cfg ${triple/${abi}/sparcel}
			;;
		sparc64)
			_doclang_cfg ${triple/${abi}/sparcv9}
			;;
	esac
}

src_install() {
	insinto "/etc/clang/${SLOT}"
	newins - gentoo-runtimes.cfg <<-EOF
		# This file is initially generated by llvm-core/clang-runtime.
		# It is used to control the default runtimes using by clang.

		--rtlib=$(usex default-compiler-rt compiler-rt libgcc)
		--unwindlib=$(usex default-compiler-rt libunwind libgcc)
		--stdlib=$(usex default-libcxx libc++ libstdc++)
		-fuse-ld=$(usex default-lld lld bfd)
	EOF
	newins - gentoo-plugins.cfg <<-EOF
		# This file is used to load optional LLVM plugins.
	EOF
	if use polly; then
		cat >> "${ED}/etc/clang/${SLOT}/gentoo-plugins.cfg" <<-EOF || die
			-fpass-plugin=LLVMPolly.so
			-fplugin=LLVMPolly.so
		EOF
	fi

	multilib_foreach_abi doclang_cfg
}
