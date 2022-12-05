![FOSSA](https://raw.githubusercontent.com/fossas/fossa-cli/master/docs/assets/header.png)
## `meta-fossa`

`meta-fossa`, analyzes and reports runtime packages of yocto image build to FOSSA.

## Table of Contents

1. Adding the meta-fossa layer to your build
2. Patches
3. Support

## Adding the meta-fossa layer to your build


1. Get `meta-fossa` layer

```bash
git clone https://github.com/fossas/meta-fossa.git
```

2. Add `meta-fossa` layer

```bash
cd poky && source poky/oe-init-build-env
bitbake add-layer ../.

# If you have persisted `meta-fossa` at some other location,
# bitbake add-layer <PATH-TO-META-FOSSA>
```

3. Inherit `fossa` into your image

```conf
INHERIT += "fossa"
```

4. Set `FOSSA_API_KEY`

```conf
FOSSA_API_KEY = "<VALID-FOSSA-API-KEY>"
```

Refer to [API Token](https://docs.fossa.com/docs/api-reference#api-tokens) documentation for more details.

5. Build your image! (done)

```bash
bitbake <IMAGE>

# example: bitbake core-image-minimal
```

Please refer to our [detailed guide](./GUIDE.md) for more information.

## Patches

Please submit any patches against the `meta-fossa` layer to this
repository. Contributions are welcome!

## Support

You can request from FOSSA's support team at https://support.fossa.com/hc/en-us 
