#!/usr/bin/env bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

helm install gloo gloo/gloo \
  --create-namespace \
  --namespace gloo-system \
  -f "$DIR/values.yaml"
