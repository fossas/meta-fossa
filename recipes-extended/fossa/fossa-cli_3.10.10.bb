# fossa-cli

SUMMARY = "Flexible, performant dependency analysis"
HOMEPAGE = "https://fossa.com"

LICENSE = "CPAL-1.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/CPAL-1.0;md5=4b571d5d786c50fbe70381b8c504be7d"

COMPATIBLE_HOST = "(x86_64|aarch64)"

FOSSA_ARCH = ""
FOSSA_ARCH:x86-64 = "amd64"
FOSSA_ARCH:aarch64 = "arm64"

FOSSA_SHA = ""
FOSSA_SHA:x86-64 = "0e4c91d803159615da0315eac3ee49ba574c0b4165c9f41d8672197a701680b8"
FOSSA_SHA:aarch64 = "15ba607a47ba333d5235c510ab80e21b1a1c7cf4610b7deef1e3984c24d4fabc"

FOSSA_DOWNLOAD_URI = "https://github.com/fossas/fossa-cli/releases/download"

SRC_URI = "${FOSSA_DOWNLOAD_URI}/v${PV}/fossa_${PV}_linux_${FOSSA_ARCH}.tar.gz;protocol=https;subdir=${BP}"
SRC_URI[sha256sum] = "${FOSSA_SHA}"

BBCLASSEXTEND += "native"

CLEANBROKEN = "1"

do_compile() {
    cp -a "${S}/fossa" "${WORKDIR}/fossa"
}

do_install() {
    install -d ${D}${bindir}/
    install -m 0755 ${WORKDIR}/fossa ${D}${bindir}/fossa
}

INSANE_SKIP:${PN} += "already-stripped"
