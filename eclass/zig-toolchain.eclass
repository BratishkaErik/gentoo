# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: zig-toolchain.eclass
# @MAINTAINER:
# Eric Joldasov <bratishkaerik@landless-city.net>
# @AUTHOR:
# Eric Joldasov <bratishkaerik@landless-city.net>
# @SUPPORTED_EAPIS: 8
# @BLURB: Prepare Zig toolchain and set environment variables.
# @DESCRIPTION:
# Prepare Zig toolchain and set environment variables.
# Does not set any default function, ebuilds must call them manually.
# Generally, only "zig-toolchain_populate_env_vars" is needed.
#
# Intended to be used by ebuilds that call "zig build-exe/lib/obj"
# or "zig test" directly and by "dev-lang/zig".
# For ebuilds with ZBS (Zig Build System), it's usually better
# to inherit zig-build instead, as it has default phases-functions.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ ! ${_ZIG_TOOLCHAIN_ECLASS} ]]; then
_ZIG_TOOLCHAIN_ECLASS=1

inherit flag-o-matic

# @ECLASS_VARIABLE: ZIG_TARGET
# @DESCRIPTION:
# Zig target triple to use. Has the following format:
# arch-os[.os_version_range]-abi[.abi_version]
# Can be passed as:
# * "-target " option in "zig test" or "zig build-exe/lib/obj",
# * "-Dtarget=" option in "zig build" (if project uses "std.Build.standardTargetOptions").
#
# Can be overriden by user. If not overriden, then set by "zig-toolchain_populate_env_vars".

# @ECLASS_VARIABLE: ZIG_CPU
# @DESCRIPTION:
# Zig target CPU and features to use. Has the following format:
# family_name(\+enable_feature|\-disable_feature)*
# Can be passed as:
# * "-mcpu " option in "zig test" or "zig build-exe/lib/obj",
# * "-Dcpu=" option in "zig build" (if project uses "std.Build.standardTargetOptions").
#
# Can be overriden by user. If not overriden, then set by "zig-toolchain_populate_env_vars".

# @ECLASS_VARIABLE: ZIG_EXE
# @DESCRIPTION:
# Absolute path to the used Zig executable.
#
# Please note that when passing one flag several times with different values:
# * to "zig build" in "-Dbar=false -Dbar" form: errors due to conflict of flags,
# * to "zig build" in "-Dbar=false -Dbar=true" form: "bar" becomes a list, which is likely not what you (or upstream) want,
# * to "zig test" or "zig build-exe/lib/obj" in "-fbar -fno-bar" form: latest value overwrites values before.
# Similar situation with other types of options (enums, "std.SemanticVersion", integers, strings, etc.)
#
# Can be overriden by user. If not overriden, then set by "zig-toolchain_populate_env_vars".

# @ECLASS_VARIABLE: ZIG_SLOT
# @PRE_INHERIT
# @DESCRIPTION:
# Zig slot that is suitable for compiling the package. If not empty, Zig
# will be added to BDEPEND and "zig-toolchain_populate_env_vars" will set
# ZIG_EXE variable in addition to other variables.
if [[ -n ${ZIG_SLOT} ]]; then
	BDEPEND+=" || (
		dev-lang/zig:${ZIG_SLOT}
		dev-lang/zig-bin:${ZIG_SLOT}
	)"
fi

# @FUNCTION: zig-toolchain_get_target
# @USAGE: <C-style target triple>
# @DESCRIPTION:
# Translates C-style target triple (like CHOST or CBUILD)
# to Zig-style target triple. Some information (like ARM features)
# is handled by "zig-toolchain_get_cpu".
#
# See ZIG_TARGET description for more information.
zig-toolchain_get_target() {
	[[ ${#} -eq 1 ]] || die "${FUNCNAME[0]}: exactly one argument must be passed"
	local c_target=${1}
	local c_target_prefix=${c_target%%-*}
	local c_target_suffix=${c_target##*-}

	local arch os abi

	case ${c_target_prefix} in
		i?86)	arch=x86;;
		arm64)	arch=aarch64;;
		arm*)	arch=arm;;
		*)	arch=${c_target_prefix};;
	esac

	case ${c_target} in
		*linux*)	os=linux;;
		*apple*)	os=macos;;
	esac

	case ${c_target_suffix} in
		solaris*)	os=solaris abi=none;;
		darwin*)	abi=none;;
		*)		abi=${c_target_suffix};;
	esac

	[[ ${arch} == arm && ${abi} == gnu ]] && die "${FUNCNAME[0]}: Zig does not support old ARM ABI"

	echo ${arch}-${os}-${abi}
}



# @FUNCTION: zig-toolchain_get_cpu
# @USAGE: <C-style target triple>
# @DESCRIPTION:
# Translates C-style target triple (like CHOST or CBUILD)
# to Zig-style target CPU and features. Mostly used for ARM features.
#
# See ZIG_CPU description for more information.
zig-toolchain_get_cpu() {
	[[ ${#} -eq 1 ]] || die "${FUNCNAME[0]}: exactly one argument must be passed"
	local c_target=${1}
	local c_target_prefix=${c_target%%-*}

	local base_cpu features=""

	case ${c_target_prefix} in
		i?86)		base_cpu=${c_target_prefix};;
		riscv32)	base_cpu=generic_rv32;;
		riscv64)	base_cpu=generic_rv64;;
		loongarch64)	base_cpu=generic_la64;;
		*)		base_cpu=generic;;
	esac

	case ${c_target_prefix} in
		armv5tel)	features+="+v5te";;
		armv*)		features+="+${c_target_prefix##armv}";;
	esac

	local is_softfloat=$(CTARGET=${c_target} tc-tuple-is-softfloat)
	case ${is_softfloat} in
		only | yes) features+="+soft_float";;
		softfp | no) features+="-soft_float";;
		*) die "${FUNCNAME[0]}: tc-tuple-is-softfloat returned unexpected value"
	esac

	echo ${base_cpu}${features}
}

# @FUNCTION: zig-toolchain_get_installation
# @DESCRIPTION:
# Returns detected Zig installation. Requires that ZIG_SLOT is set.
# See ZIG_EXE description for more information.
zig-toolchain_get_installation() {
	# Adapted from https://github.com/gentoo/gentoo/pull/28986
	# Many thanks to Florian Schmaus (Flowdalic)!

	[[ -n ${ZIG_SLOT} ]] || die "${FUNCNAME[0]}: ZIG_SLOT must be set"

	local candidate candidate_slot ver_in_suffix selected selected_slot

	for candidate in "${BROOT}"/usr/bin/zig-*; do
		# Don't need to set "extglob" explicitly here.
		# https://tiswww.case.edu/php/chet/bash/CHANGES
		# This document details the changes between this version, bash-4.1-alpha,
		# and the previous version, bash-4.0-release.
		# s.  Force extglob on temporarily when parsing the pattern argument to
		#     the == and != operators to the [[ command, for compatibility.
		if [[ ! -L "${candidate}" || "${candidate}" != */zig?(-bin)-+([0-9.]) ]]; then
			continue
		fi

		ver_in_suffix="${candidate##*-}"
		candidate_slot=$(ver_cut 1-2 ${ver_in_suffix})
		if ver_test "${candidate_slot}" -ne ${ZIG_SLOT}; then
			# Candidate does not satisfy ZIG_SLOT condition.
			continue
		fi

		selected="${candidate}"
		selected_slot="${candidate_slot}"
	done

	if [[ -z "${selected_slot}" ]]; then
		die "Could not find (suitable) Zig installation in '${BROOT}/usr/bin/'"
	fi

	local selected_ver
	selected_ver=$("${selected}" version || die "Failed to get version from '${selected}'")

	einfo "Found Zig version: ${selected_ver} (ebuild required ${ZIG_SLOT})"
	echo "${selected}"
}

# @FUNCTION: zig-toolchain_populate_env_vars
# @DESCRIPTION:
# Populates ZIG_TARGET, ZIG_CPU, and, if ZIG_SLOT is set, ZIG_EXE
# environment variables using user-defined or detected values.
zig-toolchain_populate_env_vars() {
	if [[ -z ${ZIG_TARGET} ]]; then
		if tc-is-cross-compiler; then
			export ZIG_TARGET=$(zig-toolchain_get_target ${CBUILD})
		else
			export ZIG_TARGET=native
		fi
	fi

	if [[ -z ${ZIG_CPU} ]]; then
		if tc-is-cross-compiler; then
			export ZIG_CPU=$(zig-toolchain_get_cpu ${CBUILD})
		else
			export ZIG_CPU=native
		fi
	fi

	if [[ -n ${ZIG_SLOT} ]]; then
		[[ -z "${ZIG_EXE}" ]] && export ZIG_EXE="$(zig-toolchain_get_installation)"
	fi

	einfo "ZIG_TARGET:  ${ZIG_TARGET}"
	einfo "ZIG_CPU:     ${ZIG_CPU}"
	einfo "ZIG_EXE:    \"${ZIG_EXE}\""
}

# @FUNCTION: ezig
# @USAGE: [<args>...]
# @DESCRIPTION:
# Runs ZIG_EXE with supplied arguments. Calls "die" if ZIG_EXE is not set,
# but does not call "die" if command itself failed.
# Always disables progress bar.
# By default enables ANSI escape codes (colours, etc.), set NO_COLOR
# environment variable to disable them.
ezig() {
	# Sync comments above and inside this function with "std.io.tty.detectConfig".

	if [[ -z "${ZIG_EXE}" ]] ; then
		die "${FUNCNAME[0]}: ZIG_EXE is not set. Was zig-toolchain_populate_env_vars called and ZIG_SLOT set?"
	fi

	# "[i] Semantic Analysis" and "steps [i/N] zig something something" are helpful
	# indicators in TTY, but unfortunately they pollute Portage logs.
	# We pass "TERM=dumb" here to have clean logs, and YES_COLOR to preserve colors.
	# User's NO_COLOR takes precendence over this.
	TERM=dumb YES_COLOR=1 "${ZIG_EXE}" "${@}"
}

fi
