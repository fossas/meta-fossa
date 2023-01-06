# Integration Guide

## Explanation

The `meta-fossa` layer for Yocto integrates FOSSA CLI as a build step
inside the Yocto build system.

The `meta-fossa` layer does not actually alter the build,
but does need to be run as part of the Yocto build process
so that FOSSA can query Yocto for dependency and project information.

## Integration Steps

1. Clone Yocto (if not already cloned) and `meta-fossa`:

```bash
git clone git://git.yoctoproject.org/poky.git -b dunfell
git clone https://github.com/fossas/meta-fossa.git
```

2. Add `meta-fossa` to `build/conf/local.conf` by appending the following lines:

```bash
BBLAYERS += "<PATH-TO-META-FOSSA>"
INHERIT += "fossa"
FOSSA_API_KEY = "<VALID-FOSSA-API-KEY>"
```

3. Run the build:

```bash
cd poky
source oe-init-build-env
bitbake core-image-minimal
```

## Analysis

`meta-fossa` currently supports the following strategies:

| Strategy      | License            | Description        | Homepage           | Authors | Excludes unused packages | Vulnerability |
|---------------|--------------------|--------------------|--------------------|---------|--------------------------|---------------|
| `custom-deps` | :white_check_mark: | :white_check_mark: | :white_check_mark: | :x:     | :white_check_mark:       | :x:           |

More strategies are currently in active development.

### `custom-deps` strategy

In this strategy, the `fossa` class does the following:

1. Parses each recipe and persists JSON-ified recipe in `tmp/fossa_metadata/recipes/`.
2. Identifies runtime packages via `oe.rootfs.image_list_installed_packages`.
3. Correlates runtime packages to recipe and package's metadata using a similar approach as `scripts/oe-pkgdata-util`.
4. Forms `fossa-deps.json` file for all runtime packages
5. Performs `fossa analyze` and `fossa test`

By default, FOSSA classifies this build as the following project and revision:

- Project (in FOSSA): `${IMAGE_BASENAME}`
- Project Revision (in FOSSA): `${MACHINE}${IMAGE_VERSION_SUFFIX}`

The project name and project revision can be customized by overriding the `fossa analyze` and `fossa test` commands.
Please refer to [Options](#options) for more details.

## Options

These options are configured by adding the variable to `build/conf/local.conf`.

| Variable                         | Description                                                                                                                                       | Required           | Default                                                                                         |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|--------------------|-------------------------------------------------------------------------------------------------|
| FOSSA_API_KEY                    | The FOSSA API KEY.                                                                                                                                | :white_check_mark: | None                                                                                            |
| FOSSA_ENABLED                    | Whether to run FOSSA.                                                                                                                             | :x:                | `1`                                                                                             |
| FOSSA_TEST_ENABLED               | Whether to test the project for issues.                                                                                                           | :x:                | `1`                                                                                             |
| FOSSA_LICENSE_SCAN               | Whether to have FOSSA perform its own license scan of the dependencies ([reference](#perform-license-scan)).                                      | :x:                | `0`                                                                                             |
| FOSSA_INIT_DEPS_JSON             | Path to a custom `fossa-deps.json` to be read during analysis ([reference](#manually-include-some-dependencies-in-the-analysis)).                 | :x:                | None                                                                                            |
| FOSSA_CONFIG_FILE                | Path to `fossa.yml` ([reference](https://github.com/fossas/fossa-cli/blob/master/docs/references/files/fossa-yml.md)).                            | :x:                | None                                                                                            |
| FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS | Packages to exclude from final analysis ([reference](#exclude-dependencies-from-the-analysis)).                                                   | :x:                | None                                                                                            |
| FOSSA_RAW_ANALYZE_CMD            | Invoke `fossa-cli` with this argument string during the analysis step ([reference](#specify-custom-project-name-and-project-revision-for-fossa)). | :x:                | `analyze --fossa-api-key <API_KEY> -p ${IMAGE_BASENAME} -r "${MACHINE}${IMAGE_VERSION_SUFFIX}"` |
| FOSSA_RAW_TEST_CMD               | Invoke `fossa-cli` with this argument string during the test step ([reference](#specify-custom-project-name-and-project-revision-for-fossa)).     | :x:                | `test --fossa-api-key <API_KEY> -p ${IMAGE_BASENAME} -r "${MACHINE}${IMAGE_VERSION_SUFFIX}"`    |

### Specify custom project name and project revision for FOSSA

Override invocation of `analyze` and `test` commands like the following:

```conf
FOSSA_RAW_ANALYZE_CMD = "analyze -p <PROJECT> -r <REVISION> --fossa-api-key <KEY>"
FOSSA_RAW_TEST_CMD = "test -p <PROJECT> -r <REVISION> --fossa-api-key <KEY>"
```

When these options are used, they must include the following data:

- The FOSSA API key, via `--fossa-api-key <KEY>`.
- The project name, via `--project <PROJECT>` or `-p <PROJECT>`.
- The project revision, via `--revision <REVISION>` or `-r <REVISION>`.
- The path to `fossa.yml`, if one is used, via `--config <PATH>` or `-c <PATH>`.

Typically `meta-fossa` provides all of these arguments as required,
but it does not do so if `FOSSA_RAW_ANALYZE_CMD` or `FOSSA_RAW_TEST_CMD` are used.

If one command is customized, it is highly recommended to customize both;
many options (and especially `--fossa-api-key`, `--project`, and `--revision`) should match between the commands.

For more information on available options, see the following documentation:

- [Documentation: `fossa analyze`](https://github.com/fossas/fossa-cli/blob/master/docs/references/subcommands/analyze.md)
- [Documentation: `fossa test`](https://github.com/fossas/fossa-cli/blob/master/docs/references/subcommands/test.md)

### Manually include some dependencies in the analysis

There are scenarios in which it is desired to include additional
dependencies in the analysis. This is supported with a [fossa-deps.json](https://github.com/fossas/fossa-cli/blob/master/docs/features/manual-dependencies.md#manually-specifying-dependencies)
file.

For example, assuming the following file at `/home/user/example/fossa-deps-manual.json`:

```json
{
  "referenced-dependencies": [
    {
      "type": "gem",
      "name": "iron"
    },
    {
      "type": "pypi",
      "name": "Django",
      "version": "2.1.7"
    }
  ]
}
```

This path is then configured in `build/conf/local.conf`:

```conf
FOSSA_INIT_DEPS_JSON = "/home/user/example/fossa-deps-manual.json"
```

This results in the dependencies `iron` and `Django` being reported for the project,
along with any other dependencies detected during the `meta-fossa` layer.

### Exclude dependencies from the analysis

There are scenarios in which it is desired to omit reporting specific packages.
This is supported via the `FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS` option.

For example, to exclude `bash` and `curl` from the analysis,
this option is configured in `build/conf/local.conf`:

```conf
FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS = "bash curl"
```

This option is parsed as a list of space separated package names.
Any detected package that matches an entry in this option, _ignoring case_,
is omitted from the dependencies reported to FOSSA.

### Perform only analysis (disregard fossa test)

`fossa test` blocks the build if the licenses for third party dependencies
are incompatible with the policy set for this project in FOSSA.

For example, if the policy says "do not allow GPL code",
and dependencies contain GPL code, `fossa test` blocks the build.

Some teams may not wish to block builds on FOSSA test results,
either permanently or temporarily. This is supported via the `FOSSA_TEST_ENABLED` option.

This option is configured in `build/conf/local.conf`:

```conf
FOSSA_TEST_ENABLED = "0"
```

When set to `0`, the `meta-fossa` layer does not block the build on the
results of the FOSSA analysis.

### Perform license scan

By default, `fossa` relies on the licenses provided in the build recipes when reporting dependencies.
However, this relies on the entity creating the recipe to accurately report the license
of the code built by the recipe. This is not always reliable.

In order to handle this case better, FOSSA can perform its own license scanning of dependencies
instead of relying on the license reported by the recipe.

This option is configured in `build/conf/local.conf`:

```conf
FOSSA_LICENSE_SCAN = "1"
```

When set to `1`, the `meta-fossa` layer performs its own license scan on recipe source code
instead of relying on the license reported in the recipe.

Any patches are applied before inspecting the source for license data.
No source code is uploaded to the FOSSA servers.

Internally, FOSSA treats the source code referenced in the recipe
as "vendored dependencies"; for more information see the
[vendored dependencies feature documentation](https://github.com/fossas/fossa-cli/blob/master/docs/features/vendored-dependencies.md).

## Troubleshoot

If you are running into issues, please confirm the following:

### I've included a layer in my image build

```bash
bitbake-layers show-layers
```

You should see `meta-fossa` in stdout.

### I've inherited `fossa` in my image

Confirm by looking at `conf/local.conf` or relevant configurations.

### I've set valid `FOSSA_API_KEY`

To verify, confirm that at least one of the following methods was used to specify the API key.

- Via `FOSSA_API_KEY`

```bash
# e.g. bitbake -e core-image-minimal | grep "^FOSSA_API_KEY="
bitbake -e <IMAGE> | grep "^FOSSA_API_KEY="
```

- Via `FOSSA_RAW_ANALYZE_CMD` AND `FOSSA_RAW_TEST_CMD`

```bash
bitbake -e <IMAGE> | grep "^FOSSA_RAW_ANALYZE_CMD="
bitbake -e <IMAGE> | grep "^FOSSA_RAW_TEST_CMD="
```

- Via `FOSSA_CONFIG_FILE`

```bash
bitbake -e <IMAGE> | grep "^FOSSA_CONFIG_FILE="
# FOSSA_CONFIG_FILE=/some/path/fossa-config.yml

# >> cat /some/path/fossa-config.yml
# we should see the fossa-API-key set in the config file.
```

### I can reach the fossa endpoint: `https://app.fossa.com` via curl

```bash
curl -vv https://app.fossa.com
```

If you are still running into an issue, please provide stdout of `bitbake <image-base-name> -D`,
to the FOSSA support team, we can further investigate the issue for you.

## FAQ

### Why are vulnerabilities not supported?

FOSSA is actively developing and scoping a solution that will provide
reliable and accurate vulnerability detection for yocto image builds.

Currently, we are in process of identifying how to correlate patch accurately,
with CVE - and how to integrate within the FOSSA system, such that correction
workflows, as well as issues workflows, work seamlessly.

### How does FOSSA detect dependencies?

FOSSA only detects runtime dependencies of your yocto image build. It
does so by looking at `installed_packages` on rootfs.

### How can I report the defect?

You can report defect or feature request to the FOSSA team at https://support.fossa.com/hc/en-us

### How does it differ from the `create-spdx` class?

The `create-spdx` class was introduced in Yocto with version `3.4 (honister)`, which
does not work well for the current LTS release `dunfell`.

Further, `meta-fossa` is explicitly designed to work with FOSSA,
which brings support for license correction workflows, org and project-wide reporting,
notifications, and more.

### How do I apply a correction to incorrect license or package information?

You can do so via FOSSA WEB UI. Please refer to the documentation at: https://docs.fossa.com/docs/triaging-issues#remediating-issues
