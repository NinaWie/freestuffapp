import json
import os

import pandas as pd
from PIL import Image, ImageOps

with open(os.path.join("telegram_utils", "geodata", "place_names.json"), "r") as infile:
    plz_names = json.load(infile)
    postal_or_kreis = plz_names["names"]
    postal_name_mapping = plz_names["name_mapping"]


def merge_rows_postprocessing(data):
    """
    After the whole collection of the data, merge the ones with same sender
    where only one of two messages has a picture and the other has a message
    """
    data["sender_next"] = data["sender"].shift(-1)
    data["photo_next"] = data["photo_id"].shift(-1)
    data["message_next"] = data["message"].shift(-1)
    # this one has a photo but not a message, next one has no photo
    # --> use next message
    cond1 = (data["sender_next"] == data["sender"]) & (
        (pd.isna(data["photo_next"]) & pd.isna(data["message"]))
    )
    data.loc[cond1, "message"] = data.loc[cond1, "message_next"]
    # this one has a message but not a photo, next one has no message
    # --> use next photo
    cond2 = (data["sender_next"] == data["sender"]) & (
        pd.isna(data["message_next"]) & pd.isna(data["photo_id"])
    )
    data.loc[cond2, "photo_id"] = data.loc[cond2, "photo_next"]
    data.drop(["sender_next", "photo_next", "message_next"], axis=1, inplace=True)
    return data


def clean_up_images(listed_photo_ids, path_images):
    used_photo_ids = ", ".join(listed_photo_ids).split(", ")
    unused_photos = [
        p for p in os.listdir(path_images) if p.split(".")[0] not in used_photo_ids
    ]
    print(
        "currently listed postings",
        len(used_photo_ids),
        "unused_ids",
        len(unused_photos),
    )
    for p in unused_photos:
        os.remove(os.path.join(path_images, p))


def optimize_img_file_size(img_path):
    # optimize file size
    img = Image.open(img_path)
    img = ImageOps.exif_transpose(img)
    basewidth = 200
    wpercent = basewidth / float(img.size[0])
    if wpercent > 1:
        return "Image uploaded successfully, no resize necessary"
    # resize
    hsize = int((float(img.size[1]) * float(wpercent)))
    img = img.resize((basewidth, hsize), Image.Resampling.LANCZOS)
    img.save(img_path, quality=95)


def get_chat_nr():
    """Helper method to get chat numbers"""
    from telethon.sync import TelegramClient

    with open("api_config.json", "r") as infile:
        api_config = json.load(infile)

    client = TelegramClient("anon", api_config["api_id"], api_config["api_hash"])
    client.connect()
    # Retrieve all the dialogs (chats and channels) that you are currently part of
    dialogs = client.get_dialogs()

    # Iterate over the dialogs to print the chat_id
    # and the title of each chat
    for dialog in dialogs:
        print("Chat ID:", dialog.id, "Title:", dialog.title)
