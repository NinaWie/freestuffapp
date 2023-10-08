import geopandas as gpd
import pandas as pd
import os
import json
from shapely import wkt

OUT_PATH = "outputs"
os.makedirs(OUT_PATH, exist_ok=True)
# "../../images/freestuff/postings.json" real path


def create_geojson(data, path="geodata"):
    strasse_zu_coord = pd.read_csv(os.path.join(path, "strassen.csv"))

    # Part 1: process the one with street names
    data_with_street = data[~pd.isna(data["address"])]
    data_with_street["address_wo_number"] = data_with_street["address"].apply(
        lambda x: x.split(" ")[0].lower()
    )
    data_with_street = data_with_street.merge(
        strasse_zu_coord,
        left_on="address_wo_number",
        right_on="name",
        how="left"
    )
    data_with_street = gpd.GeoDataFrame(
        data_with_street,
        geometry=gpd.points_from_xy(
            x=data_with_street["x"], y=data_with_street["y"]
        )
    )

    # Part 2: Process the ones with zip but no (valid) street
    plz_exists_but_no_stret = (~pd.isna(data["zip"])) & pd.isna(
        data["address"]
    )
    # leftover are the ones with plz but no sreets or the ones that we couldn't
    # assign a street to but which have a plz
    leftover = pd.concat(
        [
            data[plz_exists_but_no_stret],
            data_with_street[pd.isna(data_with_street["x"])]
        ]
    ).dropna(subset=["zip"])
    # convert to str
    # leftover["zip"] = leftover["zip"].astype(int).astype(str)

    # set index
    zurich_data = gpd.read_file(os.path.join(path, "zurich.gpkg"))
    zurich_data = zurich_data.set_index("name").sort_index()
    # remove invalid zip codes
    leftover = leftover[leftover["zip"].isin(zurich_data.index)]
    # compute number of required samples
    required_samples_per_zip = leftover.groupby("zip")["zip"].count()
    zurich_data["num"] = required_samples_per_zip
    zurich_data.dropna(inplace=True)
    # Sample points in polygons
    sampled = zurich_data.geometry.sample_points(
        zurich_data["num"].astype(int)
    )
    sampled = gpd.GeoDataFrame(sampled.explode()
                               ).reset_index().drop("level_1", axis=1)
    assert len(sampled) == len(leftover)
    # add as geometry
    leftover.sort_values("zip", inplace=True)
    leftover["geometry"] = sampled["sampled_points"].values

    # final data: the ones with plz (leftover) and the ones where we could
    # find a street
    data_with_geom = pd.concat(
        [leftover, data_with_street.dropna(subset=["x"])]
    ).drop(["x", "y", "name", "address_wo_number"], axis=1)
    data_with_geom = gpd.GeoDataFrame(data_with_geom, geometry="geometry")

    # rename fields to match the pennyme style:
    data_with_geom.rename(
        {
            "Message": "name",
            "Date": "time_posted"
        }, axis=1, inplace=True
    )
    data_with_geom["external_url"] = "null"  # TODO: use telegram chat link?
    data_with_geom["status"] = "showGoods"

    # format the time
    def to_readable_datetime(x):
        return x.strftime("%d/%m/%Y %H:%M")

    data_with_geom["time_posted"] = data_with_geom["time_posted"].apply(
        to_readable_datetime
    )

    # combine zip and address
    def get_full_address(row):
        address = ""
        if not pd.isna(row["address"]):
            address += (str(row["address"]) + " ")
        if not pd.isna(row["zip"]):
            address += str(row["zip"])
        return address

    data_with_geom["address"] = data_with_geom.apply(get_full_address, axis=1)
    data_with_geom = data_with_geom.drop(["zip"], axis=1)

    # Save data
    data_with_geom.to_file(
        os.path.join(OUT_PATH, "data.geojson"), driver="GeoJSON"
    )


def preprocess_streets(
    in_path=os.path.join("geodata", "raw", "strassennamen.json"),
    out_path=os.path.join("geodata", "strassen.csv")
):
    with open(in_path, "r") as infile:
        strassen = json.load(infile)
    # TODO: use full addresses
    # with open(os.path.join("geodata", "raw", "adressen.json"), "r") as infile:
    #     strassen = json.load(infile)
    strasse_zu_coord = {}
    for strasse in strassen["features"]:
        strasse_zu_coord[strasse["properties"]["lokalisationsname"].lower()
                         ] = strasse["geometry"]["coordinates"]
    strasse_zu_coord = pd.DataFrame(strasse_zu_coord,
                                    index=["x", "y"]).swapaxes(1, 0)
    strasse_zu_coord.to_csv(out_path)


def generate_eligible_name_list(
    zurich_data_path=os.path.join("geodata", "zurich.gpkg"),
    out_path=os.path.join("geodata", "place_names.json")
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
        json.dump(
            {
                "names": eligible_names,
                "name_mapping": eligible_name_mapping
            }, outfile
        )


def create_zurich_data(
    in_path="geodata/raw", out_path=os.path.join("geodata", "zurich.gpkg")
):
    # get plz polygons
    plz = gpd.read_file(os.path.join(in_path,
                                     "PLZO_PLZ.shp"))[["PLZ", "geometry"]]
    # get names for plz
    plz_orte = pd.read_csv(
        os.path.join(in_path, "plz_ortsnamen.csv"), delimiter=";"
    )
    plz_orte = plz_orte[plz_orte["Ortschaftsname"] == "Zürich"]
    # merge to keep only the ones in zurich
    plz_zurich = plz.merge(
        plz_orte, how="right", left_on="PLZ", right_on="PLZ"
    )[["PLZ", "geometry"]]
    plz_zurich.rename({"PLZ": "name"}, axis=1, inplace=True)
    plz_zurich["name"] = plz_zurich["name"].astype(str)

    # kreise
    kreise = pd.read_csv(os.path.join(in_path, "stadtkreise.csv"))
    kreise["geometry"] = kreise["geometry"].apply(wkt.loads)
    kreise = gpd.GeoDataFrame(kreise, geometry="geometry")
    kreise = kreise[["bezeichnung",
                     "geometry"]].rename({"bezeichnung": "name"}, axis=1)
    kreise["name"] = kreise["name"].str.lower()

    zurich_data = pd.concat([kreise, plz_zurich])  # project
    zurich_data.geometry.crs = "EPSG:2056"
    zurich_data.to_crs("EPSG:4326", inplace=True)
    zurich_data.to_file(out_path)


if __name__ == "__main__":
    data = pd.read_csv("data.csv")
    create_geojson(data)
