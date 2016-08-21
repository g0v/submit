#!/usr/bin/env bash
while [ 1 ]; do
  git pull
  echo 
  lsc main
  git add state.json submissions.json
  git commit -m "update submission information"
  git push
  sleep 8640
done

