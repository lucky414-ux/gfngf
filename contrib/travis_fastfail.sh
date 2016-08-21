#!/bin/sh
# This file is a part of Julia. License is MIT: http://julialang.org/license

curlhdr="Accept: application/vnd.travis-ci.2+json"
endpoint="https://api.travis-ci.org/repos/$TRAVIS_REPO_SLUG"

# Fail fast for superseded builds to PR's
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  newestbuildforthisPR=$(curl -H "$curlhdr" $endpoint/builds?event_type=pull_request | \
      jq ".builds | map(select(.pull_request_number == $TRAVIS_PULL_REQUEST))[0].number")
  if [ $newestbuildforthisPR != null -a $newestbuildforthisPR != \"$TRAVIS_BUILD_NUMBER\" ]; then
    printf "There are newer queued builds for this pull request, failing early.\n"
    exit 1
  fi
else
  # And for non-latest push builds in branches other than master or release*
  case $TRAVIS_BRANCH in
    master | release*)
      ;;
    *)
      if [ \"$TRAVIS_BUILD_NUMBER\" != $(curl -H "$curlhdr" \
          $endpoint/branches/$TRAVIS_BRANCH | jq ".branch.number") ]; then
        printf "There are newer queued builds for this branch, failing early.\n"
        exit 1
      fi
      ;;
  esac
fi
