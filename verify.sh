#!/bin/sh
network=$1
token=$2
base=$3
operator=$4
npm run verify:$network $2 && npm run verify:$network $3 && npm run verify:$network $4 $3 $2