# objc-build-scripts

This project is a collection of scripts created with two goals:

 1. To standardize how Objective-C projects are bootstrapped after cloning
 1. To easily build Objective-C projects on continuous integration servers

## Scripts

Right now, there are two important scripts: [`bootstrap`](#bootstrap) and
[`cibuild`](#cibuild). Both are Bash scripts, to maximize compatibility and
eliminate pesky system configuration issues (like setting up a working Ruby
environment).

The structure of the scripts on disk is meant to follow that of a typical Ruby
project:

```
script/
    bootstrap
    cibuild
```

### bootstrap

This script is responsible for bootstrapping (initializing) your project after
it's been checked out. Here, you should install or clone any dependencies that
are required for a working build and development environment.

By default, the script will verify that [xctool][] is installed, then initialize
and update submodules recursively. If any submodules contain `script/bootstrap`,
that will be run as well.

To check that other tools are installed, you can set the `REQUIRED_TOOLS`
environment variable before running `script/bootstrap`, or edit it within the
script directly. Note that no installation is performed automatically, though
this can always be added within your specific project.

### cibuild

This script is responsible for building the project, as you would want it built
for continuous integration. This is preferable to putting the logic on the CI
server itself, since it ensures that any changes are versioned along with the
source.

By default, the script will run [`bootstrap`](#bootstrap), look for any Xcode
workspace or project in the working directory, then build all targets/schemes
(as found by `xcodebuild -list`) using [xctool][].

You can also specify the schemes to build by passing them into the script:

```sh
script/cibuild ReactiveCocoa-Mac ReactiveCocoa-iOS
```

As with the `bootstrap` script, there are several environment variables that can
be used to customize behavior. They can be set on the command line before
invoking the script, or the defaults changed within the script directly.

## Getting Started

To add the scripts to your project, read the contents of this repository into
a `script` folder:

```
$ git remote add objc-build-scripts https://github.com/jspahrsummers/objc-build-scripts.git
$ git fetch objc-build-scripts
$ git read-tree --prefix=script/ -u objc-build-scripts/master
```

Then commit the changes, to incorporate the scripts into your own repository's
history. You can also freely tweak the scripts for your specific project's
needs.

To merge in upstream changes later:

```
$ git fetch -p objc-build-scripts
$ git merge --ff --squash -Xsubtree=script objc-build-scripts/master
```

[xctool]: https://github.com/facebook/xctool
