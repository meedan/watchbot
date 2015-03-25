#!/bin/bash
echo "WatchBot Endpoints - `LANG=en_US date --utc`" > doc/api.txt
bundle exec rake routes | sed 's/.*\([PGD]\)/\1/g' | sed 's/(.:format).*//g' | grep -v Pattern | sort | nl >> doc/api.txt
