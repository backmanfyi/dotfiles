#! /bin/bash
env=`tmux show-environment AWS_PROFILE 2>/dev/null | cut -d"=" -f2 | awk -F'-' '{$1=$NF=""; print $0}'`
role=`tmux show-environment AWS_PROFILE 2>/dev/null | cut -d"=" -f2 | awk -F'-' '{print $NF}'`

# capitalize.. Looks better
env_cap=$(for i in $env; do C=`echo -n "${i:0:1}" | tr "[:lower:]" "[:upper:]"`; echo -n "${C}${i:1} "; done | sed 's/ *$//g')
  
if [[ -z "$env_cap" ]]
then
  # Ugly, but if one is empty we can expect both to be that
  echo "<empty>,<empty>"
else
  echo "${env_cap},${role}"
fi

