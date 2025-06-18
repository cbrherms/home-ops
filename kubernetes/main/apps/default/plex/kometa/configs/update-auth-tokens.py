#!/usr/bin/env python3
import yaml
import subprocess
import json
import os
import sys
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('token-updater')

CONFIG_PATH = "/config/config.yml"

def read_config():
    """Read the Kometa config file"""
    try:
        with open(CONFIG_PATH, 'r') as file:
            config = yaml.safe_load(file)
        return config
    except Exception as e:
        logger.error(f"Error reading config file: {e}")
        sys.exit(1)

def update_1password(vault, item, fields_to_update):
    """Update fields in 1Password"""
    try:
        edit_cmd = ["op", "item", "edit", item, "--vault", vault]
        for field_name, field_value in fields_to_update.items():
            edit_cmd.extend(["--field", f"{field_name}={field_value}"])

        result = subprocess.run(edit_cmd, capture_output=True, text=True, check=True)
        logger.info(f"Successfully updated {len(fields_to_update)} fields in {item}")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Error updating 1Password: {e}")
        if e.stderr:
            logger.error(f"Error details: {e.stderr}")
        return False

def main():
    if "OP_SERVICE_ACCOUNT_TOKEN" not in os.environ:
        logger.error("OP_SERVICE_ACCOUNT_TOKEN environment variable not set")
        sys.exit(1)

    config = read_config()

    # --- Process MyAnimeList Tokens ---
    mal_auth = config.get('mal', {}).get('authorization', {})
    if mal_auth and 'access_token' in mal_auth:
        all_mal_tokens = {
            "MYANIMELIST_ACCESS_TOKEN": mal_auth.get('access_token', ''),
            "MYANIMELIST_REFRESH_TOKEN": mal_auth.get('refresh_token', '')
        }
        if 'expires_in' in mal_auth:
            all_mal_tokens["MYANIMELIST_EXPIRES_IN"] = str(mal_auth.get('expires_in', ''))

        valid_mal_updates = {}
        for key, value in all_mal_tokens.items():
            if value and not (isinstance(value, str) and value.startswith('<<') and value.endswith('>>')):
                valid_mal_updates[key] = value
            else:
                logger.info(f"Skipping update for {key}; value is a placeholder or has not changed.")

        if valid_mal_updates:
            logger.info(f"Found {len(valid_mal_updates)} valid MyAnimeList tokens to update in 1Password...")
            update_1password("kubernetes", "kometa", valid_mal_updates)
    else:
        logger.info("No MyAnimeList authorization data found in config")

    # --- Process Trakt Tokens ---
    trakt_auth = config.get('trakt', {}).get('authorization', {})
    if trakt_auth and 'access_token' in trakt_auth:
        all_trakt_tokens = {
            "TRAKT_ACCESS_TOKEN": trakt_auth.get('access_token', ''),
            "TRAKT_REFRESH_TOKEN": trakt_auth.get('refresh_token', '')
        }
        if 'expires_in' in trakt_auth:
            all_trakt_tokens["TRAKT_EXPIRES_IN"] = str(trakt_auth.get('expires_in', ''))
        if 'created_at' in trakt_auth:
            all_trakt_tokens["TRAKT_CREATED_AT"] = str(trakt_auth.get('created_at', ''))

        valid_trakt_updates = {}
        for key, value in all_trakt_tokens.items():
            if value and not (isinstance(value, str) and value.startswith('<<') and value.endswith('>>')):
                valid_trakt_updates[key] = value
            else:
                logger.info(f"Skipping update for {key}; value is a placeholder or has not changed.")

        if valid_trakt_updates:
            logger.info(f"Found {len(valid_trakt_updates)} valid Trakt tokens to update in 1Password...")
            update_1password("kubernetes", "kometa", valid_trakt_updates)
    else:
        logger.info("No Trakt authorization data found in config")

    logger.info("Token update process complete")

if __name__ == "__main__":
    main()
