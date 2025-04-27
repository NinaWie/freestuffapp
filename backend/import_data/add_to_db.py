import os
import json
from shapely.geometry import shape
from sqlalchemy.orm import sessionmaker
from geoalchemy2.shape import from_shape
from datetime import datetime
from sqlalchemy import Column, Integer, String, create_engine, DateTime
import psycopg2
from geoalchemy2 import Geometry
from sqlalchemy.ext.declarative import declarative_base


def init_session():
    """Initialize a database session."""
    DB_FILE = os.path.join("..", "db_login.json")
    with open(DB_FILE, "r") as infile:
        db_login = json.load(infile)

    def get_con():
        return psycopg2.connect(**db_login)

    engine = create_engine("postgresql+psycopg2://", creator=get_con)
    return sessionmaker(bind=engine)


Base = declarative_base()


class Postings(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    time_posted = Column(String)
    photo_id = Column(String)
    category = Column(String)
    description = Column(String)
    external_url = Column(String)
    status = Column(String)
    geometry = Column(Geometry(geometry_type="POINT", srid=4326))


def import_geojson(path):
    # Load GeoJSON file
    with open(path, "r") as f:
        data = json.load(f)

    Session = init_session()
    session = Session()

    for feature in data["features"]:
        geometry = shape(feature["geometry"])
        props = feature["properties"]

        # Convert to WKT for PostGIS
        geo = from_shape(geometry, srid=4326)

        post = Postings(
            name=props.get("name", "Unnamed"),
            time_posted=props["time_posted"],  # adjust if needed
            photo_id=props.get("photo_id"),
            category=props.get("category"),
            description=props.get("description"),
            external_url=props.get("external_url"),
            status=props.get("status", "active"),
            geometry=geo,
        )

        session.add(post)

    session.commit()
    session.close()

    print("Import completed.")


if __name__ == "__main__":
    import_geojson("data/freedges.geojson")
