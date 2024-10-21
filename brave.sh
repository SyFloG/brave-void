#!/bin/sh

set -e

TEMPLATE='
# Template file for '\''brave-bin'\''
pkgname=brave-bin
version=${{VERSION}}
revision=1
archs="x86_64 aarch64"
short_desc="Chromium based browser with built in ad blocker, VPN & AI assistant"
maintainer="SyFloG <syflog@pm.me>"
hostmakedepends="tar xz"
license="Mozilla Public License Version 2.0"
homepage="https://brave.com"
nostrip=yes

case "${XBPS_TARGET_MACHINE}" in
	x86_64)
		_arch=amd64
		_hash="${{AMD64_HASH}}"
		;;
	aarch64)
		_arch=arm64
		_hash="${{ARM64_HASH}}"
		;;
esac

distfiles="https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_${_arch}.deb"
checksum=${_hash}

do_extract() {
    ar x ${XBPS_SRCDISTDIR}/${pkgname}-${version}/brave-browser_${version}_${_arch}.deb data.tar.xz
	tar -xf data.tar.xz
}

do_install() {
	vcopy usr /
	vcopy opt /

	# install icons
	for size in 24 32 48 64 128 256; do
        vmkdir /usr/share/icons/hicolor/${size}x${size}/apps
		vcopy opt/brave.com/brave/product_logo_${size}.png /usr/share/icons/hicolor/${size}x${size}/apps/brave-browser.png
    done
}
'

_usage()
{
	echo "USAGE: ${0} (build|install|update|update-check|clean)"
	exit 1
}

_get_latest_version()
{
	BRAVE_VERSION="$(wget -qO- https://api.github.com/repos/brave/brave-browser/releases/latest | jq '.tag_name')"
	BRAVE_VERSION="${BRAVE_VERSION#*v}"
	BRAVE_VERSION="${BRAVE_VERSION%\"*}"
}

_create_template()
{
	mkdir -p "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/"
	echo "${TEMPLATE}" > "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/template"

	_get_latest_version

	AMD64_HASH="$(wget -qO- https://github.com/brave/brave-browser/releases/download/v"${BRAVE_VERSION}"/brave-browser_"${BRAVE_VERSION}"_amd64.deb.sha256)"
	AMD64_HASH="${AMD64_HASH%%\ *}"
	ARM64_HASH="$(wget -qO- https://github.com/brave/brave-browser/releases/download/v"${BRAVE_VERSION}"/brave-browser_"${BRAVE_VERSION}"_arm64.deb.sha256)"
	ARM64_HASH="${ARM64_HASH%%\ *}"

	sed "s/\${{VERSION}}/${BRAVE_VERSION}/" -i "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/template"
	sed "s/\${{AMD64_HASH}}/${AMD64_HASH}/" -i "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/template"
	sed "s/\${{ARM64_HASH}}/${ARM64_HASH}/" -i "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/template"
}

_install_to_system()
{
	sudo xbps-install -y --repository="${BUILD_DIR}/void-packages/hostdir/binpkgs" brave-bin
}

_update_system_package()
{
	sudo xbps-install -uy --repository="${BUILD_DIR}/void-packages/hostdir/binpkgs" brave-bin
}

brave_build()
{
	if [ -f "${BUILD_DIR}/void-packages/.mark-done" ]; then
		echo "Brave already built, nothing to do."
		return
	fi

	mkdir -p "${BUILD_DIR}"

	if [ ! -f "${BUILD_DIR}/void-packages/.mark-cloned" ]; then
		if [ -d "${BUILD_DIR}/void-packages" ]; then
			rm -fdr "${BUILD_DIR}/void-packages"
		fi

		git clone --depth 1 https://github.com/void-linux/void-packages.git "${BUILD_DIR}/void-packages"
		touch "${BUILD_DIR}/void-packages/.mark-cloned"
	else
		cd "${BUILD_DIR}/void-packages"
		git clean -fd
		git pull
	fi

	_create_template

	cd "${BUILD_DIR}/void-packages"
	./xbps-src binary-bootstrap
	./xbps-src pkg brave-bin

	touch "${BUILD_DIR}/void-packages/.mark-done"
}

brave_update()
{
	if [ ! -f "${BUILD_DIR}/void-packages/.mark-done" ]; then
		brave_build
		_update_system_package
		return
	fi

	CURRENT_VERSION="$(sed -n '/^version=/p' "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/template")"
	CURRENT_VERSION="${CURRENT_VERSION#*=}"

	_get_latest_version

	if [ "${CURRENT_VERSION}" = "${BRAVE_VERSION}" ]; then
		echo "Brave up to date, nothing to do."
		return
	fi

	rm "${BUILD_DIR}/void-packages/.mark-done"
	brave_build
	_update_system_package
}

brave_update_check()
{
	if [ ! -f "${BUILD_DIR}/void-packages/.mark-done" ]; then
		echo "Nothing to check, brave not built."
		return 1
	fi

	CURRENT_VERSION="$(sed -n '/^version=/p' "${BUILD_DIR}/void-packages/srcpkgs/brave-bin/template")"
	CURRENT_VERSION="${CURRENT_VERSION#*=}"

	_get_latest_version

	if [ "${CURRENT_VERSION}" = "${BRAVE_VERSION}" ]; then
		echo "Brave up to date."
		return
	else
		echo "Brave update available (${CURRENT_VERSION} -> ${BRAVE_VERSION})."
	fi
}

brave_install()
{
	if [ ! -f "${BUILD_DIR}/void-packages/.mark-done" ]; then
		brave_build
	fi

	_install_to_system
}

brave_clean()
{
	if [ -d "${BUILD_DIR}" ]; then
		rm -fdr "${BUILD_DIR}"
	fi
}

BASE_DIR="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"
BUILD_DIR="${BASE_DIR}/builddir"

if [ -z "${1}" ]; then
	_usage
fi

if [ "${1}" = "build" ]; then
	brave_build
elif [ "${1}" = "install" ]; then
	brave_install
elif [ "${1}" = "update" ]; then
	brave_update
elif [ "${1}" = "update-check" ]; then
	brave_update_check
elif [ "${1}" = "clean" ]; then
	brave_clean
else
	_usage
fi
