#! /bin/bash
jq -R 'split(".") | .[0] | @base64d | fromjson' <<<"$1"
jq -R 'split(".") | .[1] | @base64d | fromjson' <<<"$1"
