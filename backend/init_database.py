import json

import pandas as pd
import geopandas as gpd

import psycopg2
from sqlalchemy import create_engine

DB_FILE = "db_login.json"
with open(DB_FILE, "r") as infile:
    db_login = json.load(infile)


def get_con():
    return psycopg2.connect(**db_login)


engine = create_engine("postgresql+psycopg2://", creator=get_con)

from sqlalchemy import Column, Integer, String, create_engine, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

Base = declarative_base()

Session = sessionmaker(bind=engine)


def init_table():
    start_table = gpd.read_file("postings.json")
    start_table.to_postgis("postings", schema="public", if_exists="replace", con=engine, index=False)


if __name__ == "__main__":
    init_table()
