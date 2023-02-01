def report_fossa_vars(d):
    """Prints state of FOSSA-specific variables."""

    # all fossa variables
    vars_list = [
        "FOSSA_ENABLED",
        "FOSSA_API_KEY",
        "FOSSA_TEST_ENABLED",
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


def is_fossa_test_enabled(d):
    """True if FOSSA_TEST_ENABLED"""

    if d.getVar("FOSSA_TEST_ENABLED") == "1":
        return True

    return False

def is_fossa_license_scan_enabled(d):
    """True if FOSSA_LICENSE_SCAN"""

    if d.getVar("FOSSA_LICENSE_SCAN") == "1":
        return True

    return False

def is_fossa_debug_enabled(d):
    """True if FOSSA_DEBUG"""

    if d.getVar("FOSSA_DEBUG") == "1":
        return True

    return False

def is_fossa_output_enabled(d):
    """True if FOSSA_OUTPUT"""

    if d.getVar("FOSSA_OUTPUT") == "1":
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


def mk_fossa_deps(d, deps, pkg_metadata):
    """FOSSA Deps file dictionary from dependencies, and user supplied data.

    1. It reads FOSSA_INIT_DEPS_JSON if provided.
    2. It filters any deps with a name matching matching one provided in FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS
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

    If the current run is using FOSSA license scanning,
    vendored dependencies are created instead of custom dependencies.
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

    # Having empty arrays doesn't hurt, just add both to make it simpler.
    if "custom-dependencies" not in fossa_deps:
        fossa_deps["custom-dependencies"] = []
    if "vendored-dependencies" not in fossa_deps:
        fossa_deps["vendored-dependencies"] = []

    # Add dependencies that are not in excluded list.
    patched_src_dir = d.getVar('FOSSA_METADATA_PATCHED_SRC')
    for dep in deps:
        name = dep['name']

        if name.lower() in excluded_pkgs:
            bb.debug(1,f"skipping {dep['name']}, because this dep is to excluded (per FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS)")
            continue

        if is_fossa_license_scan_enabled(d):
            # Some packages are built from a recipe with a different name, and source code is stored by recipe.
            # Use the package metadata to look up the original recipe name,
            # so that the source code directory can be determined.
            src_dir = ''
            for pkg in pkg_metadata:
                meta = pkg_metadata[pkg]
                meta_name = meta['PKG_RAW_NAME']
                if meta_name == name:
                    recipe = meta['recipe']
                    recipe_name = recipe['name']
                    src_dir = source_output_path(patched_src_dir, recipe_name)
                    break

            # As a failsafe, only generate a vendored-dependency if the source dir actually exists.
            if src_dir and os.path.exists(src_dir):
                vendored_dep = mk_vendored_dependency(dep, src_dir)
                fossa_deps["vendored-dependencies"].append(vendored_dep)
                continue
            else:
                bb.warn(f"""source for package "{name}" not captured, falling back to build-provided metadata.
                This may be a bug with the "meta-fossa" layer, please refer to our troubleshooting guide at
                https://github.com/fossas/meta-fossa/blob/master/GUIDE.md#troubleshoot""")
        
        # As a default fallback, use build-provided metadata.
        fossa_deps["custom-dependencies"].append(dep)

    return fossa_deps

def copy_src(d, metadata):
    """
    Writes the source code in the current context to the output directory.
    The output directory is `{FOSSA_METADATA_PATCHED_SRC}/{RECIPE_NAME}`.
    """

    import shutil

    src_dir = d.getVar('S')
    patched_src_dir = d.getVar('FOSSA_METADATA_PATCHED_SRC')
    name = metadata['name']

    dst_dir = source_output_path(patched_src_dir, name)
    bb.utils.mkdirhier(dst_dir)

    try:
        oe.path.copytree(src_dir, dst_dir)
    except Exception as err:
        bb.error(f'failed to copy source from "{src_dir}" to "{dst_dir}": {err}')
    else:
        bb.debug(1, f'succesfully copied source for: {name}')

def write_metadata(d, metadata):
    """
    Writes the provided metadata to the output directory.
    The output directory is extracted from the provided context (`d`).
    """

    import json

    metadata_dir = d.getVar('FOSSA_METADATA_RECIPES')
    name = metadata['name']
    bb.utils.mkdirhier(metadata_dir)

    try:
        metadata_file = metadata_output_file_path(metadata_dir, name)
        with open(metadata_file, 'w+') as mf:
            json.dump(metadata, mf, indent=4, sort_keys=True)
    except Exception as err:
        bb.error(f'failed to store metadata: {err}')
    else:
        bb.debug(1, f'succesfully persisted metadata for: {name}')

def metadata_output_file_path(dir, name):
    return os.path.join(dir, name + '.json')

def source_output_path(dir, name):
    return os.path.join(dir, name)

def pkg_metadata(d):
    """ Gets package metadata for the currently active package.
    """

    # Recipe name or a resulting package name
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-PN
    name = d.getVar('PN')
    
    # Version of the recipe. This is by default, version of the released package (PKGV).
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-PV
    version = d.getVar('PV')
    
    # Version of the package. This is by default, same as recipe version (PV).
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-PKGV
    pkg_version = d.getVar('PKGV')

    # Website where more information about the software built from recipe can be found.
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-HOMEPAGE
    homepage = d.getVar("HOMEPAGE")
    
    # The list of source licenses for the recipe.
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-LICENSE
    licenses = d.getVar("LICENSE")
    
    # Summary of the package, which might be used by packaging system (e.g. rpm)
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-SUMMARY
    summary = d.getVar("SUMMARY")
    
    # The description used by package managers. Preferred over `summary`.
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-DESCRIPTION
    description = d.getVar("DESCRIPTION")

    # The list of packages the recipe creates.
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-PACKAGES
    packages = (d.getVar("PACKAGES") or "").split()
    
    # The list of source files — local or remote.
    # Ref: https://docs.yoctoproject.org/bitbake/2.2/bitbake-user-manual/bitbake-user-manual-ref-variables.html#term-SRC_URI
    src_uri = (d.getVar('SRC_URI', True) or "").split()

    # The path of the recipe.
    # Ref: https://docs.yoctoproject.org/ref-manual/variables.html#term-FILE
    recipe_path = d.getVar("FILE")
    recipe_layer = bb.utils.get_file_layer(recipe_path, d) or '.'

    metadata = {
        'name': name,
        'version': version,
        'pkg_version': pkg_version,
        'packages': packages,
        'homepage': homepage,
        'licenses': licenses,
        'summary': summary,
        'description': description,
        'src_uri': src_uri,
        'recipe': recipe_path,
        'layer': recipe_layer,
    }

    return metadata

def all_pkg_metadata(d, recipe_metadata_dir):
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

    # Retrieve installed packages and their metadata. If we find,
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

def mk_vendored_dependency(user_dependency, src_dir):
    """
    Converts a custom-dependency as returned by mk_user_dependencies
    into a vendored-dependency referencing the provided source code directory.
    """

    name = user_dependency['name']
    version = user_dependency['version']

    vendored_dependency = dict()
    vendored_dependency['name'] = name
    vendored_dependency['version'] = version
    vendored_dependency['path'] = src_dir
    return vendored_dependency

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

        if is_fossa_debug_enabled(d):
            analyze_cmd.append('--debug')

        if is_fossa_output_enabled(d):
            analyze_cmd.append('--output')

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
