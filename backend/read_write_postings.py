import json
from shapely.geometry import Point
from datetime import datetime

# database stuff
import psycopg2
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from geoalchemy2 import Geometry
from geoalchemy2.shape import from_shape


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
    name = Column(String)
    time_posted = Column(DateTime)
    photo_id = Column(String)
    category = Column(String)
    address = Column(String)
    external_url = Column(String)
    status = Column(String)
    geometry = Column(Geometry(geometry_type="POINT", srid=4326))


class DeletedPosts(Base):
    __tablename__ = "deleted_posts"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    time_posted = Column(DateTime)
    photo_id = Column(String)
    category = Column(String)
    address = Column(String)
    external_url = Column(String)
    status = Column(String)
    geometry = Column(Geometry("POINT"))

    deleted_at = Column(DateTime)
    deletion_mode = Column(String)


def insert_posting(data):
    session = Session()
    try:
        # Extract and validate fields
        lng = data.get("lon_coord")
        lat = data.get("lat_coord")
        if lng is None or lat is None:
            return {"error": "Missing coordinates"}, 400

        geom = from_shape(Point(lng, lat), srid=4326)

        new_posting = Postings(
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
        session.flush()  # This sends the insert query to the DB but doesn't commit yet
        # get ID created for the post
        new_post_id = new_posting.id

        session.commit()
        return {"status": "success", "id": new_posting.id}, 200, new_post_id
    except Exception as e:
        print("Error:", e)
        session.rollback()
        return {"error": str(e)}, 500, None
    finally:
        session.close()
