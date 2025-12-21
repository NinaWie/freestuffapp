import json
from shapely.geometry import Point
from datetime import datetime, timedelta
from PIL import Image, ImageOps
import numpy as np
import pandas as pd

# database stuff
import psycopg2
from sqlalchemy import Column, Integer, String, create_engine, DateTime, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from geoalchemy2 import Geometry
from geoalchemy2.shape import from_shape
from geoalchemy2.functions import ST_MakeEnvelope

MAX_RESULTS = 200


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
    __tablename__ = "posts"  # for debugging: telegram_postings

    id = Column(Integer, primary_key=True)
    name = Column(String)
    time_posted = Column(DateTime)
    expiration_date = Column(Date)
    photo_id = Column(String)
    category = Column(String)
    subcategory = Column(String)
    description = Column(String)
    external_url = Column(String)
    status = Column(String)
    user_id = Column(String)
    geometry = Column(Geometry(geometry_type="POINT", srid=4326))


class DeletedPosts(Base):
    __tablename__ = "deleted_posts"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    time_posted = Column(DateTime)
    expiration_date = Column(Date)
    photo_id = Column(String)
    category = Column(String)
    subcategory = Column(String)
    description = Column(String)
    external_url = Column(String)
    status = Column(String)
    user_id = Column(String)
    geometry = Column(Geometry("POINT"))

    deleted_at = Column(DateTime)
    deletion_mode = Column(String)


def insert_posting(data, nr_photos: int = 1):
    session = Session()
    try:
        # Extract and validate fields
        if "geometry" in data:
            geom = from_shape(data["geometry"], srid=4326)
        else:
            lng = data.get("lon_coord")
            lat = data.get("lat_coord")
            if lng is None or lat is None:
                return {"error": "Missing coordinates"}, 400, -1

            geom = from_shape(Point(lng, lat), srid=4326)

        # prepare expiration date
        date_string = data.get("expiration_date", "")
        if len(date_string) > 0:
            expiration_date = datetime.strptime(date_string, "%Y-%m-%d").date()
            status = "temporary"
        else:
            expiration_date = None
            status = "permanent"

        if "time_posted" not in data:
            data["time_posted"] = datetime.now()
        if isinstance(data["time_posted"], pd.Timestamp):
            data["time_posted"] = data["time_posted"].to_pydatetime()

        new_posting = Postings(
            name=data.get("name"),
            time_posted=data["time_posted"],
            expiration_date=expiration_date,
            photo_id=",".join(["_" + str(i) for i in range(nr_photos)]),
            category=data.get("category", "Goods"),
            subcategory=data.get("subcategory", ""),
            description=data.get("description", ""),
            external_url=data.get("external_url"),
            user_id=data.get("user_id", ""),
            status=status,
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


def load_filter_postings(request_args):
    session = Session()

    try:
        # Location bounding box
        nelat = request_args.get("nelat", type=float)
        nelng = request_args.get("nelng", type=float)
        swlat = request_args.get("swlat", type=float)
        swlng = request_args.get("swlng", type=float)

        # Filter parameters
        show_goods = request_args.get("showGoods", default="1") == "1"
        show_food = request_args.get("showFood", default="1") == "1"
        goods_subcategory = request_args.get("goodsSubcategory", default="All")
        food_subcategory = request_args.get("foodSubcategory", default="All")
        time_posted_max_days = request_args.get("timePostedMax", type=float, default=20)
        show_permanent = request_args.get("showPermanent", default="1") == "1"

        query = session.query(Postings)

        # Bounding box filter
        if None not in (nelat, nelng, swlat, swlng):
            envelope = ST_MakeEnvelope(swlng, swlat, nelng, nelat, 4326)
            query = query.filter(Postings.geometry.ST_Within(envelope))

        # Category filters
        category_filters = []
        if show_goods:
            category_filters.append("Goods")
        if show_food:
            category_filters.append("Food")
        # Only need to filter if we only want one of the categories
        if len(category_filters) < 2:
            query = query.filter(Postings.category.in_(category_filters))

        # Subcategory filters
        if goods_subcategory != "All" and show_goods:
            query = query.filter(~((Postings.category == "Goods") & (Postings.subcategory != goods_subcategory)))
        if food_subcategory != "All" and show_food:
            query = query.filter(~((Postings.category == "Food") & (Postings.subcategory != food_subcategory)))

        # Permanent filter
        if not show_permanent:
            query = query.filter(Postings.status != "permanent")

        # Time filter
        cutoff_time = datetime.utcnow() - timedelta(days=time_posted_max_days)
        query = query.filter(Postings.time_posted >= str(cutoff_time))

        # hard limit: 200 posts
        query = query.limit(MAX_RESULTS)

        postings = query.all()

        # print(f"Loaded {len(postings)} posts")

        return postings
    finally:
        session.close()


def process_uploaded_image(img_path: str, basewidth: int = 1000):
    """
    Optimizes an image for size/quality and re-saves it to the server.

    Args:
        img_path: The path to save the image to.
        basewidth: width of rescaled image, defaults to 1000. Used to be 400.
    """
    img = Image.open(img_path)
    img = ImageOps.exif_transpose(img)
    wpercent = basewidth / float(img.size[0])
    if wpercent > 1:
        return "Image uploaded successfully, no resize necessary"
    # resize
    hsize = int((float(img.size[1]) * float(wpercent)))
    img = img.resize((basewidth, hsize), Image.Resampling.LANCZOS)
    img.save(img_path, quality=95)
