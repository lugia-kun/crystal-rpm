#!/bin/bash

set -v

useradd -u $1 crystal || :
crystal version
crystal spec
