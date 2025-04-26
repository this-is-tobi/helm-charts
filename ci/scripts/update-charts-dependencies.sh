#!/bin/bash

for chart in $(ls ./charts); do
  helm dependency update ./charts/$chart
done
