import json
from shapely.geometry import Point
from datetime import datetime

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
    print("Received data:", data)
    try:
        # Extract and validate fields
        lng = data.get("lon_coord")
        lat = data.get("lat_coord")
        if lng is None or lat is None:
            return {"error": "Missing coordinates"}, 400

        geom = from_shape(Point(lng, lat), srid=4326)

        new_posting = Postings(
            Sender=data.get("Sender", "Anonymous"),
            name=data.get("name"),
            time_posted=datetime.now(),
            photo_id=data.get("photo_id", "TODO_Photo_ID"),
            category=data.get("category", "TODO_Category"),
            address=data.get("address"),
            external_url=data.get("external_url", "TODO_URL"),
            status=data.get("status", "available"),
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
