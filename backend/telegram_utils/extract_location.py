import json
import os


import pandas as pd

def load_plz_names():
    with open(os.path.join("telegram_utils", "raw_geodata", "place_names.json"), "r") as infile:
        plz_names = json.load(infile)
        postal_or_kreis = plz_names["names"]
        postal_name_mapping = plz_names["name_mapping"]
    return postal_or_kreis, postal_name_mapping


def get_postal(message):
    postal_or_kreis, postal_name_mapping = load_plz_names()
    if pd.isna(message):
        return pd.NA
    for plz_name in postal_or_kreis:
        if plz_name in message.lower():
            return str(postal_name_mapping.get(plz_name, plz_name))
    return pd.NA


def get_address(message):
    if pd.isna(message):
        return pd.NA
    if not (
        ("strasse" in message.lower())
        or ("straße" in message.lower())
        or ("gasse" in message.lower())
        or ("weg " in message.lower())
        or ("platz " in message.lower())
    ):
        return pd.NA
    # clean
    wo_commas = message.replace(",", " ").replace("\n", " ")
    split = wo_commas.replace(".", " ").replace("/", " ").split(" ")
    # get the element
    street_part = [
        elem
        for elem in split
        if "strasse" in elem.lower()
        or "straße" in elem.lower()
        or "gasse" in elem.lower()
        or "weg" in elem.lower()
        or "platz" in elem.lower()
    ]
    index_of_element = split.index(street_part[0])

    # if the street name is split into two parts, we add the first part
    real_street = street_part[0]
    if real_street == "weg":  # cases where weg does not refer to a street but to "gone"
        return pd.NA

    if street_part[0].lower() in ["strasse", "gasse", "straße", "platz"]:
        real_street = " ".join(split[index_of_element - 1 : index_of_element + 1])

    try:
        house_number = int(split[index_of_element + 1])
        real_street = real_street + f" {house_number}"
    except:
        pass
    return real_street
