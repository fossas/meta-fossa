def report_fossa_vars(d):
    """Prints state of FOSSA-specific variables."""

    # all fossa variables
    vars_list = [
        "FOSSA_ENABLED",
        "FOSSA_API_KEY",
        "FOSSA_ANALYZE_ONLY",
        "FOSSA_DEBUG",
        "FOSSA_OUTPUT",
        "FOSSA_INIT_DEPS_JSON",
        "FOSSA_CONFIG_FILE",
        "FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS",
        "FOSSA_RAW_ANALYZE_CMD",
        "FOSSA_RAW_TEST_CMD",
        "FOSSA_METADATA_RECIPES",
        "FOSSA_METADATA_PATCHED_SRC",
        "FOSSA_STAGING_DIR",
    ]

    for var in vars_list:
        is_truthy = False
        if d.getVar(var):
            is_truthy = True

        bb.debug(2, f"{var}: {d.getVar(var)} (isTruthy: {is_truthy}) ")


def is_fossa_enabled(d):
    """True, if FOSSA is enabled otherwise False."""

    if d.getVar("FOSSA_ENABLED") == "0":
        return False

    return True


def is_fossa_analyze_only(d):
    """True, if FOSSA_ANALYZE_ONLY or FOSSA_OUTPUT is enabled"""

    if d.getVar("FOSSA_ANALYZE_ONLY") == "1":
        return True

    return False


def has_fossa_yml_file(d):
    """True, if FOSSA_CONFIG_FILE exist and is readable."""

    import os

    if d.getVar("FOSSA_CONFIG_FILE"):
        fossa_yml = os.path.abspath(d.getVar("FOSSA_CONFIG_FILE"))
        bb.warn(f"{fossa_yml}")

        readable = os.path.isfile(fossa_yml) and os.access(fossa_yml, os.R_OK)

        if not readable:
            bb.warn(f"provided fossa config file is not readable: {fossa_yml}")

        return (readable, fossa_yml)

    return (False, None)


def mk_fossa_deps(d, deps):
    """Fossa Deps file dictionary from dependencies, and user supplied data.

    1. It reads FOSSA_INIT_DEPS_JSON if provided.
    2. It filters out, deps, if any match pkg provided in FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS
    3. It merges FOSSA_INIT_DEPS_JSON with custom-dependencies from deps.

    >> mk_fossa_deps(d, [{"name": "bat", "version": "0.0.1", "license": "MIT"}])

    {
        "custom-dependencies": [
            {
                "name": "bat",
                "version": "0.0.1",
                "license": "MIT"
            }
        ]
    }
    """

    import os
    import json

    # Retrieve user provided fossa-deps.json file
    fossa_deps = {}
    if d.getVar("FOSSA_INIT_DEPS_JSON"):
        fossa_deps_path = d.getVar("FOSSA_INIT_DEPS_JSON")
        if os.path.isfile(fossa_deps_path) and os.access(fossa_deps_path, os.R_OK):
            with open(fossa_deps_path, "r+") as f:
                fossa_deps = json.load(f)
                bb.debug(1, f"read fossa-deps, user supplied file from: {fossa_deps_path}")
        else:
            bb.warn(f"fossa-deps file does not exist or is not readable at: {fossa_deps_path}")

    # Identify packages to exclude
    excluded_pkgs = {}
    if d.getVar("FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS"):
        excluded = (d.getVar("FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS", True) or "").split()
        if excluded:
            bb.debug(1, f"indentified {len(excluded)} packages to exclude!")
        excluded_pkgs = {e.lower() for e in excluded}

    if "custom-dependencies" not in fossa_deps:
        fossa_deps["custom-dependencies"] = []

    # Add dependencies that are not in excluded list
    # as custom-dependencies
    for dep in deps:
        if dep.get("name", "").lower() in excluded_pkgs:
            bb.debug(1,f"skipping {dep['name']}, beacuse this dep is to excluded (per FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS)")
            continue

        fossa_deps["custom-dependencies"].append(dep)

    return fossa_deps


def get_pkg_metadata(d, recipe_metadata_dir):
    """Gets packages metadata for all installed packages

    It uses similar approach as `licese_image.bbclass` and `oe-pkgdata-util`.
    This is the same code, that is responisble for generating yocto's license.manifest.
    """
    import oe
    import os
    import glob
    import json

    # Read all the recipes metadata
    recipes = dict()
    recipe_files = glob.glob(os.path.join(recipe_metadata_dir, "*.json"))
    for recipe_file in recipe_files:
        rf = os.path.basename(recipe_file)
        recipe_name, _ = os.path.splitext(rf)
        try:
            with open(recipe_file, "r+") as f:
                recipe = json.load(f)
                recipes[recipe_name] = recipe
        except Exception as err:
            bb.error(f"failed to read metadata: {err}")
            continue

    # Retrieve installed packages and thier metadata. If we find,
    # responsible recipe, attach recipe metadata with the package
    pkg_dic = {}
    for pkg in sorted(oe.rootfs.image_list_installed_packages(d)):
        pkg_info = os.path.join(d.getVar("PKGDATA_DIR"), "runtime-reverse", pkg)
        pkg_name = os.path.basename(os.readlink(pkg_info))

        pkg_dic[pkg_name] = oe.packagedata.read_pkgdatafile(pkg_info)
        if not "LICENSE" in pkg_dic[pkg_name].keys():
            pkg_lic_name = "LICENSE_" + pkg_name
            pkg_dic[pkg_name]["LICENSE"] = pkg_dic[pkg_name][pkg_lic_name]

        recipe_name = pkg_dic[pkg_name]["PN"]
        pkg_dic[pkg_name]["recipe"] = recipes.get(recipe_name, {})

        # Sometimes package name is not same, as recipe name
        # nor same as PACKAGE attribute specified in recipe.
        # For example, libkmod2 vs libkmod.
        #
        # We do this so, findings matches that of generated  deploy/**/*.manifest file
        pkg_dic[pkg_name]["PKG_RAW_NAME"] = pkg

    return pkg_dic


def mk_user_dependencies(pkg_dict):
    """Creates custom-dependencies.

    It prefers package metadata over associated recipe metadata. For,
    revision it includes -release attribute.
    """

    def name():
        return pkg_dict["PKG_RAW_NAME"] or pkg_dict["PN"]

    def release():
        r = pkg_dict["PKGR"] or pkg_dict["PR"] or None
        return f"-{r}" if r else ""

    def version():
        return pkg_dict["PKGV"] or pkg_dict["PV"]

    def license():
        return pkg_dict["LICENSE"] or pkg_dict.get("recipe", {}).get("licenses", "")

    user_dependency = dict()
    user_dependency["name"] = name()
    user_dependency["version"] = version() + release()
    user_dependency["license"] = license()

    user_dependency["metadata"] = dict()
    if "recipe" in pkg_dict:
        if "description" in pkg_dict["recipe"] and pkg_dict["recipe"]["description"]:
            user_dependency["metadata"]["description"] = pkg_dict["recipe"][
                "description"
            ]

        if "homepage" in pkg_dict["recipe"] and pkg_dict["recipe"]["homepage"]:
            user_dependency["metadata"]["homepage"] = pkg_dict["recipe"]["homepage"]

    # if there was no homepage, or description
    # remove metadata attribute!
    if user_dependency["metadata"] == {}:
        del user_dependency["metadata"]

    return user_dependency


def mk_fossa_cmd(d, subcmd):
    """Makes fossa command and provides options.

    >> mk_fossa_cmd(d, 'analyze')
    analyze -p core-imagine-minimal -r x86-202201222 -c /path/to/fossa.yml --debug

    >> mk_fossa_cmd(d, 'test')
    test -p core-imagine-minimal -r x86-202201222 -c /path/to/fossa.yml --debug
    """
    if subcmd not in ["analyze", "test"]:
        raise ValueError(f"{subcmd} is not a valid fossa subcmd")

    # yocto specific project/revision instead of git
    project = d.getVar("IMAGE_BASENAME")
    revision = d.getVar("MACHINE") + d.getVar("IMAGE_VERSION_SUFFIX")
    fossa_api_key = d.getVar("FOSSA_API_KEY")

    # config file
    has_fossa_yml, fossa_yml = has_fossa_yml_file(d)

    # raw commands (escape hatch)
    rawcmd_analyze = (d.getVar("FOSSA_RAW_ANALYZE_CMD", True) or "").split()
    rawcmd_test = (d.getVar("FOSSA_RAW_TEST_CMD", True) or "").split()

    if subcmd == "analyze":
        if rawcmd_analyze:
            bb.debug(1, "using, raw analyze command provided: {rawcmd_analyze}")
            return rawcmd_analyze

        analyze_cmd = ["analyze", "-p", f"{project}", "-r", f"{revision}"]
        if has_fossa_yml:
            analyze_cmd.append("-c")
            analyze_cmd.append(fossa_yml)

        if fossa_api_key:
            analyze_cmd.append("--fossa-api-key")
            analyze_cmd.append(fossa_api_key)

        return analyze_cmd

    if subcmd == "test":
        if rawcmd_test:
            bb.debug(1, "using, raw test command provided: {rawcmd_test}")
            return rawcmd_test

        test_cmd = ["test", "-p", f"{project}", "-r", f"{revision}"]
        if has_fossa_yml:
            test_cmd.append("-c")
            test_cmd.append(fossa_yml)

        if fossa_api_key:
            test_cmd.append("--fossa-api-key")
            test_cmd.append(fossa_api_key)

        return test_cmd
