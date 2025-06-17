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
    mal_auth = config.get('mal', {}).get('authorization', {})
    if mal_auth and 'access_token' in mal_auth:
        mal_updates = {
            "MYANIMELIST_ACCESS_TOKEN": mal_auth.get('access_token', ''),
            "MYANIMELIST_REFRESH_TOKEN": mal_auth.get('refresh_token', '')
        }
        if 'expires_in' in mal_auth:
            mal_updates["MYANIMELIST_EXPIRES_IN"] = str(mal_auth.get('expires_in', ''))
        mal_updates = {k: v for k, v in mal_updates.items() if v}
        if mal_updates:
            logger.info("Updating MyAnimeList tokens in 1Password...")
            update_1password("kubernetes", "kometa", mal_updates)
    else:
        logger.info("No MyAnimeList authorization data found in config")
    trakt_auth = config.get('trakt', {}).get('authorization', {})
    if trakt_auth and 'access_token' in trakt_auth:
        trakt_updates = {
            "TRAKT_ACCESS_TOKEN": trakt_auth.get('access_token', ''),
            "TRAKT_REFRESH_TOKEN": trakt_auth.get('refresh_token', '')
        }
        if 'expires_in' in trakt_auth:
            trakt_updates["TRAKT_EXPIRES_IN"] = str(trakt_auth.get('expires_in', ''))
        if 'created_at' in trakt_auth:
            trakt_updates["TRAKT_CREATED_AT"] = str(trakt_auth.get('created_at', ''))
        trakt_updates = {k: v for k, v in trakt_updates.items() if v}
        if trakt_updates:
            logger.info("Updating Trakt tokens in 1Password...")
            update_1password("kubernetes", "kometa", trakt_updates)
    else:
        logger.info("No Trakt authorization data found in config")
    logger.info("Token update process complete")
if __name__ == "__main__":
    main()
