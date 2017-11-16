#!/bin/bash
appExists = `pgrep httpd`
if [[ -n $appExists ]]; then
    service httpd stop
fi
