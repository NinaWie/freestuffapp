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


from read_write_postings import insert_posting, Session, Postings

with open("blocked_ips.json", "r") as infile:
    # NOTE: blocking an IP requires restart of app.py via waitress
    blocked_ips = json.load(infile)

# dictionary with comment by IP address - used to block predatory ips
with open("ip_comment_dict.json", "r") as f:
    IP_COMMENT_DICT = json.load(f)


PATH_COMMENTS = os.path.join("..", "..", "images", "freestuff", "comments")
PATH_IMAGES = os.path.join("..", "..", "images", "freestuff", "images")

app = Flask(__name__)


@app.route("/add_post", methods=["POST"])
def create_posting():
    post_infos = request.args.to_dict()
    return insert_posting(post_infos)


@app.route("/postings.json", methods=["GET"])
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


@app.route("/add_comment", methods=["GET"])
def add_comment():
    """Receives a comment and adds it to the json file."""

    comment = str(request.args.get("comment"))
    post_id = str(request.args.get("id"))

    ip_address = request.remote_addr
    if ip_address in blocked_ips:
        return jsonify({"error": "User IP address is blocked"}), 403

    path_machine_comments = os.path.join(PATH_COMMENTS, f"{post_id}.json")
    if os.path.exists(path_machine_comments):
        with open(path_machine_comments, "r") as infile:
            # take previous comments and add paragaph
            all_comments = json.load(infile)
    else:
        all_comments = {}

    all_comments[str(datetime.now())] = comment

    with open(path_machine_comments, "w") as outfile:
        json.dump(all_comments, outfile, indent=4)

    # send message to slack
    # message_slack(machine_id, comment, ip=ip_address)

    save_comment(comment, ip_address, post_id)

    return jsonify({"message": "Success!"}), 200


def save_comment(comment: str, ip: str, machine_id: int):
    """
    Saves a comment to the json file.

    Args:
        comment: The comment to save.
        ip: The IP address of the user.
        machine_id: The ID of the machine.
    """
    # Create dict hierarchy if needed
    if ip not in IP_COMMENT_DICT.keys():
        IP_COMMENT_DICT[ip] = {}
    if machine_id not in IP_COMMENT_DICT[ip].keys():
        IP_COMMENT_DICT[ip][machine_id] = {}

    # Add comment
    IP_COMMENT_DICT[ip][machine_id][str(datetime.now())] = comment

    # Resave the file
    with open("ip_comment_dict.json", "w") as f:
        json.dump(IP_COMMENT_DICT, f, indent=4)


@app.route("/delete_post/<int:post_id>", methods=["DELETE"])
def delete_post(post_id):
    session = Session()
    try:
        post = session.query(Postings).filter_by(id=post_id).first()
        if not post:
            return {"error": "Post not found"}, 404

        session.delete(post)
        session.commit()
        return {"status": "success", "message": f"Post {post_id} deleted."}, 200
    except Exception as e:
        session.rollback()
        return {"error": str(e)}, 500
    finally:
        session.close()


if __name__ == "__main__":
    app.run(debug=True, port=5000)
