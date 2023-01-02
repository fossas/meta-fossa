# Integration Guide

## Quick Guide

```bash
git clone git://git.yoctoproject.org/poky.git -b dunfell
git clone https://github.com/fossas/meta-fossa.git

# Activate yocto build environment
cd poky && source poky/oe-init-build-env

# Add meta-fossa layer in conf/local.conf
BBLAYERS += "${TOPDIR}/../meta-fossa"

# INHERIT fossa in conf/local.conf
INHERIT += "fossa"

# Specify FOSSA_API_KEY in conf/local.conf
FOSSA_API_KEY = "<VALID-FOSSA-API-KEY>"
```

When you build your image, fossa will analyze and test your build.

```bash
bitbake core-image-minimal
```

## Analysis

`meta-fossa` currently supports the following strategies:

| Strategy    | License            | Description        | Homepage           | Authors | Excludes unused packages | Vulnerability |
| ----------- | ------------------ | ------------------ | ------------------ | ------- | ------------------------ | ------------- |
| custom-deps | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x:     | :heavy_check_mark:       | :x:           |

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

The default project name, and project revision can be customized by overriding the `fossa analyze` and `fossa test` commands. Please refer to the Options section for more details.

## Options

| Variable                         | Value                       | Description                                                                         |
| -------------------------------- | --------------------------- | ----------------------------------------------------------------------------------- |
| FOSSA_API_KEY                    | `API-KEY`                   | (Required) Your FOSSA API KEY.                                                      |
| FOSSA_ENABLED                    | `1`                         | (Optional) FOSSA is enabled. This is the default behaviour.                         |
| FOSSA_ENABLED                    | `0`                         | (Optional) FOSSA is disabled. No analysis or test will run.                         |
| FOSSA_ANALYZE_ONLY               | `1`                         | (Optional) No test will run, but the analysis will be updated in FOSSA.             |
| FOSSA_ANALYZE_ONLY               | `0`                         | (Optional) Fossa test will be performed. This is the default behaviour.             |
| FOSSA_INIT_DEPS_JSON             | `PATH-TO-FOSSA-DEPS-JSON`   | (Optional) Path to `fossa-deps.json`, which should be used in analysis.             |
| FOSSA_CONFIG_FILE                | `PATH-TO-FOSSA-YML`         | (Optional) Path to `fossa.yml`, which to use during analysis and test.              |
| FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS | `SPACE-SEPARATED-PKGNAMES`  | (Optional) Packages to exclude from final analysis. Comparison is case-insensitive. |
| FOSSA_RAW_ANALYZE_CMD            | `ARGS` (e.g. `analyze ...`) | (Optional) Invoke `fossa-cli` with provided cmd args, during the analysis step.     |
| FOSSA_RAW_TEST_CMD               | `ARGS` (e.g. `test ...`)    | (Optional) Invoke `fossa-cli` with provided cmd args during the test step.          |

### Specify custom project name and project revision for FOSSA

We can override invocation `analyze` and `test` commands like the following:

```conf
FOSSA_RAW_ANALYZE_CMD = "analyze -p myProject -r myRevision --fossa-api-key myApiKey"
FOSSA_RAW_TEST_CMD = "test -p myProject -r myRevision --fossa-api-key myApiKey"
```

When you do use `FOSSA_RAW_ANALYZE_CMD` and `FOSSA_RAW_TEST_CMD`, you will also need
to provide `FOSSA_API_KEY` and the relevant config file manually in the command.

### Manually include some dependencies in the analysis

Sometimes you may have a scenario where you want to include additional
dependencies in the analysis. We can do this via [fossa-deps.json](https://github.com/fossas/fossa-cli/blob/master/docs/features/manual-dependencies.md#manually-specifying-dependencies) file.

For example, we can create the following `fossa-deps-manual.json` at some
path, e.g. `/home/user/example/fossa-deps-manual.json`.

```JSON
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

Now, when we set this fossa-deps path to `FOSSA_INIT_DEPS_JSON`, fossa will include
`iron` and `Django` dependencies in the final analysis.

```conf
FOSSA_INIT_DEPS_JSON = "/home/user/example/fossa-deps-manual.json"
```

### Exclude dependencies from the analysis

If for some reason, you want to exclude a specific package from the analysis,
and inclusion, you can use `FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS`.

For example, to exclude `bash` and `curl` from the analysis:

```conf
FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS = "bash curl"
```

`meta-fossa` performs a case-insensitive match between the installed package and
package from `FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS`. The package
will be excluded from the analysis if there is a match.

### Perform only analysis (disregard fossa test)

Sometimes, you may want only to perform analysis and not
let your build FAIL if there are licensing issues.

You can do this so by setting `FOSSA_ANALYZE_ONLY` to `1`. Now,
fossa will perform the `fossa analyze` command but will skip the `fossa test`.

```conf
FOSSA_ANALYZE_ONLY = "1"
```

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
does so by looking at installed_packages on rootfs.

### How can I report the defect?

You can report defect or feature request to the FOSSA team at https://support.fossa.com/hc/en-us

### How does it differ from the `create-spdx` class?

`create-spdx` class was introduced in Yocto with version: `3.4 (honister)`, which
does not work well for the current LTS release: `dunfell`.

Further, `meta-fossa` is explicitly designed to work with FOSSA,
which brings support for license correction workflows, org and project-wide reporting,
notifications, and more.
### How do I apply a correction to incorrect license or package information?

You can do so via FOSSA WEB UI. Please refer to the documentation at: https://docs.fossa.com/docs/triaging-issues#remediating-issues
