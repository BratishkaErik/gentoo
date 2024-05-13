# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: zig-build.eclass
# @MAINTAINER:
# Eric Joldasov <bratishkaerik@landless-city.net>
# @AUTHOR:
# Eric Joldasov <bratishkaerik@landless-city.net>
# @SUPPORTED_EAPIS: 8
# @PROVIDES: zig-toolchain
# @BLURB: Functions for working with ZBS (Zig Build System).
# @DESCRIPTION:
# TODO

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ ! ${_ZIG_BUILD_ECLASS} ]]; then
_ZIG_BUILD_ECLASS=1

inherit multiprocessing zig-toolchain

# See https://github.com/ziglang/zig/issues/3382
# For now (maybe never?), Zig doesn't support CFLAGS/LDFLAGS/etc.
QA_FLAGS_IGNORED=".*"

BDEPEND+="virtual/pkgconfig"

# @ECLASS_VARIABLE: ZBS_VERBOSE
# @USER_VARIABLE
# @DESCRIPTION:
# By default, ZBS will print all commands before executing them.
# Set to OFF to disable these verbose messages.
#
# This variable affects only the "--verbose" parameter
# and does not impact other parameters that begin with "--verbose",
# such as "--verbose-air", which are used for debugging the Zig compiler.
: "${ZBS_VERBOSE:=ON}"


# @ECLASS_VARIABLE: ZBS_ECLASS_DIR
# @PRE_INHERIT
# @DESCRIPTION:
# TODO absolute path, no trailing slash.
#
# TODO defaults to "${WORKDIR}/zig-eclass" if not set.
: "${ZBS_ECLASS_DIR:=${WORKDIR}/zig-eclass}"

# @FUNCTION: zig-build_get_jobs
# @DESCRIPTION:
# Returns number of jobs, extracted from ZBS_ARGS_EXTRA or MAKEOPTS.
# If empty, defaults to number of available processing units
# (like upstream does when "-jN" is not passed).
zig-build_get_jobs() {
	# Should never be empty or zero.
	echo $(makeopts_jobs "${ZBS_ARGS_EXTRA} ${MAKEOPTS}" "$(get_nproc)")
}

# @INTERNAL
zig-build_populate_base_args() {
	[[ ${ZBS_ARGS_BASE} ]] && return

	declare -g -a ZBS_ARGS_BASE=(
		--build-file "${S}/build.zig"
		-j$(zig-build_get_jobs)

		-Dtarget=${ZIG_TARGET}
		-Dcpu=${ZIG_CPU}

		# TODO. Description below is for me, remove or rewrite after "zig build test" completed:
		# broken, Zig thinks all these libraries are valid for any target.
		#--search-prefix "${BROOT}/usr/"

		--prefix-exe-dir bin/
		--prefix-lib-dir $(get_libdir)/
		--prefix-include-dir include/
		--prefix usr/
	)
	[[ "${ZBS_VERBOSE}" != OFF ]] && ZBS_ARGS_BASE+=( --verbose --summary all )
}

zig-build_pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] || return 0

	zig-toolchain_populate_env_vars
	zig-build_populate_base_args

	einfo "ZBS_ECLASS_DIR: ${ZBS_ECLASS_DIR}"

	mkdir "${T}/zig-cache/" || die
	export ZIG_LOCAL_CACHE_DIR="${T}/zig-cache/local/"
	export ZIG_GLOBAL_CACHE_DIR="${T}/zig-cache/global/"
}

# @INTERNAL
_zig-build_set_system_mode() {
	[[ ${#} -eq 1 ]] || die "${FUNCNAME[0]}: exactly one argument must be passed"
	local system_dir="${1}"

	local -a packages=()
	readarray -d '' -t packages < <(find "${system_dir}/" -mindepth 1 -maxdepth 1 -type d -print0 || die "")

	ewarn "Packages:"
	ewarn "${packages[@]}"
	local count="${#packages[@]}"
	if [[ "${count}" -gt 0 ]]; then
		einfo "ZBS: found fetched packages: ${count}"
		ZBS_ARGS_BASE+=( --system "${system_dir}/" )
		einfo "ZBS: system mode enabled"
	else
		einfo "ZBS: no fetched packages found, not enabling system mode"
	fi
}

zig-build_live_fetch() {
	has live "${PROPERTIES}" || die "${FUNCNAME[0]}: only allowed in live ebuilds"
	[[ ${EBUILD_PHASE} == unpack ]] || die "${FUNCNAME[0]}: only allowed in src_unpack"

	pushd "${S}" > /dev/null || die

	local args=(
		"${ZBS_ARGS_BASE[@]}"

		# Arguments from ebuild
		"${my_zbs_fetch_args[@]}"

		--global-cache-dir "${ZBS_ECLASS_DIR}/"
		--fetch
	)

	einfo "ZBS: attempting to live-fetching dependencies using the following options: ${args[@]}"
	ezig build "${args[@]}" || die "ZBS: fetching dependencies failed"

	popd > /dev/null || die

	# TODO
	_zig-build_set_system_mode "${ZBS_ECLASS_DIR}/p"
}

zig-build_src_unpack() {
	default

	_zig-build_set_system_mode "${ZBS_ECLASS_DIR}/p"
}

zig-build_src_configure() {
	declare -g -a ZBS_ARGS=( "${ZBS_ARGS_BASE[@]}" )

	if tc-is-cross-compiler; then
		cat <<- _EOF_ > "${T}/zig_libc.txt" || die "Failed to create Zig libc installation paths file"
			include_dir=${ESYSROOT}/usr/include/
			sys_include_dir=${ESYSROOT}/usr/include/
			crt_dir=${ESYSROOT}/usr/$(get_libdir)/
			# Windows with MSVC only.
			msvc_lib_dir=
			# Windows with MSVC only.
			kernel32_lib_dir=
			# Haiku only.
			gcc_dir=
		_EOF_

		ZBS_ARGS+=( --libc "${T}/zig_libc.txt" )
	fi

	ZBS_ARGS+=(
		# Arguments from ebuild
		"${my_zbs_args[@]}"

		# Arguments from user
		"${ZBS_ARGS_EXTRA[@]}"
	)
	# Since most arguments in array are also cached by ZBS, we want to
	# reuse array as much as possible, so prevent modification of it.
	readonly ZBS_ARGS

	einfo "Configured with:"
	einfo "${ZBS_ARGS[@]}"
}

zig-build_src_compile() {
	ezig build "${ZBS_ARGS[@]}" "${@}" || die "ZBS: compilation failed"
}

zig-build_src_test() {
	# UPSTREAM std.testing.tmpDir does not respect ZIG_LOCAL_CACHE_DIR:
	# https://github.com/ziglang/zig/issues/19874
	mkdir "${S}/zig-cache/" || die

	local found_test_step=false

	local -a steps
	readarray steps < <(ezig build --list-steps "${ZBS_ARGS[@]}" || die "ZBS: listing steps failed")

	for step in "${steps[@]}"; do
		# UPSTREAM Currently, step name can have any characters in it,
		# including whitespaces, so splitting names and
		# descriptions by whitespaces is not enough for some cases.
		# We probably need something like "--list-steps names_only".
		# In practice, almost nobody sets such names.
		step_name=$(awk '{print $1}' <<< "${step}")
		if [[ ${step_name} == test ]]; then
			found_test_step=true
			break
		fi
	done

	if [[ ${found_test_step} == true ]]; then
		ezig build test "${ZBS_ARGS[@]}" "${@}" || die "ZBS: tests failed"
	else
		einfo "Test step not found, skipping."
		return
	fi
}

zig-build_src_install() {
	DESTDIR="${ED}" ezig build install "${ZBS_ARGS[@]}" "${@}" || die "ZBS: installing failed"

	einstalldocs
}

fi

EXPORT_FUNCTIONS pkg_setup src_unpack src_configure src_compile src_test src_install
