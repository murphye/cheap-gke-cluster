#!/usr/bin/env bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update