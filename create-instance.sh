#!/usr/bin/env bash

set -eou pipefail

INSTANCE_NAME=$1
MACHINE_TYPE=${2:-n1-standard-1}

gcloud compute instances create $INSTANCE_NAME \
    --machine-type=$MACHINE_TYPE \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud
