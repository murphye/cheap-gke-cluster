#!/usr/bin/env bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system
helm install istiod istio/istiod -n istio-system -f "$DIR/values-istiod.yaml"

kubectl create namespace istio-system

kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled
helm install istio-ingressgateway istio/gateway -n istio-ingress -f "$DIR/values-gateway.yaml"

