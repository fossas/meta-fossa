Inspired by [this post](https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html).

This is a hopefully useful guide to how this project works and where its various bits and pieces are.
Its goal is to get someone new up and running quickly when developing or reviewing this project.

The audience for this document is an engineer who:

* is interested in how the project currently works
* is onboarding onto working on this project
* is on-call and doing an urgent bugfix to this project
* is in the future, and is trying to understand why we made certain decisions

# Overview

The `meta-fossa` layer for Yocto integrates FOSSA CLI as a build step
inside the Yocto build system.

This layer does not actually alter the build,
but does need to be run as part of the Yocto build process
so that FOSSA can query Yocto for dependency and project information.

The information queried is then used to build `vendored-dependency`
and `custom-dependency` entries in a `fossa-deps.yml`,
which is then scanned by `fossa-cli`.

## Layers

Layers in Yocto are the preferred way to extend the build process.
From [the Yocto documentation](https://docs.yoctoproject.org/overview-manual/concepts.html#layers):

> Layers are repositories that contain related metadata (i.e. sets of instructions)
> that tell the OpenEmbedded build system how to build a target.
> [...] Layers logically separate information for your project.
> For example, you can use a layer to hold all the configurations for a particular piece of hardware.

Obviously, FOSSA is not building hardware; but we do use a layer so that we can keep the build steps required
to support `fossa-cli` separate from the rest of the build system and make us easy to plug in.

By convention, recipes have the following shape:

```
recipes-extended/
  <RECIPE-NAME>/
    <RECIPE-NAME>.bb

classes/
  <CLASS-1>.bbclass
  <CLASS-2>.bbclass
  <CLASS-N>.bbclass
```

A layer can have one or more recipes, and the recipes can depend upon the classes
(which can provide shared functionality for recipes).

# Code Map

_Items referenced in this map are referenced by name, but are intentionally not linked._
_Please use symbol search tools in your editor to find the named items._

## Recipes

### `fossa-cli`

The recipe for this layer, `fossa-cli` drives integrating FOSSA with the Yocto system.

Recipes provide implementations for pre-configured tasks ([reference](https://docs.yoctoproject.org/ref-manual/tasks.html#tasks)).
See the comments in the `fossa-cli` recipe for more details.

This recipe isn't directly included in the build; instead it is brought in via
a dependency declared by the `fossa_upload` class (explained below).

## Classes

### `fossa`

The `fossa` class is the primary interaction point for users
since they add it to their `INHERIT` directive.

It, in turn, inherits `fossa_upload` and `fossa_utils` into the build.
(These classes are explained below).

This class is responsible for interrogating Yocto and then using that information to
generate the `fossa-deps` file used by `fossa-cli` to report dependencies.

### `fossa_upload`

The `fossa_upload` class is the class that actually runs `fossa-cli`,
consuming the `fossa-deps.yml` and sending the corresponding dep graph to the FOSSA service.

This class depends on the `fossa-cli` recipe.

### `fossa_utils`

The `fossa_utils` class contains utility functions and is just directly imported
by other classes in this layer.
