
# These special variables control how BitBake builds the project.
#
# Reference: https://docs.yoctoproject.org/bitbake/2.2/bitbake-user-manual/bitbake-user-manual-ref-variables.html

SUMMARY = "Flexible, performant dependency analysis"
HOMEPAGE = "https://fossa.com"
LICENSE = "MPL-2.0"
DEPENDS += "unzip-native"
INHIBIT_DEFAULT_DEPS = "1"
LIC_FILES_CHKSUM = "file://LICENSE;md5=815ca599c9df247a0c7f619bab123dad"
S = "${WORKDIR}/fossa-cli-${PV}"

inherit native

# Every BitBake recipe implicitly inherits `base.bbclass`: https://docs.yoctoproject.org/ref-manual/classes.html#base-bbclass
# This means that in addition to the tasks defined in this file, implicit tasks are defined.
# Refer to `meta/classes/base.bbclass` in Poky for the implementation of these implicit tasks
# and dependencies.
#
# In Dunfell, the following is the implicit task ordering:
# - addtask fetch
# - addtask unpack after do_fetch
# - addtask configure after do_patch
# - addtask compile after do_configure
# - addtask install after do_compile
# - addtask build after do_populate_sysroot
# - addtask cleansstate after do_clean
# - addtask cleanall after do_cleansstate
#
# An observant reader may have noticed that the `fossa` class is inherited in the quickstart,
# but nothing is explicitly added to depend on this `fossa-cli` recipe.
#
# The connection is in the `fossa_upload` class:
# 
# ```
# do_fossa_analyze[depends] = "fossa-cli:do_populate_sysroot"
# do_fossa_test[deptask] += "fossa-cli:do_populate_sysroot"
# ```
# 
# From the Yocto docs (https://docs.yoctoproject.org/ref-manual/tasks.html#do-populate-sysroot),
# `do_populate_sysroot` depends on the `do_install` task since it populates files from that task
# into the sysroot.
#
# In turn as we can see in the base class, `do_install` depends on `do_configure`,
# which depends on `fetch` which starts things off by pulling the `fossa-cli` bundle
# as part of the configuration step. Note: we delete the do_compile task here as 
# there is nothing to compile for this.
#
# While we specify populate_sysroot as the step to perform this, since we are a native
# recipe installing a binary to be run on the build host, the install phase is applied
# to sysroot-native.

# https://docs.yoctoproject.org/ref-manual/tasks.html#do-compile
#
# Implicitly, before this step is run, the `fetch` and `unpack` tasks are run.
# These ensure that the source at `SRC_URI` is present in `${S}`.
#
# This task downloads `fossa-cli` at the specified version to `${D}`.
# The version provided to the install script should match the version specified by `${PV}`.
do_configure() {
    chmod a+x ${S}/install-latest.sh
    ${S}/install-latest.sh -b ${S} -d v${PV}
}

do_compile[noexec] = "1"

# https://docs.yoctoproject.org/ref-manual/tasks.html#do-install
#
# Implicitly, before this step is run the `compile` task is run.
#
# This task installs the downloaded `fossa` binary to the BitBake binary directory
# for invocation.
do_install() {
    install -d ${D}${bindir}/
	install -m 0755 ${S}/fossa ${D}${bindir}/fossa
}

INSANE_SKIP_${PN} += "already-stripped"
