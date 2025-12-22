import argparse
import logging
import pathlib
import pydantic
from typing import Optional
from nixarr.clients import jellyfin_client


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class UserConfig(pydantic.BaseModel):
    name: str
    passwordFile: Optional[pathlib.Path] = None


class JellyfinConfig(pydantic.BaseModel):
    users: list[UserConfig] = []
    complete_wizard: bool = False


def complete_wizard(client):
    client.system_configuration({
        "IsStartupWizardCompleted": True
    })


def sync_users(config: JellyfinConfig, client):
    existing_users = {u['Name']: u for u in client.get_users()}

    for user_cfg in config.users:
        password = None
        if user_cfg.passwordFile:
            try:
                password = user_cfg.passwordFile.read_text().strip()
            except Exception as e:
                logger.error(
                    f"Failed to read password file for user {user_cfg.name}: "
                    f"{e}"
                )
                continue

        if user_cfg.name not in existing_users:
            logger.info(f"Creating user {user_cfg.name}")
            user = client.create_user(user_cfg.name, password)
            existing_users[user_cfg.name] = user  # Update local cache
        else:
            logger.info(f"User {user_cfg.name} already exists")
            user_id = existing_users[user_cfg.name]['Id']
            if password:
                client.update_user_password(user_id, None, password)


def main():
    parser = argparse.ArgumentParser(description="Sync Jellyfin settings")
    parser.add_argument(
        "--config-file",
        type=pathlib.Path,
        required=True,
        help="Path to config file"
    )
    args = parser.parse_args()

    config_json = args.config_file.read_text()
    config = JellyfinConfig.model_validate_json(config_json)

    with jellyfin_client() as client:
        # Complete wizard first if requested
        if config.complete_wizard:
            try:
                complete_wizard(client)
            except Exception as e:
                logger.warning(f"Failed to complete wizard: {e}")
                # Continue anyway - wizard might already be complete

        # Then sync users via authenticated API
        if config.users:
            sync_users(config, client)


if __name__ == "__main__":
    main()
