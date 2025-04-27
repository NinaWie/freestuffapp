import pandas as pd
import requests
import time
import json
import geopandas as gpd
import os


def compile_description(row):
    desc = ""
    details = row["Details (Describe your project)"]
    if not pd.isna(details):
        desc += details
    located = row["Location type (church, storefront, etc.)"]
    if not pd.isna(located):
        if len(desc) > 0:
            desc += "\n"
        desc += "Located at: " + located
    opening_hours = row["Days/times fridge is open"]
    if not pd.isna(opening_hours):
        if len(desc) > 0:
            desc += "\n"
        desc += "Opened: " + opening_hours
    return desc


def add_all_freedges(path_all):
    freedges = pd.read_csv(path_all)
    freedges = freedges[freedges["LABEL"] == "Freedge"]

    # my_cols = ["name", "description", "address", "time_posted", "photo_id", "category", "external_url", "status"]
    cleaned = pd.DataFrame()
    cleaned["name"] = freedges["Project"]

    cleaned["description"] = freedges.apply(compile_description, axis=1)
    cleaned["address"] = (
        freedges["Street address"]
        + ", "
        + freedges["Zip Code"]
        + " "
        + freedges["City"]
        + ", "
        + freedges["State / Province"]
    )
    cleaned["time_posted"] = freedges["Date Installed"]
    cleaned["photo_id"] = freedges["Image URL"]
    cleaned["category"] = "Food"
    cleaned["external_url"] = freedges["Main Contact (email, IG, FB, website, linktree or other)"]
    cleaned["status"] = "permanent"
    return cleaned


def add_foodsharing_freedges(path):
    # Add foodsharing.de freedges
    freedges = pd.read_csv(path, encoding="utf-8", delimiter=";").dropna(subset="freedge_name")

    cleaned = pd.DataFrame()
    cleaned["name"] = freedges["freedge_name"]
    cleaned["description"] = freedges["description"] + "\n(Taken from https://foodsharing.de/)"
    cleaned["address"] = freedges["address"] + ", " + freedges["zip_code"] + " " + freedges["city"]
    cleaned["time_posted"] = "unknown"
    cleaned["photo_id"] = ""
    cleaned["category"] = "Food"
    cleaned["external_url"] = freedges["link"]
    cleaned["status"] = "permanent"
    return cleaned


def preprocess_both_freedges(path_all, path_foodsharing, path_save):
    worldwide = add_all_freedges(path_all)
    cleaned = add_foodsharing_freedges(path_foodsharing)

    # Combine both dataframes
    both_combined = pd.concat([worldwide, cleaned], ignore_index=True)
    print(
        "Length of combined data:",
        len(both_combined),
        "Length of worldwide data:",
        len(worldwide),
        "Length of foodsharing.de data:",
        len(cleaned),
    )
    both_combined = both_combined.drop_duplicates(subset=["name", "address"], keep="first")
    print("Length of combined data after dropping duplicates:", len(both_combined))
    both_combined = both_combined.dropna(subset=["name", "address"], how="any")
    print("Length of combined data after dropping NaN:", len(both_combined))
    both_combined.to_csv(path_save, index=False)
    print(both_combined.iloc[20])


def add_locations(in_path, save_path_geojson):
    freedges_combined = pd.read_csv(in_path)

    with open("location_api_key", "r") as inf:
        token = inf.read()[:-1]

    id_to_longlat = {}
    for i, row in freedges_combined.iterrows():

        address = row["address"]

        params = {"key": token, "q": address, "format": "json", "limit": 1}

        response = requests.get("https://us1.locationiq.com/v1/search", params=params)
        data = response.json()

        if data and isinstance(data, list):
            lat = data[0]["lat"]
            lon = data[0]["lon"]
            print(f"Latitude: {lat}, Longitude: {lon}")

            id_to_longlat[i] = (lat, lon)
        else:
            print("No results found.")
            id_to_longlat[i] = (pd.NA, pd.NA)

        if i % 20 == 0:
            print("Did steps", i)
        time.sleep(0.6)

    # add lat and lon to dataframe and convert to geodataframe
    id_to_lat = {k: float(v[0]) if not pd.isna(v[0]) else pd.NA for k, v in id_to_longlat.items()}
    id_to_lon = {k: float(v[1]) if not pd.isna(v[1]) else pd.NA for k, v in id_to_longlat.items()}
    freedges_combined["latitude"] = id_to_lat
    freedges_combined["longitude"] = id_to_lon
    freedges_without_nans = freedges_combined.dropna(subset=["latitude", "longitude"]).fillna("")
    freedges_gdf = gpd.GeoDataFrame(
        freedges_without_nans,
        geometry=gpd.points_from_xy(x=freedges_without_nans["longitude"], y=freedges_without_nans["latitude"]),
    )
    freedges_gdf.to_file(save_path_geojson)


if __name__ == "__main__":
    # preprocess all freedges
    path_all = "data/freedges around the world - All.csv"
    path_foodsharing = "data/freedges around the world - foodsharing.de.csv"
    path_save = "data/freedges_combined.csv"
    preprocess_both_freedges(path_all, path_foodsharing, path_save)

    # add locations to freedges
    save_path_geojson = os.path.join("data", "freedges.geojson")
    add_locations(path_save, save_path_geojson)
