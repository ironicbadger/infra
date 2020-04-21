#!/bin/bash
# sets up a pre-commit hook to ensure that vault.yaml is encrypted
# credit goes to nick busey from homelabos for this
cd ../../../
pwd
if [ -d .git/ ]; then
  echo test
  mkdir -p .git/hooks/ > /dev/null 2>&1
fi

