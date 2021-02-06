# crystal-rpm [![Crystal CI](https://github.com/lugia-kun/crystal-rpm/workflows/Crystal%20CI/badge.svg)](https://github.com/lugia-kun/crystal-rpm/actions?query=workflow%3A%22Crystal+CI%22)

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
can be compatible with MIT and Apache-2.0.

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

The development files (pkg-config file) of [RPM](https://rpm.org/) is
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
  pkg = ts.read_package_file(path)
  
  ts.install(pkg, path) # Add installation package. Package path is required.
  ts.commit   # Run Transaction
end
```

BTW, `RPM::Package.open` allocates a `Transaction` inside. So if you
have an instance of `Transaction` already,
`Transaction#read_package_file` reduces allocations.

### Search installed packages

```crystal
# with given name
RPM.transaction do |ts|
  ts.db_iterator(RPM::DbiTag::Name, "package-name-to-find") do |iter|
    iter.each do |pkg|
      # Iterator over matching packages.
    end
  end
end

# with given regexp
RPM.transaction do |ts|
  ts.db_iterator do |iter|
    # Set condition
    iter.regexp(RPM::DbiTag::Name, # <= Entry to search (here, Name)
                RPM::MireMode::REGEX, # <= Default matching method
                "simple.*") #  <= Name to search
    
    # Iterate over matching packages.
    iter.each do |pkg|
      puts pkg[RPM::Tag::Version].as(String) # => (Version of package "simple")
    end
  end
end

# Iterate over all installed packages
RPM.transaction do |ts|
  ts.db_iterator do |iter|
    iter.each do |pkg|
      # ... iterates over all installed packages.
    end
  end
end

# Lookup package(s) which contains a specific file
RPM.transaction do |ts|
  ts.db_iterator(RPM::DbiTag::BaseNames, "/path/to/lookup") do |iter|
    iter.each do |pkg|
      # ... iterates over packages contains "/path/to/lookup"
    end
  end
end

# NOTE: Using regexp with BaseNames, it will search packages which
# contain a file whose basename is the given name.
RPM.transaction do |ts|
  ts.db_iterator do |iter|
    iter.regexp(RPM::DbiTag::BaseNames, RPM::MireMode::STRCMP, "README")
    iter.each do |pkg|
      # ... iterates over packages which contain a file named "README"
    end
  end
end
```

### Remove package

```crystal
RPM.transaction do |ts|
  ts.delete(pkg) # Add to removal package
  ts.order
  ts.clean
  ts.commit   # Run Transaction
end
```

### Using Transaction without block

For installing and/or removing packages, the DB handle is bound to the
transaction. So, DB must be closed via transaction.

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

### Using DB iterator without block

For searching packages in DB, the DB handle is bound to the
iterator. So, DB must be closed via finalizing the iterator.

```crystal
ts = RPM::Transaction.new
begin
  iter = ts.init_iterator(...)
  begin
    iter.each do |item|
      # work with item
    end
  ensure
    iter.finalize # Must finalize iterator.
  end
end
ts.finalize
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
# Steps to be run.
#
# Here, %prep, %build, %install, %check, %clean and generates the source
# and binary packages.
#
amount = RPM::BuildFlags.flags(PREP, BUILD, INSTALL, CHECK, CLEAN,
  PACKAGESOURCE, PACKAGEBINARY)

# Read specfile
spec = RPM::Spec.open("foo.spec")
spec.build(build_amount: amount)
```

## Development

The definitions of structs are written by hand. Tests can check their
size and member offsets if you have a C compiler (optional).

[fakechroot](https://github.com/dex4er/fakechroot/wiki) (recommended),
[proot](https://proot-me.github.io/) (untested), or root permission
(i.e., `sudo`) is required to run `crystal spec`, since this spec uses
`chroot()`.

Alternatively, using Docker is another method to test:

```bash
     host$ shards install
     host$ docker build -t [version] -f .travis/Dockerfile.rpm-[version] .
     host$ docker run -it -v $(pwd):/work -w /work [version] ./.travis.sh
```

Or, manually,

```bash
     host$ shards install
     host$ docker build -t [version] -f .travis/Dockerfile.rpm-[version] .
     host$ docker run -it -v $(pwd):/work -w /work [version]
container# useradd -u $(stat -c %u spec/data/simple.spec) crystal || :
container# crystal spec [arguments]
container# exit
```

Notes:

* Git in CentOS 6 is too old and does not work with shards, so shards
  should be install on the local.
* In Fedora and CentOS, rpmbuild or rpmrc or rpmmacro files requires
  that the spec files must be owned by a valid user, when building
  RPMs.

## Contributing

1. Fork it (<https://github.com/lugia-kun/crystal-rpm/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Hajime Yoshimori](https://github.com/lugia-kun) - creator and maintainer
