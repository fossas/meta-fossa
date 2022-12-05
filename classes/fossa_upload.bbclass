inherit fossa_utils

addtask do_fossa_analyze before do_build after do_rootfs
do_fossa_analyze[doc] = "Analyze via fossa-cli"
do_fossa_analyze[nostamp] = "1"
do_fossa_analyze[depends] = "fossa-cli:do_populate_sysroot"

addtask do_fossa_test before do_build after do_fossa_analyze
do_fossa_test[doc] = "Test via fossa-cli"
do_fossa_test[nostamp] = "1"
do_fossa_test[deptask] += "fossa-cli:do_populate_sysroot"

python do_fossa_analyze() {
    if not is_fossa_enabled(d):
        bb.debug(1, "Since FOSSA_ENABLED is 0, skipping: fossa analyze")
        return

    staging_dir = d.getVar("FOSSA_STAGING_DIR") 
    if not staging_dir:
        bb.fatal("expected to have value for FOSSA_STAGING_DIR, but recieved Nothing")

    run_fossa_cli(d, mk_fossa_cmd(d, 'analyze'))
}

python do_fossa_test() {
    if not is_fossa_enabled(d):
        bb.debug(1, "Since FOSSA_ENABLED is 0, skipping: fossa test")
        return 

    if is_fossa_analyze_only(d):
        bb.debug(1, "Since FOSSA_ANALYZE_ONLY is 1, skipping: fossa test")
        return

    run_fossa_cli(d, mk_fossa_cmd(d, 'test'))
}

def run_fossa_cli(d, cli_args):
    import os
    import subprocess

    BINDIR = d.getVar("bindir")
    WORKDIR = d.getVar("WORKDIR")

    cli_path = (f"{WORKDIR}/recipe-sysroot{BINDIR}/fossa")
    cmds = [cli_path] + cli_args
    bb.plain(f"running: {' '.join(cmds)}")

    out = subprocess.run(cmds, cwd=d.getVar("FOSSA_STAGING_DIR"), capture_output=True, text=True, shell=False)
    if out.returncode != 0:
        bb.fatal(out.stderr)
    else:
        # fossa analyze summary is printed in stderr
        bb.plain(out.stderr)
        bb.plain(out.stdout)
