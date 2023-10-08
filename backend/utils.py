import pandas as pd
import os
from PIL import Image, ImageOps


def merge_rows_postprocessing(data):
    """
    After the whole collection of the data, merge the ones with same sender
    where only one of two messages has a picture and the other has a message
    """
    data["sender_next"] = data["Sender"].shift(-1)
    data["photo_next"] = data["photo_id"].shift(-1)
    data["message_next"] = data["Message"].shift(-1)
    # this one has a photo but not a message, next one has no photo
    # --> use next message
    cond1 = (data["sender_next"] == data["Sender"]
             ) & ((pd.isna(data["photo_next"]) & pd.isna(data["Message"])))
    data.loc[cond1, "Message"] = data.loc[cond1, "message_next"]
    # this one has a message but not a photo, next one has no message
    # --> use next photo
    cond2 = (data["sender_next"] == data["Sender"]
             ) & (pd.isna(data["message_next"]) & pd.isna(data["photo_id"]))
    data.loc[cond2, "photo_id"] = data.loc[cond2, "photo_next"]
    data.drop(
        ["sender_next", "photo_next", "message_next"], axis=1, inplace=True
    )
    return data


def clean_up_images(listed_photo_ids, path_images):
    used_photo_ids = [", ".join(listed_photo_ids).split(", ")]
    unused_photos = [
        p for p in os.listdir(path_images)
        if p.split(".")[0] not in used_photo_ids
    ]
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
