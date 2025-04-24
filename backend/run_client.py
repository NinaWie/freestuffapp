import asyncio
import json
import os

import pandas as pd
from sqlalchemy.orm import sessionmaker
from telethon import TelegramClient, events

from data_preprocessing import (
    IMG_OUT_PATH,
    create_geojson,
    get_last_updated,
    get_used_ids,
)
from extract_location import get_address, get_postal
from to_database import MessageTable, Session, find_max_id
from utils import merge_rows_postprocessing, optimize_img_file_size

chat_name_mapping = {131336840: "Test", 1343503814: "Food", 1001280863188: "Goods"}
DOWNLOAD_IMAGES = True


def check_msg_relevant(msg):
    return msg.text is None or not (
        "suche" in msg.text.lower() or "kein kaufen/verkaufen hier" in msg.text.lower()
    )


async def download_img(msg, id_current):
    # Download potential images
    if DOWNLOAD_IMAGES and msg.photo:
        # thumb =0 was super small, thumb=3 seemed pretty
        # much the original size
        await msg.download_media(
            file=os.path.join(IMG_OUT_PATH, f"{id_current}.jpg"), thumb=1
        )


def handle_incoming_message(msg, last_msg, id_current):
    chatType = chat_name_mapping[msg.chat_id]

    # get name -  can be None
    if msg.sender is not None:
        sender_name = msg.sender.first_name
        sender_name = (
            sender_name + msg.sender.last_name
            if msg.sender.last_name is not None
            else sender_name
        )
    else:
        sender_name = None

    # Several messages by one user
    if last_msg is not None and sender_name == last_msg["sender"]:
        # Case 1: no photo in this message -> append message to previous
        if not msg.photo:
            last_msg["message"] += " " + msg.text
            return last_msg, True
        # Case 2: one of them does not have text -> same thing
        elif last_msg["message"] == "":
            last_msg["message"] = msg.text
            last_msg["photo_id"].append(id_current)
            id_current += 1
            return last_msg, True

    # add the message and metadata
    msg_dict = {
        "sender": sender_name,
        "message": msg.text,
        "date": msg.date,
        "id": id_current,
        "photo_id": [id_current] if msg.photo else [],
        "category": chatType,
    }
    return msg_dict, False


async def get_history(api_config, download_images=DOWNLOAD_IMAGES):
    """
    Load the last x messages and save as csv file

    Args:
        api_config (_type_): _description_
        download_images (bool, optional): _description_. Defaults to True.

    Notes:
        * Skipping messages containing "suche"
        * Not saving messages where we cannot determine any address
        * Merging messages if the same person posts two things after another
    """
    last_update = get_last_updated()
    message_list = []
    # https://stackoverflow.com/questions/44467293/how-can-i-download-the-chat-history-of-a-group-in-telegram

    id_current = 0
    ids_in_use = get_used_ids()
    if len(ids_in_use) > 0:
        id_current = max(ids_in_use)

    async with TelegramClient(
        "anon", api_config["api_id"], api_config["api_hash"]
    ) as client:
        # # THIS NEEDS TO BE DONE THE FIRST TIME IT RUNS!
        # me = await client.get_me()
        # async for dialog in client.iter_dialogs():
        #     print(dialog)
        for chat_nr in [1343503814, 1001280863188]:
            # iterate over the messages in the chat
            async for msg in client.iter_messages(
                chat_nr, 500
            ):  #  api_config["chat_nr"], 40):
                # skip searching
                chatType = chat_name_mapping[chat_nr]
                if msg.date < last_update[chatType]:
                    print(chatType, "ENDING HERE")
                    break
                if not check_msg_relevant(msg):
                    continue

                download_img(msg, id_current)

                prev_msg = message_list[-1] if len(message_list) > 0 else None
                # process the message
                msg_dict, is_last_message = handle_incoming_message(msg, prev_msg)
                # either update or append
                if is_last_message:
                    message_list[-1] = msg_dict
                else:
                    message_list.append(msg_dict)

                id_current += 1

    data = pd.DataFrame(message_list)
    # print(data)
    # print(data["category"].unique())

    # Save list of photos as strings --> saved as str anyways
    data["photo_id"] = data["photo_id"].astype(str).str[1:-1]
    data.loc[data["photo_id"] == "", "photo_id"] = pd.NA
    data.loc[data["message"] == "", "message"] = pd.NA
    # Do some postprocessing to merge messages
    data = merge_rows_postprocessing(data)
    data.dropna(subset=["message", "photo_id"], inplace=True)
    # print(data)

    # Get address for the messages
    data["zip"] = data["message"].apply(get_postal)
    data["address"] = data["message"].apply(get_address)
    # print(data)

    # data.to_csv("data.csv", encoding="utf-8", index=False)
    create_geojson(data)


global prev_msg
prev_msg = None

global id_current
id_current = int(find_max_id()) + 1


def get_online(api_config):
    with TelegramClient("anon", api_config["api_id"], api_config["api_hash"]) as client:

        @client.on(events.NewMessage(chats=[131336840]))  # 1343503814, 1001280863188])
        async def handle_chat_events(event):
            msg = event.message
            if not check_msg_relevant(msg):
                print("Skipping, not relevant")
            else:
                global id_current
                await download_img(msg, id_current)
                # process the rest of the image
                global prev_msg
                msg_dict, is_prev_msg = handle_incoming_message(
                    msg, prev_msg, id_current
                )
                if is_prev_msg:
                    print("Update previous message", msg_dict)
                    sql_session = Session()
                    row_to_update = (
                        sql_session.query(MessageTable)
                        .filter(MessageTable.id == str(msg_dict["id"]))
                        .first()
                    )
                    if row_to_update:
                        row_to_update.message = msg_dict["message"]
                        sql_session.commit()
                else:
                    print("Upload new message", msg_dict)
                    sql_session = Session()
                    new_row = MessageTable(
                        id=id_current,
                        message=msg_dict["message"],
                        sender=msg_dict["sender"],
                        category=msg_dict["category"],
                    )
                    sql_session.add(new_row)
                    sql_session.commit()
                    sql_session.close()
                    # increase ID
                    id_current += 1
                prev_msg = msg_dict

        client.run_until_disconnected()


if __name__ == "__main__":
    with open("api_config.json", "r") as infile:
        api_config = json.load(infile)
    # asyncio.run(get_history(api_config))
    get_online(api_config)
