#!/usr/bin/env bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

helm install --dry-run gloo gloo/gloo \
  --namespace gloo-system \
  -f "$DIR/values.yaml"
