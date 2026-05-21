#!/bin/bash

tmux set-environment AWS_PROFILE "$(AWS_PROFILE='' aws-assume-role -q --print-exportable | cut -d'=' -f2)"
echo "export "$(tmux show-environment AWS_PROFILE)
