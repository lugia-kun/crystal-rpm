#!/bin/bash

set -v

useradd -u $(stat -c %u spec/data/simple.spec) crystal || :
crystal version
crystal spec
