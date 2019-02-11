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

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

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
