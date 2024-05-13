# Copyright 2019-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( 17 )
LLVM_OPTIONAL=1

inherit check-reqs cmake flag-o-matic edo llvm-r1 toolchain-funcs zig-build

DESCRIPTION="A robust, optimal, and maintainable programming language"
HOMEPAGE="https://ziglang.org/"
if [[ ${PV} == 9999 ]]; then
	EGIT_REPO_URI="https://github.com/ziglang/zig.git"
	inherit git-r3
else
	SRC_URI="https://ziglang.org/download/${PV}/${P}.tar.xz"
	KEYWORDS="~amd64 ~arm ~arm64"
fi

# project itself: MIT
# There are bunch of projects under "lib/" folder that are needed for cross-compilation.
# Files that are unnecessary for cross-compilation are removed by upstream
# and therefore their licenses (if any special) are not included.
# lib/libunwind: Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT )
# lib/libcxxabi: Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT )
# lib/libcxx: Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT )
# lib/libc/wasi: || ( Apache-2.0-with-LLVM-exceptions Apache-2.0 MIT BSD-2 ) public-domain
# lib/libc/musl: MIT BSD-2
# lib/libc/mingw: ZPL public-domain BSD-2 ISC HPND
# lib/libc/glibc: BSD HPND ISC inner-net LGPL-2.1+
LICENSE="MIT Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT ) || ( Apache-2.0-with-LLVM-exceptions Apache-2.0 MIT BSD-2 ) public-domain BSD-2 ZPL ISC HPND BSD inner-net LGPL-2.1+"
SLOT="$(ver_cut 1-2)"
IUSE="doc +llvm"
REQUIRED_USE="
	!llvm? ( !doc )
	llvm? ( ${LLVM_REQUIRED_USE} )
"

BUILD_DIR="${S}/build"

# Zig requires zstd and zlib compression support in LLVM, if using LLVM backend.
# (non-LLVM backends don't require these)
# They are not required "on their own", so please don't add them here.
# You can check https://github.com/ziglang/zig-bootstrap in future, to see
# options that are passed to LLVM CMake building (excluding "static" ofc).
DEPEND="
	llvm? (
		$(llvm_gen_dep '
			sys-devel/clang:${LLVM_SLOT}
			sys-devel/lld:${LLVM_SLOT}
			sys-devel/llvm:${LLVM_SLOT}[zstd]
		')
	)
"
RDEPEND="${DEPEND}"
IDEPEND="app-eselect/eselect-zig"

RESTRICT="!llvm? ( test )"

# Since commit https://github.com/ziglang/zig/commit/e7d28344fa3ee81d6ad7ca5ce1f83d50d8502118
# Zig uses self-hosted compiler only
CHECKREQS_MEMORY="4G"

PATCHES=(
	"${FILESDIR}/zig-0.12.0-skip-tests.patch"
)

pkg_setup() {
	zig-build_pkg_setup

	export ZIG_SYS_INSTALL_DEST="usr/$(get_libdir)/zig/${PV}"

	use llvm && llvm-r1_pkg_setup
	check-reqs_pkg_setup
}

src_prepare() {
	cmake_src_prepare

	# Remove "limit memory usage" flags, it's already verified by
	# CHECKREQS_MEMORY and causes unneccessary errors. Upstream set them
	# according to CI OOM failures, which are not applicable to normal Gentoo build.
	sed -i -e '/\.max_rss = .*,/d' build.zig || die
}

src_configure() {
	# Has no effect on final binary and only causes failures during bootstrapping.
	filter-lto

	# Used during bootstrapping. stage1/stage2 have limited functionality
	# and can't resolve native target, so we pass target in exact form.
	declare -r -g ZIG_HOST_AS_TARGET=$(zig-toolchain_get_target ${CHOST})

	# If not passed explicitly, "zig build" detects it fine during src_compile
	# but can fail in src_install and trigger partial re-compilation.
	local zig_version
	if [[ ${PV} == 9999 ]]; then
		zig_version=$(git -C '.' describe --match '*.*.*' --tags --abbrev=9 || die "Detecting Zig version failed")
	else
		zig_version=${PV}
	fi


	# Note that if we are building with CMake, "my_zbs_args" is used
	# only during src_test and doc generation.
	local my_zbs_args=(
		--zig-lib-dir "${S}/lib/"
		# Will be a subdir under ZIG_SYS_INSTALL_DEST.
		--prefix-lib-dir lib/

		-Dversion-string=${zig_version}
		-Dstatic-llvm=false

		# These are built separately
		-Dno-langref
		-Dstd-docs=false

		# Testing options
		-Dskip-non-native
	)
	if use llvm; then
		my_zbs_args+=(
			-Denable-llvm=true
			-Dconfig_h="${BUILD_DIR}/config.h"

			--release=fast
		)
	else
		my_zbs_args+=(
			-Denable-llvm=false

			# Currently, Zig without LLVM extensions lacks most optimizations,
			# so we are leaving it to Debug for now.
			--release=off
		)
	fi

	zig-build_src_configure

	if use llvm; then
		local mycmakeargs=(
			-DZIG_USE_CCACHE=OFF
			-DZIG_SHARED_LLVM=ON
			-DZIG_USE_LLVM_CONFIG=ON

			-DZIG_VERSION=${zig_version}
			-DZIG_TARGET_TRIPLE=${ZIG_TARGET}
			-DZIG_TARGET_MCPU=${ZIG_CPU}
			-DZIG_HOST_TARGET_TRIPLE=${ZIG_HOST_AS_TARGET}

			-DCMAKE_PREFIX_PATH="$(get_llvm_prefix)"
			-DCMAKE_INSTALL_PREFIX="${EPREFIX}/${ZIG_SYS_INSTALL_DEST}"
		)

		cmake_src_configure
	fi
}

src_compile() {
	if use llvm; then
		cmake_src_compile
	else
		local cc="$(tc-getCC)"
		"${cc}" -o bootstrap bootstrap.c || die "Zig's bootstrap.c compilation failed"
		ZIG_HOST_TARGET_TRIPLE=${ZIG_HOST_AS_TARGET} CC="${cc}" edob ./bootstrap
		ZIG_EXE="${S}/zig2" zig-build_src_compile --prefix "${BUILD_DIR}/stage3/"
	fi

	cd "${BUILD_DIR}" || die
	./stage3/bin/zig env || die "Zig compilation failed"

	if use doc; then
		TERM=dumb ZIG_EXE="${BUILD_DIR}/stage3/bin/zig" zig-build_src_compile std-docs langref --prefix "${S}/docgen/"
	fi
}

src_test() {
	cd "${BUILD_DIR}" || die
	TERM=dumb ZIG_EXE="${BUILD_DIR}/stage3/bin/zig" zig-build_src_test
}

src_install() {
	local DOCS=( "README.md" "doc/build.zig.zon.md" )
	use doc && local HTML_DOCS=( "docgen/doc/langref.html" "docgen/doc/std" )

	if use llvm; then
		cmake_src_install
	else
		TERM=dumb ZIG_EXE="${S}/zig2" zig-build_src_install --prefix "${ZIG_SYS_INSTALL_DEST}"
	fi

	cd "${ED}/${ZIG_SYS_INSTALL_DEST}" || die
	mv lib/zig/ lib2/ || die
	rm -rf lib/ || die
	mv lib2/ lib/ || die
	dosym -r "/${ZIG_SYS_INSTALL_DEST}/bin/zig" /usr/bin/zig-${PV}
}

pkg_postinst() {
	eselect zig update ifunset

	if ! use llvm; then
		elog "Currently, Zig built without LLVM support lacks some"
		elog "important features such as most optimizations, @cImport, etc."
		elog "They are listed under \"Building from Source without LLVM\""
		elog "section of the README file from \"/usr/share/doc/${PF}\" ."
		elog "It's recommended to use C backend directly with this stage2 build."
	fi
}

pkg_postrm() {
	eselect zig update ifunset
}
