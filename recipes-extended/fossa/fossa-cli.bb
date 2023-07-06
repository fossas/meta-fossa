
# These special variables control how BitBake builds the project.
#
# Reference: https://docs.yoctoproject.org/bitbake/2.2/bitbake-user-manual/bitbake-user-manual-ref-variables.html

PN = "fossa-cli"
PKG_NAME = "fossa-cli"
PV = "3.8.4"

SUMMARY = "Flexible, performant dependency analysis"
HOMEPAGE = "https://fossa.com"
LICENSE = "MPL-2.0"
INHIBIT_DEFAULT_DEPS = "1"
SRC_URI = "https://github.com/fossas/fossa-cli/archive/refs/tags/v${PV}.tar.gz;sha256sum=38ee6acd7ba96b0a53d458ae1c0f29308a6ca78a8802813293ff15aed8fccada;protocol=https \
    https://github.com/fossas/fossa-cli/releases/download/v${PV}/fossa_${PV}_linux_amd64.zip;sha256sum=18c2f7a4833f917b7ea9169fb827a2ca57f973dc47ccd79b67fd23cff127a567;protocol=https"

LIC_FILES_CHKSUM = "file://LICENSE;md5=815ca599c9df247a0c7f619bab123dad"
S = "${WORKDIR}/fossa-cli-${PV}"

inherit native

do_compile() {
    if [ "${BUILD_ARCH}" != "x86_64" ]; then
        echo "Host machine arch is ${BUILD_ARCH}, but fossa-cli requires: x86_64!"
        return 1
    fi
    cp ${WORKDIR}/fossa ${S}/fossa
}

do_configure() {
    echo "Nothing to configure for fossa-cli!"
}

do_install() {
    install -d ${D}${bindir}/
	install -m 0755 ${S}/fossa ${D}${bindir}/fossa
    install -m 0755 ${S}/fossa ${bindir}/fossa
}

INSANE_SKIP_${PN}:append = "already-stripped"
