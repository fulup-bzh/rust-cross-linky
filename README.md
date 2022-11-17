# Installing Rust

Unfortunately in development the simplest way to install RUST remains restup. It waist 1.5GB on your home directory and upload far more often than needed new updates. Nevertheless util you're not in production with long term support constrains it remains the simplest option.

 - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > sh.rustup.rs && bash ./sh.rustup.rs
 - source $HOME/.cargo/env
 - rustup update stable
 - rustup component add rust-src
 ** Note:** ~/.rustup easily uses 1.5G

Check rustc is visible in your shell environment
 - source $HOME/.cargo/env   ;# it is automatically added in your ~/.profile
 - rustc --print sysroot     ;# should point on ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu

# Rust and codium

Rust is well integrated within codium. Like often with vscode you have to double check you download the right extension. Obviously they is the old and new official one to confuse you.

 - install rust-analyzer extension
 - the extension should install automatically rust-analyzer server
 - in theory as soon as you open a rust.rs file the magic should work.

** Warning: ** until you open a rust.rs source file, the extension is dormant and ```cargo task``` not available. It open happen we you reopen a project and try to compile/debug without 1st opening your source code.

** During my test the extension did not set correct an execution right **

```
chmod +x $HOME/.config/VSCodium/User/globalStorage/matklad.rust-analyzer/rust-analyzer-x86_64-unknown-linux-gnu
```

# Compilation

## native: cargo build

If your desktop have a valid GCC tool chain, it should work out of box.

```
cargo build
```

## Cross compilation cross

Cross compilation with RUST imposes to have on top of Rust cross utilities corresponding GCC compiler/linker as well as a valid cross-sysroot that maches your target.

Major Linux distributions as :Fedora, OpenSuSE or Ubuntu maintain pre-build versions of cross-compilers. Unfortunately getting a valid cross-sysroot is rarely as simple. This especially when you do not use the same host and target distribution (i.e. fedora desktop with raspberry-pi target). Furthermore if you have target multiple targets you may also need multiple sysroot.

As a result you generally:

- may install required cross compiler through your preferred package management command (apt, zypper, dnf) without any further problem.
- should install cross-sysroot through a manual process
- *** Warning: *** Do not force installation of a package (rpm or deb) from an alien architecture/distribution manually. Installing two packages with the same name for two architectures is not supported by rpm/deb and will in most of the case lead to compromise or break your workstation. I strongly advise to install cross-sysroot without admin privileges. Not using root to install target cross-sysroot is a little more complex but it is the only way for not killing your development workstation through a simple --option mistake.


## Rust cross part

Installing the rust part of cross utilities is very simple. Select from proposed list the one you're interested in.

```
rustup target list
rustup target add aarch64-unknown-linux-gnu
```

## Sysroot cross part

If you're lucky a systoot for your target might be available from standard repositories as OpenSuSE/Raspberry. Unfortunately in most of the case your have to build your sysroot by hand as explained later with fedora/raspberry case.

## OpenSuse:

Luckily the community maintain through the OBS a full pre-built cross-dev repository that includes both cross compiler and corresponding cross-sysroot. You simply have to add corresponding repository to your development workstation and you're done. As today OpenSuSE:15.4 cross sysroot works out of the box with Raspberry:Debian-11, with future versions ?

```
zypper addrepo https://download.opensuse.org/repositories/Geckito:SDK:Main/15.4/Geckito:SDK:Main.repo
zypper install cross-aarch64-gcc11
```

Define which cross-linker Rust should use. Note that config.toml file may either be locate within your home or directly within your project directory. As your linker depends from your development workstation it is probably a good idea to host it more at $HOME than at project level.

```
cat  >$HOME/.cargo/config.toml <<EOF
[build]
# OpenSuSE default --sysroot for aarch64 compiler works fine
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-suse-linux-gcc"
EOF
```


## Fedora

Fedora only ship a pre-build cross-compiler and getting a valid sysroot for your target is more complex that it should. Depending on target you may choose to download the sysroot either from Fedora-aarch64 or Debian-aarch64 repository. In both case the sysroot config will probably not match 100% your cross compiler configuration and some manual tweaks as describe here after might be necessary.


### Install cross compiler

Cross compiler is available out of the box from Fedora repositories.

```
sudo dnf install gcc-aarch64-linux-gnu
```

### Prepare cross sysroot installation

As explain in the introduction. Installing a sysroot not pre-configure from your desktop is a ricky operation. I strongly advice to abandon admin/root privileges for this installation. For this will give sysroot directory to a standard user.

```
### Create sysroot in your preferred location
sudo mkdir -p /opt/aarch64-linux
sudo chown $LOGNAME /opt/aarch64-linux
```
You should download your sysroot from a distribution compatible with your target. When possible connect with ssh on your target and check installed packages version. As Debian repository mix architecture and patch version you should double check that you do not mess up and download a consistent set of packages to build your sysroot. The simplest way to find a version of libc6_xx that match libgcc-s1_zz is to directly check your target.

Get from your target sysroot version you should use
```
# define your target mdns name
MYTARGET=raspberry
ssh $MYTARGET.local dpkg -s libc6 | grep Version
ssh $MYTARGET.local dpkg -s libgcc-s1 | grep Version
```

### Download sysroot debian repository

Chose your preferred mirror from [debian-aarch64](https://www.debian.org/aarch64/list). Make sure you download the right version and architecture, as check in previous step.

```
cd /opt/aarch64-linux
aarch64=http://ftp.fr.debian.org/debian/pool
wget $aarch64/main/g/glibc/libc6_2.31-13%2Bdeb11u5_arm64.deb
wget $aarch64/main/g/glibc/libc6-dev_2.31-13%2Bdeb11u5_arm64.deb
wget $aarch64/main/g/gcc-10/libgcc-s1_10.2.1-6_arm64.deb
```

In order to avoid 'root' usage and make sure we do not execute any post-install script that could damage/kill or development workstation, let's extract files from debian packages manually.

```
# Manually extract sysroot from downloaded packages
cd /opt/aarch64-linux
for FILE in *.deb; do
  ar -p $FILE data.tar.xz | tar -Jxf -
done
rm *.deb
```

Debian packages are not designed to be compliant with --sysroot and without any post-install script few manual tweaks remain to be done.

```
# define your target mdns for ssh
MYTARGET=raspberry

# GNU ld scripts use share library, but some functions are only present within libgcc.a static library
echo "GROUP ( libgcc_s.so.1 -lgcc )" >./lib/aarch64-linux-gnu/libgcc_s.so

# libc.so matches sysroot from tool chain built-time --prefix and don't support about runtime --sysroot option. This error probably comes from the other rustc linker options order.
cat > ./usr/lib/aarch64-linux-gnu/libc.so <<EOF
OUTPUT_FORMAT(elf64-littleMIRROR)
GROUP ( /opt/aarch64-linux/lib/aarch64-linux-gnu/libc.so.6 )
GROUP ( /opt/aarch64-linux/usr/lib/aarch64-linux-gnu/libc_nonshared.a )
GROUP ( AS_NEEDED ( /opt/aarch64-linux/lib/ld-linux-aarch64.so.1 ) )
EOF

# Fix a link to share libpthread.so that is not compatible with --sysroot
rm ./usr/lib/aarch64-linux-gnu/libpthread.so
(cd lib/aarch64-linux-gnu; ln -s libpthread.so.0  libpthread.so)

# Retrieve gcc "specs" from the target to match sysroot directory structure
ssh $MYTARGET.local gcc -dumpspecs > gcc-$MYTARGET.specs
```

Finally define within config.toml gcc-linker and option rust should use.

```
cat  >$HOME/.cargo/config.toml <<EOF
[build]
# Fedora cross-compiler requires few extra options to accept a Debian sysroot.
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
rustflags = [
  "-C","link-args=--sysroot=/opt/aarch64-linux",
  "-C","link-args=-specs=/opt/aarch64-linux/gcc-$MYTARGET.specs",
  ]
EOF
```

#### Downloading sysroot from a RPM repository

Depending on your target you may prefer to start from a RPM repository. The logic remains the same. Check target architecture and version. Select your preferred aarch64. Download require packages and tweak the sysroot to work within your development context. Following script allows to extract RPM archive without root privilege.

```
# extract RPM without root admin privilege
for FILE in *rpm; do
    rpm2cpio $FILE | cpio -idv
done
```


### Optional linker flags.

Some rust packages may require a C/C++ recompilation. If needed install required packages dependencies to your cross-rootfs and PKG_CONFIG prefix should be set to match your sysroot configuration.

```
export PKG_CONFIG_SYSROOT_DIR=/opt/aarch64
```

Warning: before installing to many extra dependencies within your cross-sysroot check you realy need them. Some packages have optional features that are not useful and created useless extra dependencies. Example serial package by default pull usb-dev when you may not need it on your target.

```
[dependencies]
serialport = { version= "4.2.0", default-features = false }
```

### Start Cross-compilation

If you have the right cross compiler and a valid cross-sysroot everything should work smoothy.

```
clear && cargo build --target aarch64-unknown-linux-gnu
```

### Debug from codium/vscode IDE

Codium support Rust in cross mode through lldb/gdbserver. You need to setup a script to remove debug symbol from the object and copy striped binary on your target. This custom script should be called by codium before starting the debug session.

```Check .vscode launch.json and task.json for samples```

***Warning:*** Do not forget that at codium startup time "cargo task" is not available. You should open a rust file (main.rs) to prevent codium complaining when starting a debug session.

***Note:*** Rustc provides an "unpacked" mode to "split-debuginfo" profile option. Unfortunately I fail to get it to work with lldb/gdbserver