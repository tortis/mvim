# MVIM

A VIM-like editor for ComputerCraft (CC: Tweaked)

## Local development

Dependencies:
- java 17 (`sudo pacman -S jdk17-openjdk` and `sudo archlinux-java set java-17-openjdk`)

Run standalone cc computer. This will start a cc computer with it's root in the
current directory.
```bash
$ ./run.sh
```

Inside of the computer emulator open mvim
```shell
> vim vim.lua
```

## Re-building standalone

The standalone jar was built from https://github.com/cc-tweaked/CC-Tweaked

The patch in ./standalone/standalone-build.patch can be applied to which will
add a gradle task to build the jar for the standalone project. It also doubles
the font scaling on the emulator.

```bash
$ ./gradlew buildStandalone
```

```bash
rsync -av projects/core/src/main/resources ../mvim/standalone/
cp projects/standalone/build/libs/cc-tweaked-1.20.1-standalone-1.113.0-standalone.jar ../mvim/standalone/cc.jar
```
