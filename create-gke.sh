#!/usr/bin/env bash

set -eou pipefail

CLUSTER=${1:-emqx}

gcloud container clusters create $CLUSTER
gcloud container clusters get-credentials $CLUSTER
