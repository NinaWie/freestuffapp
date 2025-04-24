import json
import os
import queue
import random
import traceback
from datetime import datetime
from threading import Thread
from typing import Any, Dict
import pandas as pd
from flask import Flask, jsonify, request
from shapely.geometry import Point

# database stuff
import psycopg2
from sqlalchemy import Column, Integer, String, create_engine, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import Column, Integer, String, DateTime, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.declarative import declarative_base
from geoalchemy2 import Geometry
from geoalchemy2.shape import from_shape
from flask import jsonify
from shapely.geometry import mapping
from geoalchemy2.shape import to_shape


def init_session():
    """Initialize a database session."""
    DB_FILE = "db_login.json"
    with open(DB_FILE, "r") as infile:
        db_login = json.load(infile)

    def get_con():
        return psycopg2.connect(**db_login)

    engine = create_engine("postgresql+psycopg2://", creator=get_con)
    return sessionmaker(bind=engine)


Session = init_session()
Base = declarative_base()
app = Flask(__name__)


class Postings(Base):
    __tablename__ = "postings"

    id = Column(Integer, primary_key=True)
    Sender = Column(String)
    name = Column(String)
    time_posted = Column(DateTime)
    photo_id = Column(String)
    category = Column(String)
    address = Column(String)
    external_url = Column(String)
    status = Column(String)
    geometry = Column(Geometry(geometry_type="POINT", srid=4326))


def insert_posting(data):
    session = Session()
    try:
        # Extract and validate fields
        lng = data.get("longitude")
        lat = data.get("latitude")
        if lng is None or lat is None:
            return {"error": "Missing coordinates"}, 400

        geom = from_shape(Point(lng, lat), srid=4326)

        new_posting = Postings(
            Sender=data.get("Sender"),
            name=data.get("name"),
            time_posted=datetime.fromisoformat(data.get("time_posted")),
            photo_id=data.get("photo_id"),
            category=data.get("category"),
            address=data.get("address"),
            external_url=data.get("external_url"),
            status=data.get("status"),
            geometry=geom,
        )

        session.add(new_posting)
        session.commit()
        return {"status": "success", "id": new_posting.id}
    except Exception as e:
        session.rollback()
        return {"error": str(e)}, 500
    finally:
        session.close()


@app.route("/api/insert_post", methods=["POST"])
def create_posting():
    data = request.get_json()
    return insert_posting(data)


@app.route("/api/postings.json", methods=["GET"])
def get_all_postings():
    session = Session()
    try:
        postings = session.query(Postings).all()
        features = []
        for post in postings:
            geom = to_shape(post.geometry)
            feature = {
                "type": "Feature",
                "geometry": mapping(geom),
                "properties": {
                    "id": post.id,
                    "Sender": post.Sender,
                    "name": post.name,
                    "time_posted": post.time_posted,
                    "photo_id": post.photo_id,
                    "category": post.category,
                    "address": post.address,
                    "external_url": post.external_url,
                    "status": post.status,
                },
            }
            features.append(feature)

        return jsonify({"type": "FeatureCollection", "features": features})
    finally:
        session.close()


if __name__ == "__main__":
    app.run(debug=True, port=5000)

# if __name__ == "__main__":
#     test_data = {
#         "Sender": "Alice",
#         "name": "Cool Place",
#         "time_posted": "2025-04-24T15:30:00",
#         "photo_id": "abc123",
#         "category": "parks",
#         "address": "123 Main St",
#         "external_url": "http://example.com",
#         "status": "active",
#         "longitude": 13.405,
#         "latitude": 52.52,
#     }
#     print(insert_posting(test_data))
