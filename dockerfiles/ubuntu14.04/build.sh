#!/usr/bin/env bash

set -e pipefail

docker build -t docker.io/ncronquist/shell-install:ubuntu14.04 .
