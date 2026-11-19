#!/usr/bin/env bash
# Kotlin client (OkHttp + kotlinx.serialization) from the shared contract.
set -euo pipefail
cd "$(dirname "$0")"
npx --yes @openapitools/openapi-generator-cli@2.25.0 generate -i ../../openapi.yaml -g kotlin \
  -o generated --additional-properties=library=jvm-okhttp4,serializationLibrary=kotlinx_serialization,packageName=com.simpleappscompany.mytinyjungle.api
