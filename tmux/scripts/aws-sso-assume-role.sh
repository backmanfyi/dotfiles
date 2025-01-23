#!/bin/bash

res=$(aws-sso-util login --profile $1 2>&1)

if [ $? -eq 0 ] || [ "$res" == "No AWS SSO config found" ] ; then
  identity=$(aws sts get-caller-identity --profile $1 | jq -r ".Arn" | awk -F'/' '{print $2}')
  if grep -q "_" <<< $identity; then
    role=$(echo $identity | awk -F '_' '{print $2}')
  else
    role=$identity
  fi
  echo "export AWS_PROFILE=${1}; export AWS_ROLE=${role}"
else
  echo "ERROR" >&2
  echo $res >&2
fi
