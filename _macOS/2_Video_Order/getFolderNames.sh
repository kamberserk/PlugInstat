#!/bin/bash
ls -d */ | sed 's#/##' | awk '{printf "%s\"%s\"", sep, $0; sep=","} END {print ""}' > folders.txt
