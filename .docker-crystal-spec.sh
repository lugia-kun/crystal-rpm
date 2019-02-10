#!/bin/bash

set -ev

curl https://dist.crystal-lang.org/rpm/setup.sh | bash
yum install -y rpm-devel crystal

crystal spec
