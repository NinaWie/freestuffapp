import os
import osmnx as ox
import pandas as pd


def get_street_data(city_name: str):
    # Get drivable road network
    G = ox.graph_from_place(city_name, network_type="drive")

    # Convert to GeoDataFrame
    edges = ox.graph_to_gdfs(G, nodes=False)

    # Keep relevant columns
    edges = edges[["name", "geometry"]].dropna()
    edges.to_crs(epsg=2056, inplace=True)

    # Get centroid (approx location of street segment)
    edges["x"] = edges.geometry.centroid.y
    edges["y"] = edges.geometry.centroid.x

    edges.to_crs(epsg=4326, inplace=True)
    print("Number of edges with non-null names:", len(edges))

    # print(edges["name"].apply(type).value_counts())
    # print(edges[edges["name"].apply(lambda x: not isinstance(x, str))])
    # edges = edges[edges["name"].apply(lambda x: isinstance(x, str))]  # keep only streets with valid names
    # Ensure everything is a list
    edges["name"] = edges["name"].apply(lambda x: x if isinstance(x, list) else [x])

    # Explode → one row per name
    edges = edges.explode("name")
    print("Number of edges after exploding lists:", len(edges))

    # Some streets appear multiple times → deduplicate
    df = edges.groupby("name")[["x", "y"]].mean().reset_index()
    # turn name to lower
    df["name"] = df["name"].str.lower()
    print("Number of unique street names:", len(df))
    return df


if __name__ == "__main__":
    out_name = "brutisellen_strassen.csv"
    df = get_street_data("Brüttisellen, Switzerland")
    print(df.head())
    df.to_csv(os.path.join("telegram_utils", "geodata", out_name), index=False)
