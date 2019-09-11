# crystal-rpm

The [RPM](http://rpm.org/) bindings for
[Crystal](https://crystal-lang.org/) language based on
[ruby-rpm](https://github.com/dmacvicar/ruby-rpm) and
[ruby-rpm-ffi](https://github.com/dmacvicar/ruby-rpm-ffi).

It supports RPM 4.8.0 or later.

## Before use

RPM is licensed under [GNU GPL](https://rpm.org/about.html). This
means all libraries and applications which link to RPM must be
licensed under GNU GPL. But, Crystal (and standard libraries) are
licensed under Apache-2.0, which will be incompatible.

Actual `COPYING` file in source tarball of RPM says that library part
of RPM (i.e., `librpm`) is licensed under LGPL 2.0 or later too, which
can be compatible with MIT and, from LGPL 3.0, which they implicitly
allows to apply, Apache-2.0.

So currently, crystal-rpm is licensed under both [GPLv2 or
later](./COPYING) and [MIT](./LICENSE) (which should be compatible
with LGPL 2.0 and Apache-2.0). We are thinking you do not have a
chance to use this library under the conditions of GPLv2, but left to
let us to keep in mind.

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
  
  ts.install(pkg, path) # Add installation package. Package path is required.
  ts.commit   # Run Transaction
end
```

### Search installed packages

```crystal
# with given name
RPM.transaction do |ts|
  iter = ts.init_iterator(RPM::DbiTag::Name, "package-name-to-find")
  
  # You should make sure iterator has finalized (for closing database)
  begin
    iter.each do |pkg|
      # Iterator over matching packages.
    end
  ensure
    iter.finalize
  end
end

# with given regexp
RPM.transaction do |ts|
  iter = ts.init_iterator   # Create iterator of installed packages

  begin
    # Set condition
    iter.regexp(RPM::DbiTag::Name, # <= Entry to search (here, Name)
                RPM::MireMode::REGEX, # <= Default matching method
                "simple.*") #  <= Name to search
    
    # Iterate over matching packages.
    iter.each do |pkg|
      puts pkg[RPM::Tag::Version].as(String) # => (Version of package "simple")
    end
  ensure
    iter.finalize
  end
end

# Iterate over all installed packages
RPM.transaction do |ts|
  iter = ts.init_iterator
  begin
    iter.each do |pkg|
      # ... iterates over all installed packages.
    end
  ensure
    iter.finalize
  end
end

# Lookup package(s) which contains a specific file
RPM.transaction do |ts|
  iter = ts.init_iterator(RPM::DbiTag::BaseNames, "/path/to/lookup")
  begin
    iter.each do |pkg|
      # ... iterates over packages contains "/path/to/lookup"
    end
  ensure
    iter.finalize
  end
end

# NOTE: Using regexp with BaseNames, it will search packages which
# contain a file whose basename is the given name.
RPM.transaction do |ts|
  iter = ts.init_iterator
  begin
    iter.regexp(RPM::DbiTag::BaseNames, RPM::MireMode::STRCMP, "README")
    iter.each do |pkg|
      # ... iterates over packages which contain a file named "README"
    end
  ensure
    iter.finalize
  end
end
```

### Remove package

Currently, the following code does not work unless you are using
OpenSUSE (see #1).

```crystal
RPM.transaction do |ts|
  ts.delete(pkg) # Add to removal package
  ts.order
  ts.clean
  ts.commit   # Run Transaction
end
```

### Using Transaction without block

```crystal
ts = RPM::Transaction.new
begin
  ts.install(...)
  ts.delete(...)
  ts.order
  ts.clean
  ts.commit
ensure
  ts.close_db # Must close DB
end
ts.finalize # Not nesseary, but recommended.
```

### Install/Remove Problems

```crystal
RPM.transation do |ts|
  ts.install(...)
  ts.order
  ts.clean
  ts.check
  if (problems = ts.problems?)
    problems.each do |problem|
      puts problem.to_s # => Output install (typically dependency) problems.
    end
  end
end
```

### Inspect Specfile

```crystal
spec = RPM::Spec.open("foo.spec")
packages = spec.packages
packages[0][RPM::Tag::Name] # => (Name of the first package)
packages[1][RPM::Tag::Name] # => (Name of the second package)
# NOTE: The order is undefined.

spec.buildrequires # => Array of BuildRequires.
```

### Build RPM

```crystal
spec = RPM::Spec.open("foo.spec")
spec.build
```

## Development

The definitions of structs are written by hand. Tests can check their
size and member offsets if you have a C compiler (optional).

[fakechroot](https://github.com/dex4er/fakechroot/wiki) (recommended)
or root permission (i.e., `sudo`) is required to run `crystal spec`,
since this spec uses `chroot()`.

Alternatively, using Docker is another method to test:

```bash
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
