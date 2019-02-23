# crystal-rpm

The [RPM] bindings for [Crystal] language based on [ruby-rpm-ffi].

It supports RPM 4.8.0 or later.

## Installation

1. Add the dependency to your `shard.yml`:
```yaml
dependencies:
  rpm:
    github: lugia-kun/crystal-rpm
```
2. Run `shards install`

## Usage

```crystal
require "rpm"
```

The development files (pkg-config file) of [RPM] is
required. Typically, it can be installed by `yum install rpm-devel` on
CentOS or Red Hat, `dnf install rpm-devel` on Fedora, and `zypper in
rpm-devel` on openSUSE or SLES.

### Inspect package

```crystal
pkg = RPM::Package.open("foobar-1.0-0.x86_64.rpm")
puts pkg[RPM::Tag::Name] # => "foobar"
puts pkg[RPM::Tag::Arch] # => "x86_64"
puts pkg[RPM::Tag::Summary] # => (Content of Summary)
# and so on...

pkg.requires # => Array of Requires.
pkg.provides # => Array of Provides.
pkg.conflicts # => Array of Conflicts.
pkg.obsoletes # => Array of Obsolstes.
```

### Install package

```crystal
RPM.transaction do |ts|
  path = "pkg_to_install-1.0-0.x86_64.rpm"
  pkg = RPM::Package.open(path)
  begin
    ts.install(pkg, path) # Add installation package. Package path is required.
    ts.commit   # Run Transaction
  ensure
    ts.db.close # must close Database.
  end
end
```

### Remove package

Currently, the following code does not work unless you are using
OpenSUSE.

```crystal
RPM.transaction do |ts|
  begin
    ts.delete(pkg)
    ts.order    # Order and Clean is not mandatory.
    ts.clean
    ts.commit   # Run Transaction
  ensure
    ts.db.close # must close Database.
  end
end
```

## Development

The definitiions of structs are written by hand. Tests can check their
size and member offsets if you have a C compiler (optional).

[fakechroot] (recommended) or root permission (i.e., `sudo`) is
required to run `crystal spec`, since this spec uses `chroot()`.

Alternatively, using Docker is another method to test:

```
$ shards install
$ docker build -t [version] -f .travis/Dockerfile.rpm-[version] .
$ docker run -v $(pwd):/work -w /work [version] crystal spec
```

Note that shards should be installed on local (because git in CentOS 6
is too old and does not work with shards).

## Contributing

1. Fork it (<https://github.com/lugia-kun/crystal-rpm/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Hajime Yoshimori](https://github.com/lugia-kun) - creator and maintainer

[RPM]: http://rpm.org/
[Crystal]: https://crystal-lang.org/
[ruby-rpm-ffi]: https://github.com/dmacvicar/ruby-rpm-ffi
[fakechroot]: https://github.com/dex4er/fakechroot/wiki
