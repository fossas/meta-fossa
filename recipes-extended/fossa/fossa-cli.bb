PN = "fossa-cli"
PKG_NAME = "fossa-cli"
PV = "3.6.0"

SUMMARY = "Flexible, performant dependency analysis"
HOMEPAGE = "https://fossa.com"
LICENSE = "MPL-2.0"
DEPENDS += "unzip-native"
INHIBIT_DEFAULT_DEPS = "1"

SRC_URI = "https://github.com/fossas/fossa-cli/archive/refs/tags/v${PV}.tar.gz"
SRC_URI[sha256sum] = "31eac60f057b191734f5b4cc9ffedc25f9a2726828ddad99e6392dc10d638e1c"
LIC_FILES_CHKSUM = "file://LICENSE;md5=815ca599c9df247a0c7f619bab123dad"
S = "${WORKDIR}/fossa-cli-${PV}"

inherit native

do_compile() {
    chmod a+x ${S}/install-latest.sh
    ${S}/install-latest.sh -b ${S} -d v3.6.0
}

do_install() {
    install -d ${D}${bindir}/
	install -m 0755 ${S}/fossa ${D}${bindir}/fossa
    install -m 0755 ${S}/fossa ${bindir}/fossa    
}

INSANE_SKIP_${PN} += "already-stripped"