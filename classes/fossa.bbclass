inherit fossa_utils

FOSSA_METADATA_RECIPES ??= "${TMPDIR}/fossa_metadata/recipes"
FOSSA_METADATA_PATCHED_SRC ??= "${TMPDIR}/fossa_metadata/src"
FOSSA_STAGING_DIR ??= "${TMPDIR}/fossa_metadata/staging"

addtask do_fossa_pkg after do_packagedata before do_rm_work
do_fossa_pkg[doc] = "Stores recipe metadata for future analysis"
do_fossa_pkg[nostamp] = "1"
do_fossa_pkg[rdeptask] += "do_unpack"
do_fossa_pkg[rdeptask] += "do_packagedata"

python do_fossa_pkg() {
    if not is_fossa_enabled(d):
        bb.debug(1, "Since FOSSA_ENABLED is 0, skipping: creating recipe parsing")
        return 

    import json

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

    metadata_dir = d.getVar('FOSSA_METADATA_RECIPES')
    bb.utils.mkdirhier(metadata_dir)

    try:
        metadata_file = os.path.join(metadata_dir, name + '.json')
        with open(metadata_file, 'w+') as mf:
            json.dump(metadata, mf, indent=4, sort_keys=True)
    except Exception as err:
        bb.error(f'failed to store metadata: {err}')
    else:
        bb.debug(1, f'succesfully persisted metadata for: {name}')
}

ROOTFS_POSTPROCESS_COMMAND += " do_fossa;"
do_rootfs[recrdeptask] += "do_fossa_pkg"
do_rootfs[recideptask] += "do_fossa_pkg"

python do_fossa() {
    if not is_fossa_enabled(d):
        bb.debug(1, "Since FOSSA_ENABLED is 0, skipping: creating fossa-deps.json")
        return 

    import errno
    import os
    import json
    import glob
    
    metadata_dir = d.getVar('FOSSA_METADATA_RECIPES')    
    pkg_metadata = get_pkg_metadata(d, metadata_dir)

    installed_pkgs = []
    for pkg in pkg_metadata:
        try:
            installed_pkgs.append(mk_user_dependencies(pkg_metadata[pkg]))
        except Exception as err:
            bb.error(f'failed to retrieve pkg metadata for {pkg} because: {err}')

    # Ensure path exists
    fossa_deps_dir = d.getVar("FOSSA_STAGING_DIR")
    bb.utils.mkdirhier(fossa_deps_dir)
    fossa_deps_path = os.path.join(fossa_deps_dir, 'fossa-deps.json')
    fossa_deps_raw = os.path.join(fossa_deps_dir, 'fossa-raw.json')

    # Make fossa-deps.json from installed pakckages,
    # provided initial deps file (if any), while excluding
    # deps provided in exclusion list.
    fossa_deps_dict = mk_fossa_deps(d, installed_pkgs)

    with open(fossa_deps_path, 'w+') as fd:
        json.dump(fossa_deps_dict, fd, indent=4, sort_keys=False)
    
    with open(fossa_deps_raw, 'w+') as fr:
        json.dump(pkg_metadata, fr, indent=4, sort_keys=False)
    
    bb.debug(1, "Wrote fossa-deps at: {fossa_deps_path}")
}

# Inlcude fossa_upload from this entrypoint
IMAGE_CLASSES_append = " fossa_upload"