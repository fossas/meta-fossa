# Integeration Guide

## Quick Guide

```bash
RELEASE=dunfell
git clone git://git.yoctoproject.org/poky.git -b $RELEASE
git clone https://github.com/fossas/meta-fossa.git

# Activate yocto build environment
cd poky && source poky/oe-init-build-env

# Add meta-fossa layer in conf/local.conf
BBLAYERS += "${TOPDIR}/../meta-timesys"

# INHERIT fossa in conf/local.conf
INHERIT += "fossa"

# Specify FOSSA_API_KEY in conf/local.conf
FOSSA_API_KEY = "<VALID-FOSSA-API-KEY>"
```

Now, when you build your image, fossa will analyze and perform test on your build.

```bash
bitbake core-image-minimal
```

Output:

```bash

```

## Analysis

`meta-fossa`, currently supports following strategies:

| Strategy    | License            | Description        | Homepage           | Authors | Excludes unused packages | Vulnerability |
| ----------- | ------------------ | ------------------ | ------------------ | ------- | ------------------------ | ------------- |
| custom-deps | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x:     | :heavy_check_mark:       | :x:           |

More strategies are currently in active development.

### `custom-deps` strategy

In this strategy, `fossa` class does following:

1. Parses each recipe and persists JSON-ified recipe in `tmp/fossa_metadata/recipes/`.
2. Identifies runtime packages via `oe.rootfs.image_list_installed_packages`.
3. Correlates runtime packages to recipe and package's metadata using, similar approach as `scripts/oe-pkgdata-util`.
4. Forms `fossa-deps.json` file, for all runtime packages
5. Performs `fossa analyze` and `fossa test`

By default, FOSSA classifies this build as following project and revision:

- Project (in FOSSA): `${IMAGE_BASENAME}`
- Project Revision (in FOSSA): `${MACHINE}${IMAGE_VERSION_SUFFIX}`

This can be customized by overriding `fossa analyze` and `fossa test` command. Please refer to Options section for more details.

## Options

| Variable                         | Value                       | Description                                                                         |
| -------------------------------- | --------------------------- | ----------------------------------------------------------------------------------- |
| FOSSA_API_KEY                    | <APIKEY>                    | (Required) Your FOSSA API KEY.                                                      |
| FOSSA_ENABLED                    | 1                           | (Optional) FOSSA is enabled. This is the default behavior.                          |
| FOSSA_ENABLED                    | 0                           | (Optional) FOSSA is disabled. No analysis or test will be ran.                      |
| FOSSA_ANALYZE_ONLY               | 1                           | (Optional) No test will be ran, but analysis will be updated in FOSSA.              |
| FOSSA_ANALYZE_ONLY               | 0                           | (Optional) Fossa test will be performed. This is the default behavior.              |
| FOSSA_INIT_DEPS_JSON             | <PATH-TO-FOSSA-DEPS-JSON>   | (Optional) Path to `fossa-deps.json`, which should be used in analysis.             |
| FOSSA_CONFIG_FILE                | <PATH-TO-FOSSA-YML>         | (Optional) Path to `fossa.yml`, which to use during analysis and test.              |
| FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS | <SPACE-SEPARATED-PKGNAMES>  | (Optional) Packages to exclude from final analysis. Comparison is case-insensitive. |
| FOSSA_RAW_ANALYZE_CMD            | <ARGS> (e.g. `analyze ...`) | (Optional) Invoke `fossa-cli` with provided cmd args, during analysis step.         |
| FOSSA_RAW_TEST_CMD               | <ARGS> (e.g. `test ...`)    | (Optional) Invoke `fossa-cli` with provided cmd args, during test step.             |

### Specify custom project name and project revision for FOSSA

We can override invocation `analyze` and `test` command like following:

```conf
FOSSA_RAW_ANALYZE_CMD = "analyze -p myProject -r myRevision --fossa-api-key myApiKey"
FOSSA_RAW_TEST_CMD = "test -p myProject -r myRevision --fossa-api-key myApiKey"
```

When you do use `FOSSA_RAW_ANALYZE_CMD` and `FOSSA_RAW_TEST_CMD`, you will also need
to provide `FOSSA_API_KEY` and relevant config file manually in the command.

### Manually include some dependencies in analysis

Sometimes you may have scenario, where you want to include additional
dependencies in the analysis. We can do this via [fossa-deps.json](https://github.com/fossas/fossa-cli/blob/master/docs/features/manual-dependencies.md#manually-specifying-dependencies) file.

For example, we can create following `fossa-deps-manual.json` at some
path, e.g. `/home/user/example/fossa-deps-manual.json`.

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

Now, when we set this fossa-deps path to `FOSSA_INIT_DEPS_JSON`, fossa will include
`iron` and `Django` dependencies in the final analysis.

```conf
FOSSA_INIT_DEPS_JSON = "/home/user/example/fossa-deps-manual.json"
```

### Exclude dependencies from analysis

If for some reason, you want to exclude specific package from analysis,
and inclusion, you can use `FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS`.

For example to exclude `bash` and `curl` from analysis:

```conf
FOSSA_EXCLUDE_PKGS_FROM_ANALYSIS = "bash curl"
```

### Perform only analysis (disregard fossa test)

Some times, you may want to only perform analysis, and not
let your build FAIL fatally, if there are licensing issues.

You can do this so by setting `FOSSA_ANALYZE_ONLY` to `1`. Now,
fossa will perform `fossa analyze` command, but will skip `fossa test`.

```conf
FOSSA_ANALYZE_ONLY = "1"
```

## Troubleshoot

If you are running into issues, please confirm following:

1. I've included layer in the my image build

```bash
bitbake-layers show-layers
```

You should see `meta-fossa` in stdout.

2. I've inherited `fossa` in my image

Confirm by looking at `conf/local.conf` or relevant configurations.

3. I've set valid `FOSSA_API_KEY`

To verify, confirm at-least one of following method was used to specify the api key.

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
# we should see fossa-api-key set in the config file.
```

4. I can reach fossa endpoint: `https://app.fossa.com` via curl

```bash
curl -vv https://app.fossa.com
```

If you are still running into issue, please provide stdout of `bitbake <image-base-name> -D`,
to FOSSA support team, so we can further investigate the issue for you.

## FAQ

1. Why are vulnerabilities not supported ?

FOSSA is actively developing and scoping a solution that will provide
reliable and accurate vulnerability detection for yocto image builds.

Currently, we are in process of identifying how to accurately correlate patch,
with CVE - and how to integrate within FOSSA system, such that correction
workflows as well as issues workflows work seamlessly.

2. How does FOSSA detect dependencies?

FOSSA only detects runtime dependencies of your yocto image build. It
does so by looking at installed_packages on rootfs.

3. How can I report defect?

You can report defect or feature request to FOSSA team at https://support.fossa.com. We prefer
you use fossa's support portal instead of github Issues, as our support team can rapidly address
question and bugs.

4. How does it differ from `create-spdx` class?

`create-spdx` class was introduced in Yocto with version: `, which
does not work well for current LTS release: dunfell.

Further, `meta-fossa` is designed specifically to work with FOSSA
supporting license correction workflows, org/project wide reporting,
and notification etc.

5. How do I apply a correction to incorrect license or package information?

You can do so via FOSSA WEB UI. Please refer to documentation at: https://docs.fossa.com/docs/triaging-issues#remediating-issues
