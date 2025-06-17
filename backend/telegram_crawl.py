import asyncio
import json
import os

import pandas as pd
from sqlalchemy.orm import sessionmaker
from telethon import TelegramClient, events

from read_write_postings import insert_posting

from telegram_utils.data_preprocessing import (
    IMG_OUT_PATH,
    create_geojson,
    get_last_updated,
    get_used_ids,
)
from telegram_utils.extract_location import get_address, get_postal
from telegram_utils.utils import merge_rows_postprocessing, optimize_img_file_size

chat_name_mapping = {131336840: "Goods", 1001343503814: "Food", 1001280863188: "Goods", 1280863188: "Goods"}
DOWNLOAD_IMAGES = True

SUPPORT_MULTIPLE_IMAGES = False  # Whether to support multiple images in a single message
SUPPORT_SENDER_MERGE = False  # Whether to merge messages from the same sender

def check_msg_relevant(msg):
    return msg.text is None or not (
        "suche" in msg.text.lower() or "kein kaufen/verkaufen hier" in msg.text.lower()
    )


async def download_img(msg, id_current, client=None):
    """Download potential images from a message."""
    # Assume msg is a Message object you received from an event
    if SUPPORT_MULTIPLE_IMAGES and msg.grouped_id:
        assert client is not None, "Client must be provided for grouped messages"
        print("Downloading album with grouped_id:", msg.grouped_id)
        album_msgs = await client.get_messages(
            msg.chat_id,
            filter=None,
            min_id=0,
            limit=5
        )
        album_msgs = [m for m in album_msgs if m.grouped_id == msg.grouped_id]
        for i, m in enumerate(reversed(album_msgs)):  # preserve original order
            await m.download_media(file=os.path.join(IMG_OUT_PATH, f"{id_current}_{i}.jpg"))
    else:
        # thumb =0 was super small, thumb=3 seemed pretty much the original size
        await msg.download_media(
            file=os.path.join(IMG_OUT_PATH, f"{id_current}_0.jpg"), thumb=1
        )



def handle_incoming_message(msg, last_msg, chat_nr):
    # get type (Food or Goods)
    chat_type = chat_name_mapping[chat_nr]
    
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
    if SUPPORT_SENDER_MERGE and last_msg is not None and sender_name == last_msg["sender"]:
        # Case 1: no photo in this message -> append message to previous
        if not msg.photo:
            last_msg["message"] += " " + msg.text
            return last_msg, True
        # Case 2: one of them does not have text -> same thing
        elif last_msg["message"] == "":
            last_msg["message"] = msg.text
            # TODO: get last photo id (currently always "_0")
            last_msg["photo_id"].append("_0")  # append new photo id
            return last_msg, True

    expire_date = (msg.date + pd.Timedelta(days=3)).strftime("%d. %b %Y")


    # add the message and metadata
    msg_dict = {
        "sender": sender_name,
        "message": msg.text,
        "description": "Taken from Unkommerzieller Marktplatz Zuerich Chat: " + msg.text,
        "expiration_date": expire_date,
        "external_url": None,  # No external URL in the messages
        "category": chat_type,
        "time_posted": msg.date,
        "zip": get_postal(msg.text),
        "address": get_address(msg.text),
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


    async with TelegramClient(
        "history_session", api_config["api_id"], api_config["api_hash"]
    ) as client:
        await client.start(phone="+4917663009436")
        # # THIS NEEDS TO BE DONE THE FIRST TIME IT RUNS!
        # me = await client.get_me()

        # # Code to get IDs of chats
        # async for dialog in client.iter_dialogs():
        #     if "Food" in dialog.name:
        #         print(dialog.name, dialog.id)
            
        for chat_nr in [1280863188, 1001343503814]:
            # iterate over the messages in the chat
            async for msg in client.iter_messages(
                chat_nr, 20
            ): 
                # debugging: skip searching
                # if msg.date < last_update[chatType]:
                #     print(chatType, "ENDING HERE")
                #     break
                if not check_msg_relevant(msg):
                    continue
                # print("Processing message ID:", msg.id, "from chat:", chat_name_mapping[chat_nr])

                prev_msg = message_list[-1] if len(message_list) > 0 else None
                # process the message
                msg_dict, is_last_message = handle_incoming_message(msg, prev_msg, chat_nr)

                # get coordinates
                msg_as_df = pd.DataFrame([msg_dict])
                msg_w_coords = create_geojson(msg_as_df)

                # add if we found a location
                if len(msg_w_coords) > 0:
                    assert len(msg_w_coords) == 1, "Expected only one row in GeoDataFrame"
                    # print("MSG WITH COORDS", msg_w_coords.iloc[0].to_dict())
                    # print(msg)
                    has_photo= msg.photo is not None # TODO: handle multiple photos
                    jsonify_result, error_code, new_post_id = insert_posting(
                        msg_w_coords.iloc[0].to_dict(), nr_photos=int(has_photo)
                    )
                    if error_code == 200:
                        print("Successfully inserted posting with ID:", new_post_id)
                        await download_img(msg, new_post_id)
                    else:
                        print("Error inserting posting:", jsonify_result)

                # either update or append
                if is_last_message:
                    message_list[-1] = msg_dict
                else:
                    message_list.append(msg_dict)



global prev_msg
prev_msg = None


def get_online(api_config):
    with TelegramClient("anon", api_config["api_id"], api_config["api_hash"]) as client:

        @client.on(events.NewMessage(chats=[131336840, 1280863188, 1001343503814])) # TODO: delete test chat
        async def handle_chat_events(event):
            msg = event.message
            if not check_msg_relevant(msg):
                print("Skipping, not relevant", msg.text)
            else:
                # process the rest of the image
                # TODO: support for merging messages from the same sender
                global prev_msg
                # msg_dict, is_prev_msg = handle_incoming_message(
                #     msg, prev_msg, id_current
                # )
                # if is_prev_msg:
                #     print("Update previous message", msg_dict)
                #     sql_session = Session()
                #     row_to_update = (
                #         sql_session.query(MessageTable)
                #         .filter(MessageTable.id == str(msg_dict["id"]))
                #         .first()
                #     )
                #     if row_to_update:
                #         row_to_update.message = msg_dict["message"]
                #         sql_session.commit()

                # process the message
                msg_dict, is_last_message = handle_incoming_message(msg, prev_msg, msg.chat_id)

                # get coordinates
                msg_as_df = pd.DataFrame([msg_dict])
                msg_w_coords = create_geojson(msg_as_df)
                
                # add if we found a location
                if len(msg_w_coords) > 0:
                    assert len(msg_w_coords) == 1, "Expected only one row in GeoDataFrame"
                    has_photo= msg.photo is not None # TODO: handle multiple photos
                    jsonify_result, error_code, new_post_id = insert_posting(
                        msg_w_coords.iloc[0].to_dict(), nr_photos=int(has_photo)
                    )
                    if error_code == 200:
                        print("Successfully inserted posting with ID:", new_post_id)
                        await download_img(msg, new_post_id)
                        prev_msg = msg_dict
                    else:
                        print("Error inserting posting:", jsonify_result)
                else:
                    print("Location could not be determined", msg.text)

        client.run_until_disconnected()


if __name__ == "__main__":
    with open("telegram_utils/api_config.json", "r") as infile:
        api_config = json.load(infile)
    # asyncio.run(get_history(api_config)) # for testing
    get_online(api_config)
