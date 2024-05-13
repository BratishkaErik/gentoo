# @ECLASS_VARIABLE: ZIG_OPTIMIZE_MODE
# @USER_VARIABLE
# @REQUIRED
# @DESCRIPTION:
# Zig optimize mode to use during building with ZBS. Limited to following options:
# * "none": Debug mode (similar to -Og in C, but with runtime safety checks).
# * "fast": ReleaseFast mode (similar to -O2 in C).
# * "small": ReleaseSmall mode (similar to -Os in C).
# * (Recommended) "safe": ReleaseSafe mode (ReleaseFast, but with runtime safety checks).
# * "upstream": Use whatever upstream prefers, will work **only if** upstream passed
# their "preferred_optimize_mode" to std.Build.standardOptimizeOption . **Do not set globally**,
# because it will **not compile** if upstream didn't chose preference.

# @FUNCTION: zig-toolchain_get_optimize_mode
# @DESCRIPTION:
# Outputs ZIG_OPTIMIZE_MODE in "Zig short" format, suitable for
# "--release=<short_form>" option in "zig build".
# Dies if ZIG_OPTIMIZE_MODE is empty.
zig-toolchain_get_optimize_mode() {
    [[ -n "${ZIG_OPTIMIZE_MODE}" ]] || die "${FUNCNAME[0]}: ZIG_OPTIMIZE_MODE must be set"

	case "${ZIG_OPTIMIZE_MODE}" in
	"none")
		echo "off";;
	"fast" | "small" | "safe")
		echo "${ZIG_OPTIMIZE_MODE}";;
	"upstream")
		echo "any";;
	*)
		eerror "Expected 'none', 'fast', 'small', 'safe' or 'upstream'"
		die "${FUNCNAME[0]}: invalid option: ${ZIG_OPTIMIZE_MODE}";;
	esac
}
