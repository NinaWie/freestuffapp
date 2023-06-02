import json
import os
import pandas as pd
from telethon import TelegramClient, events, sync
from PIL import Image, ImageOps


# Remember to use your own values from my.telegram.org!
def get_online(api_config):
    text_list = []

    with TelegramClient(
        "anon", api_config["api_id"], api_config["api_hash"]
    ) as client:

        @client.on(events.NewMessage(chats=api_config["chat_nr"]))
        # '**Unkommerzieller Marktplatz Zureich**'))
        async def my_event_handler(event):
            print(event.raw_text)
            text_list.append(event.raw_text)

        client.run_until_disconnected()

    with open("test.json", "w") as outfile:
        json.dump(text_list, outfile)


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
        ("gasse" in message.lower()) or ("weg" in message.lower())
    ):
        return pd.NA
    # clean
    wo_commas = message.replace(",", " ").replace("\n", " ")
    split = wo_commas.replace(".", " ").replace("/", " ").split(" ")
    # get the element
    street_part = [
        elem for elem in split
        if "strasse" in elem.lower() or "straße" in elem.lower()
        or "gasse" in elem.lower() or "weg" in elem.lower()
    ]
    index_of_element = split.index(street_part[0])

    # if the street name is split into two parts, we add the first part
    real_street = street_part[0]
    if real_street == "weg":  # cases where weg does not refer to a street but to "gone"
        return pd.NA

    if street_part[0].lower() in ["strasse", "gasse", "straße"]:
        real_street = " ".join(
            split[index_of_element - 1:index_of_element + 1]
        )

    try:
        house_number = int(split[index_of_element + 1])
        real_street = real_street + f" {house_number}"
    except ValueError:
        pass
    return real_street


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


def get_history(api_config, download_images=True):
    message_list = []
    # https://stackoverflow.com/questions/44467293/how-can-i-download-the-chat-history-of-a-group-in-telegram

    # store the previous sender to check whether it's a continued message
    prev_sender = "None"

    id_current = 0

    with TelegramClient(
        "anon", api_config["api_id"], api_config["api_hash"]
    ) as client:
        for msg in client.iter_messages(api_config["chat_nr"], 500):
            # skip searching
            if "suche" in msg.text.lower():
                continue
            # get name
            sender_name = msg.sender.first_name
            sender_name = (
                sender_name + msg.sender.last_name
                if msg.sender.last_name is not None else sender_name
            )
            if sender_name == prev_sender:
                # continued message!
                message_list[-1]["Message"] += " " + msg.text
                continue

            # add the message and metadata
            message_list.append(
                {
                    "Sender": sender_name,
                    "Message": msg.text,
                    "Date": msg.date,
                    "id": id_current,
                }
            )
            if download_images and msg.photo:
                # thumb =0 was super small, thumb=3 seemed pretty much the original size
                path = msg.download_media(
                    file=os.path.join("img", f"{id_current}.jpg"), thumb=1
                )
                # optimize_img_file_size(path)

            prev_sender = sender_name
            id_current += 1

    test = pd.DataFrame(message_list)
    # postal
    test["zip"] = test["Message"].apply(get_postal)
    test["address"] = test["Message"].apply(get_address)

    print(test)
    test.to_csv("data.csv", encoding="utf-8", index=False)


if __name__ == "__main__":
    with open("api_config.json", "r") as infile:
        api_config = json.load(infile)
    get_history(api_config)
