#!/usr/bin/env bash

# Copyright 2020 The Knative Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

source $(dirname $0)/../vendor/knative.dev/hack/codegen-library.sh
source "${CODEGEN_PKG}/kube_codegen.sh"

# If we run with -mod=vendor here, then the generators look for vendor files in the wrong place.
export GOFLAGS=-mod=

boilerplate="${REPO_ROOT_DIR}/hack/boilerplate/boilerplate.go.txt"

echo "=== Update Codegen for $MODULE_NAME"

# RabbitMQ uses Kubebuilder
# Kubebuilder project layout has API under 'api/v1beta1', ie. 'github.com/rabbitmq/messaging-topology-operator/api/v1beta1'
# client-go codegen expects group name (rabbitmq.com) in the path, ie. 'github.com/rabbitmq/messaging-topology-operator/api/rabbitmq.com/v1beta1'
# Because there's no way how to modify any of these settings, to enable client codegen,
# we need to reorganize things a little bit (copy to 'third_party/pkg/apis/rabbitmq.com/v1beta1')
rm -rf ${REPO_ROOT_DIR}/third_party/pkg/apis/rabbitmq.com
mkdir -p ${REPO_ROOT_DIR}/third_party/pkg/apis/rabbitmq.com
cp -R "${REPO_ROOT_DIR}/vendor/github.com/rabbitmq/messaging-topology-operator/api/v1beta1" ${REPO_ROOT_DIR}/third_party/pkg/apis/rabbitmq.com

group "Kubernetes Codegen"

# Deepcopy for our own API types (sources, eventing and the duck types).
kube::codegen::gen_helpers \
  --boilerplate "${boilerplate}" \
  "${REPO_ROOT_DIR}/pkg/apis"

# Client, lister and informer for our own API types.
kube::codegen::gen_client \
  --boilerplate "${boilerplate}" \
  --output-dir "${REPO_ROOT_DIR}/pkg/client" \
  --output-pkg "knative.dev/eventing-rabbitmq/pkg/client" \
  --with-watch \
  "${REPO_ROOT_DIR}/pkg/apis"

group "RabbitMQ Codegen"

# Generate our own RabbitMQ client (otherwise injection won't work).
# The deepcopy functions for the RabbitMQ types are copied from the upstream
# messaging-topology-operator vendor directory above, so only the client is
# generated here.
kube::codegen::gen_client \
  --boilerplate "${boilerplate}" \
  --output-dir "${REPO_ROOT_DIR}/third_party/pkg/client" \
  --output-pkg "knative.dev/eventing-rabbitmq/third_party/pkg/client" \
  --with-watch \
  "${REPO_ROOT_DIR}/third_party/pkg/apis"

group "Knative Codegen"

# Knative Injection
${KNATIVE_CODEGEN_PKG}/hack/generate-knative.sh "injection" \
  knative.dev/eventing-rabbitmq/pkg/client knative.dev/eventing-rabbitmq/pkg/apis \
  "sources:v1alpha1 duck:v1beta1 eventing:v1alpha1" \
  --go-header-file "${boilerplate}"

# Knative Injection for the RabbitMQ client
${KNATIVE_CODEGEN_PKG}/hack/generate-knative.sh "injection" \
  knative.dev/eventing-rabbitmq/third_party/pkg/client knative.dev/eventing-rabbitmq/third_party/pkg/apis \
  "rabbitmq.com:v1beta1" \
  --go-header-file "${boilerplate}"

group "Update deps post-codegen"

# Make sure our dependencies are up-to-date
${REPO_ROOT_DIR}/hack/update-deps.sh
