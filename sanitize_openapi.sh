#!/bin/sh

sed -e 's/\(GET\|POST\|PUT\|DELETE\|PATCH\):/\L\0/g' openapi.yaml | tee openapi_sanitized.yaml
