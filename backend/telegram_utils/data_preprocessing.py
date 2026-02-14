import json
import os

import geopandas as gpd
import pandas as pd
import numpy as np


OUT_PATH = "../../images/freestuff"
IMG_OUT_PATH = "../../images/freestuff/images"
os.makedirs(OUT_PATH, exist_ok=True)
# "../../images/freestuff/postings.json" real path
TIME_FORMAT = "%d/%m/%Y %H:%M"


def get_last_updated():
    if os.path.exists(os.path.join(OUT_PATH, "postings.json")):
        current_geojson = gpd.read_file(os.path.join(OUT_PATH, "postings.json"))
    else:
        current_geojson = pd.DataFrame(columns=["category"])

    last_update = {}
    for category in ["Food", "Goods"]:
        # for all categories, find the last posted message
        categ_postings = current_geojson[current_geojson["category"] == category]
        if len(categ_postings) > 0:
            last_update[category] = pd.to_datetime(categ_postings["time_posted"], format=TIME_FORMAT, utc=True).max()
        else:
            last_update[category] = pd.to_datetime("2023-10-08 00:00:00+00:00")


def get_used_ids():
    ids_in_use = [int(i.split(".")[0]) for i in os.listdir(IMG_OUT_PATH) if i[0] != "."]
    return ids_in_use


def jitter_lonlat(lon, lat, radius_m=20.0, rng=None):
    EARTH_R = 6_371_000.0  # meters

    def wrap_lon(lon_deg: float) -> float:
        # wrap to [-180, 180)
        return ((lon_deg + 180.0) % 360.0) - 180.0

    def clamp_lat(lat_deg: float) -> float:
        return float(np.clip(lat_deg, -90.0, 90.0))

    rng = np.random.default_rng(rng)
    theta = rng.uniform(0.0, 2 * np.pi)
    r = radius_m * np.sqrt(rng.uniform(0.0, 1.0))
    dx = r * np.cos(theta)  # meters east
    dy = r * np.sin(theta)  # meters north
    lat_rad = np.deg2rad(lat)
    dlat = (dy / EARTH_R) * (180.0 / np.pi)
    # Guard against cos(lat)=0 near poles
    coslat = np.cos(lat_rad)
    if abs(coslat) < 1e-12:
        dlon = 0.0
    else:
        dlon = (dx / (EARTH_R * coslat)) * (180.0 / np.pi)
    lon2 = wrap_lon(lon + dlon)
    lat2 = clamp_lat(lat + dlat)
    return lon2, lat2


# load streets and plz coordinates
strasse_zu_coord = pd.read_csv(os.path.join("telegram_utils", "geodata", "strassen.csv"))


# set index
zurich_zip = gpd.read_file(os.path.join("telegram_utils", "geodata", "zurich.gpkg"))
zurich_zip = zurich_zip.set_index("name").sort_index()


def create_geojson(data, allow_only_zip=False):

    # Part 1: process the one with street names
    data_with_street = data[~pd.isna(data["address"])]
    data_with_street["address_wo_number"] = data_with_street["address"].apply(lambda x: x.split(" ")[0].lower())
    data_with_street = data_with_street.merge(
        strasse_zu_coord, left_on="address_wo_number", right_on="name", how="left"
    )
    # apply jitter
    data_with_street["x"], data_with_street["y"] = zip(
        *data_with_street.apply(lambda row: jitter_lonlat(row["x"], row["y"]), axis=1)
    )
    data_with_geom = gpd.GeoDataFrame(
        data_with_street, geometry=gpd.points_from_xy(x=data_with_street["x"], y=data_with_street["y"]), crs=4326
    )
    data_with_geom = data_with_geom[~data_with_geom.geometry.is_empty]

    if allow_only_zip:
        # Part 2: Process the ones with zip but no (valid) street
        plz_exists_but_no_stret = (~pd.isna(data["zip"])) & pd.isna(data["address"])
        # leftover are the ones with plz but no sreets or the ones that we couldn't
        # assign a street to but which have a plz
        leftover = pd.concat(
            [
                data[plz_exists_but_no_stret],
                data_with_street[pd.isna(data_with_street["x"])],
            ]
        ).dropna(subset=["zip"])
        # convert to str
        # leftover["zip"] = leftover["zip"].astype(int).astype(str)

        zurich_data = zurich_zip.copy()
        # remove invalid zip codes
        leftover = leftover[leftover["zip"].isin(zurich_data.index)]
        # compute number of required samples
        required_samples_per_zip = leftover.groupby("zip")["zip"].count()
        zurich_data["num"] = required_samples_per_zip
        zurich_data.dropna(inplace=True)
        # Sample points in polygons
        sampled = zurich_data.geometry.sample_points(zurich_data["num"].astype(int))
        sampled = gpd.GeoDataFrame(sampled.explode(index_parts=True)).reset_index().drop("level_1", axis=1)
        assert len(sampled) == len(leftover)
        # add as geometry
        leftover.sort_values("zip", inplace=True)
        leftover["geometry"] = sampled["sampled_points"].values

        # final data: the ones with plz (leftover) and the ones where we could
        # find a street
        data_with_geom = pd.concat([leftover, data_with_geom.dropna(subset=["x"])])

    data_with_geom.drop(["x", "y", "name", "address_wo_number"], axis=1, inplace=True)
    data_with_geom = gpd.GeoDataFrame(data_with_geom, geometry="geometry")

    data_with_geom["name"] = data_with_geom["message"].str[:50].str.replace("\n", " ")

    # combine zip and address
    def get_full_address(row):
        address = ""
        if not pd.isna(row["address"]):
            address += str(row["address"]) + " "
        if not pd.isna(row["zip"]):
            address += str(row["zip"])
        return address

    data_with_geom["address"] = data_with_geom.apply(get_full_address, axis=1)
    data_with_geom = data_with_geom.drop(["zip"], axis=1)

    return data_with_geom


def preprocess_streets(
    in_path=os.path.join("geodata", "raw", "strassennamen.json"),
    out_path=os.path.join("geodata", "strassen.csv"),
):
    with open(in_path, "r") as infile:
        strassen = json.load(infile)
    # TODO: use full addresses
    # with open(os.path.join("geodata", "raw", "adressen.json"), "r") as infile:
    #     strassen = json.load(infile)
    strasse_zu_coord = {}
    for strasse in strassen["features"]:
        strasse_zu_coord[strasse["properties"]["lokalisationsname"].lower()] = strasse["geometry"]["coordinates"]
    strasse_zu_coord = pd.DataFrame(strasse_zu_coord, index=["x", "y"]).swapaxes(1, 0)
    strasse_zu_coord.to_csv(out_path)


def generate_eligible_name_list(
    zurich_data_path=os.path.join("geodata", "zurich.gpkg"),
    out_path=os.path.join("geodata", "place_names.json"),
):
    zurich_data = gpd.read_file(zurich_data_path)
    eligible_names = list(zurich_data["name"].values)
    eligible_name_mapping = {}
    for name in zurich_data["name"].values:
        if "kreis" in name:
            kreis_number = name.split(" ")[-1]
            eligible_names.append("k" + kreis_number)
            eligible_names.append("kreis" + kreis_number)
            eligible_name_mapping["k" + kreis_number] = name
            eligible_name_mapping["kreis" + kreis_number] = name

    with open(out_path, "w") as outfile:
        json.dump({"names": eligible_names, "name_mapping": eligible_name_mapping}, outfile)


def create_zurich_data(in_path="geodata/raw", out_path=os.path.join("geodata", "zurich.gpkg")):
    # get plz polygons
    plz = gpd.read_file(os.path.join(in_path, "PLZO_PLZ.shp"))[["PLZ", "geometry"]]
    # get names for plz
    plz_orte = pd.read_csv(os.path.join(in_path, "plz_ortsnamen.csv"), delimiter=";")
    plz_orte = plz_orte[plz_orte["Ortschaftsname"] == "Zürich"]
    # merge to keep only the ones in zurich
    plz_zurich = plz.merge(plz_orte, how="right", left_on="PLZ", right_on="PLZ")[["PLZ", "geometry"]]
    plz_zurich.rename({"PLZ": "name"}, axis=1, inplace=True)
    plz_zurich["name"] = plz_zurich["name"].astype(str)

    # kreise
    kreise = pd.read_csv(os.path.join(in_path, "stadtkreise.csv"))
    kreise["geometry"] = kreise["geometry"].apply(wkt.loads)
    kreise = gpd.GeoDataFrame(kreise, geometry="geometry")
    kreise = kreise[["bezeichnung", "geometry"]].rename({"bezeichnung": "name"}, axis=1)
    kreise["name"] = kreise["name"].str.lower()

    zurich_data = pd.concat([kreise, plz_zurich])  # project
    zurich_data.geometry.crs = "EPSG:2056"
    zurich_data.to_crs("EPSG:4326", inplace=True)
    zurich_data.to_file(out_path)


def test_jitter():
    lon = 8.5417
    lat = 47.3769
    data_with_street = pd.DataFrame(
        {
            "address": ["Bahnhofstrasse 1", "Bahnhofstrasse 2", "Bahnhofstrasse 3"],
            "message": ["Test1", "Test2", "Test3"],
            "x": [lon, lon, lon],
            "y": [lat, lat, lat],
        }
    )
    print(data_with_street)
    data_with_street["x"], data_with_street["y"] = zip(
        *data_with_street.apply(lambda row: jitter_lonlat(row["x"], row["y"]), axis=1)
    )
    print(data_with_street)


if __name__ == "__main__":
    data = pd.read_csv("data.csv")
    create_geojson(data)
