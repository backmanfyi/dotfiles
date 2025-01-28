#! /bin/bash
env=`tmux show-environment AWS_PROFILE 2>/dev/null | cut -d"=" -f2`
role=`tmux show-environment AWS_ROLE 2>/dev/null | cut -d"=" -f2`

# capitalize.. Looks better
env_cap=$(echo -n $env | tr "[:lower:]" "[:upper:]")
  
if [[ -z "$env_cap" ]]
then
  # Ugly, but if one is empty we can expect both to be that
  echo "<empty>,<empty>"
else
  echo "${env_cap},${role}"
fi

