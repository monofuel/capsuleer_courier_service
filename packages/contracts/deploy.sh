#!/bin/bash

## I was having issues with intermittent http errors (not timeouts) so I made this script to retry the deploy command until it succeeds

## ensure PRIVATE_KEY is set

source .env.testnet

until pnpm run deploy:testnet --worldAddress 0x8dc9cab3e97da6df615a8a24cc07baf110d63071; do
  echo "Command failed, retrying..."
  #sleep $((1 + RANDOM % 10))  # Waits for a random time between 1 and 10 seconds before retrying
  #sleep $((RANDOM%1000+1))e-3  # Add a random amount of milliseconds
done

echo "Command succeeded."