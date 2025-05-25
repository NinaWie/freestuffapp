import os
import json
from datetime import datetime, date
from shutil import move
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from read_write_postings import Postings, DeletedPosts, Base, init_session

# Constants
PATH_COMMENTS = os.path.join("..", "..", "images", "freestuff", "comments")
PATH_IMAGES = os.path.join("..", "..", "images", "freestuff", "images")
PATH_DELETED = os.path.join("..", "..", "images", "freestuff", "deleted")
DELETION_MODE = "expired"

Session = init_session()


def delete_expired_posts():
    session = Session()
    try:
        today = date.today()
        expired_posts = (
            session.query(Postings).filter(Postings.status == "temporary", Postings.expiration_date <= today).all()
        )

        print(f"[{datetime.now()}] Found {len(expired_posts)} expired posts.")

        for post in expired_posts:
            print(f"Deleting expired post {post.id} with name {post.name}...")
            # Move to DeletedPosts
            deleted = DeletedPosts(
                id=post.id,
                name=post.name,
                time_posted=post.time_posted,
                expiration_date=post.expiration_date,
                photo_id=post.photo_id,
                category=post.category,
                subcategory=post.subcategory,
                description=post.description,
                external_url=post.external_url,
                status=post.status,
                geometry=post.geometry,
                deleted_at=datetime.now(),
                deletion_mode=DELETION_MODE,
            )

            session.add(deleted)
            session.delete(post)

            # Move associated comment file
            comment_fn = os.path.join(PATH_COMMENTS, f"{post.id}.json")
            if os.path.exists(comment_fn):
                move(comment_fn, os.path.join(PATH_DELETED, f"{post.id}.json"))

            # Move associated images
            if post.photo_id and not "http" in post.photo_id:
                for pid in post.photo_id.split(","):
                    image_name = f"{post.id}{pid}.jpg"
                    src_path = os.path.join(PATH_IMAGES, image_name)
                    dst_path = os.path.join(PATH_DELETED, image_name)
                    print("move image from", src_path, "to", dst_path)
                    if os.path.exists(src_path):
                        move(src_path, dst_path)

            print(f"Deleted expired post {post.id}")

        session.commit()

    except Exception as e:
        print(f"Error while deleting expired posts: {e}")
        session.rollback()
    finally:
        session.close()


if __name__ == "__main__":
    delete_expired_posts()
