import json
import os
import pandas as pd
import asyncio
from telethon import TelegramClient
from data_preprocessing import create_geojson
from utils import merge_rows_postprocessing, optimize_img_file_size

IMG_OUT_PATH = "outputs"

with open(os.path.join("geodata", "place_names.json"), "r") as infile:
    plz_names = json.load(infile)
    postal_or_kreis = plz_names["names"]
    postal_name_mapping = plz_names["name_mapping"]


def get_postal(message):
    for plz_name in postal_or_kreis:
        if plz_name in message.lower():
            return postal_name_mapping.get(plz_name, plz_name)
    return pd.NA


def get_address(message):
    if not (
        ("strasse" in message.lower()) or ("straße" in message.lower()) or
        ("gasse" in message.lower()) or ("weg" in message.lower()) or
        ("platz" in message.lower())
    ):
        return pd.NA
    # clean
    wo_commas = message.replace(",", " ").replace("\n", " ")
    split = wo_commas.replace(".", " ").replace("/", " ").split(" ")
    # get the element
    street_part = [
        elem for elem in split
        if "strasse" in elem.lower() or "straße" in elem.lower() or "gasse" in
        elem.lower() or "weg" in elem.lower() or "platz" in elem.lower()
    ]
    index_of_element = split.index(street_part[0])

    # if the street name is split into two parts, we add the first part
    real_street = street_part[0]
    if real_street == "weg":  # cases where weg does not refer to a street but to "gone"
        return pd.NA

    if street_part[0].lower() in ["strasse", "gasse", "straße", "platz"]:
        real_street = " ".join(
            split[index_of_element - 1:index_of_element + 1]
        )

    try:
        house_number = int(split[index_of_element + 1])
        real_street = real_street + f" {house_number}"
    except:
        pass
    return real_street


async def get_history(api_config, download_images=True):
    """
    Load the last x messages and save as csv file

    Args:
        api_config (_type_): _description_
        download_images (bool, optional): _description_. Defaults to True.

    Notes:
        * Skipping messages containint "suche"
        * Not saving messages where we cannot determine any address
        * Merging messages if the same person posts two things after another
    """
    message_list = []
    # https://stackoverflow.com/questions/44467293/how-can-i-download-the-chat-history-of-a-group-in-telegram

    # store the previous sender to check whether it's a continued message
    prev_sender = "None"

    id_current = 0

    async with TelegramClient(
        "anon", api_config["api_id"], api_config["api_hash"]
    ) as client:
        async for msg in client.iter_messages(api_config["chat_nr"], 40):
            # skip searching
            if "suche" in msg.text.lower(
            ) or "kein kaufen/verkaufen hier" in msg.text.lower():
                continue
            # get name -  can be None
            if msg.sender is not None:
                sender_name = msg.sender.first_name
                sender_name = (
                    sender_name + msg.sender.last_name
                    if msg.sender.last_name is not None else sender_name
                )
            else:
                sender_name = None

            # Download potential images
            if download_images and msg.photo:
                # thumb =0 was super small, thumb=3 seemed pretty much the original size
                await msg.download_media(
                    file=os.path.join(IMG_OUT_PATH, f"{id_current}.jpg"),
                    thumb=1
                )
                photo_exists = True
            else:
                photo_exists = False

            # Several messages by one user
            if sender_name == prev_sender:
                # Case 1: no photo in this message -> append message to previous
                if not photo_exists:
                    message_list[-1]["Message"] += " " + msg.text
                    continue
                # Case 2: one of them does not have text -> same thing
                elif message_list[-1]["Message"] == "":
                    message_list[-1]["Message"] = msg.text
                    message_list[-1]["photo_id"].append(id_current)
                    id_current += 1
                    continue

            # add the message and metadata
            message_list.append(
                {
                    "Sender": sender_name,
                    "Message": msg.text,
                    "Date": msg.date,
                    "id": id_current,
                    "photo_id": [id_current] if photo_exists else []
                }
            )
            # print(message_list[-1])

            id_current += 1
            prev_sender = sender_name

    data = pd.DataFrame(message_list)

    # Get address for the messages
    data["zip"] = data["Message"].apply(get_postal)
    data["address"] = data["Message"].apply(get_address)
    # print(data)

    # Save list of photos as strings --> saved as str anyways
    data["photo_id"] = data["photo_id"].astype(str).str[1:-1]
    data.loc[data["photo_id"] == "", "photo_id"] = pd.NA
    data.loc[data["Message"] == "", "Message"] = pd.NA
    # Do some postprocessing to merge messages
    data = merge_rows_postprocessing(data)
    data.dropna(subset=["Message", "photo_id"], inplace=True)
    # print(data)

    # data.to_csv("data.csv", encoding="utf-8", index=False)
    create_geojson(data)


if __name__ == "__main__":
    with open("api_config.json", "r") as infile:
        api_config = json.load(infile)
    asyncio.run(get_history(api_config))
