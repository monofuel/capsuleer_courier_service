#!/bin/bash

## I was having issues with intermittent http errors (not timeouts) so I made this script to retry the deploy command until it succeeds

## ensure PRIVATE_KEY is set

until pnpm run deploy:testnet --worldAddress 0x8dc9cab3e97da6df615a8a24cc07baf110d63071; do
  echo "Command failed, retrying..."
  sleep 1  # Waits for 1 second before retrying
done

echo "Command succeeded."