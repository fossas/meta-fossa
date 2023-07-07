![FOSSA](https://raw.githubusercontent.com/fossas/fossa-cli/master/docs/assets/header.png)
## `meta-fossa`

`meta-fossa` analyzes and reports runtime packages of yocto image build to FOSSA.

## Quickstart

_For more details and configuration options, please refer to our [integration guide](./GUIDE.md)!_

```shell
# Check out the FOSSA layer.
; git clone https://github.com/fossas/meta-fossa.git -b dunfell

# Check out Yocto, if it isn't already.
; git clone git://git.yoctoproject.org/poky.git -b dunfell

# Activate yocto build environment
# This quickstart assumes the build env then moves CWD to `./build`.
; cd poky && source oe-init-build-env

# Add meta-fossa layer
; bitbake-layers add-layer ../../meta-fossa/
; echo 'BBLAYERS += "${TOPDIR}/../../meta-fossa"' >> conf/local.conf

# Inherit the fossa layer
; echo 'INHERIT += "fossa"' >> conf/local.conf

# Specify FOSSA API key
# Get one in your FOSSA account settings: https://app.fossa.com/account/settings/integrations/api_tokens
; echo 'FOSSA_API_KEY = "<VALID-FOSSA-API-KEY>"' >> conf/local.conf

# Build your image!
; bitbake core-image-minimal
```

The build logs report the URL at which the FOSSA project can be viewed:
```shell
[ INFO] Using project name: `core-image-minimal`
[ INFO] Using revision: `qemux86-64-20230103233003`
[ INFO] Using branch: `dunfell`
[ INFO] ============================================================
[ INFO]
[ INFO]     View FOSSA Report:
[ INFO]     https://app.fossa.com/projects/<YOUR-PROJECT-URL-HERE>
[ INFO]
[ INFO] ============================================================
```

If there are issues, the image build is prevented with an error:
```shell
[ERROR] ----------
  An issue occurred

  >>> Relevant errors

    Error

      The scan has revealed issues. Number of issues found: 19

      Traceback:
        (none)

NOTE: Tasks Summary: Attempted 3385 tasks of which 3142 didn't need to be rerun and 1 failed.

Summary: 1 task failed:
  <PATH-TO-REPO>/meta/recipes-core/images/core-image-minimal.bb:do_fossa_test
Summary: There was 1 WARNING message shown.
Summary: There was 1 ERROR message shown, returning a non-zero exit code.
```

This test functionality can be disabled if desired; see the [integration guide](./GUIDE.md#perform-only-analysis-disregard-fossa-test)
for more details.

## FAQ & Troubleshooting

- For FAQ, please refer to the [FAQ here](./GUIDE.md#faq)
- For troubleshooting, please refer to the [troubleshooting guide here](./GUIDE.md#troubleshoot).

## Patches

Please submit any patches against the `meta-fossa` layer to this
repository. Contributions are welcome!

This layer maintainer can be contacted at support@fossa.com, or via github issues.
**Please only use issues or direct emails for code related questions; for general support please see [support](#support).**

## Support

You can request from FOSSA's support team at https://support.fossa.com/hc/en-us
