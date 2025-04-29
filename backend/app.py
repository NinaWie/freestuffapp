import json
import os
from datetime import datetime
from typing import Any, Dict
import pandas as pd
from flask import Flask, jsonify, request

# slack
from slack import WebClient
from slack.errors import SlackApiError

# database stuff
from flask import jsonify
from shapely.geometry import mapping
from geoalchemy2.shape import to_shape
from geoalchemy2.functions import ST_MakeEnvelope

from read_write_postings import insert_posting, Session, Postings, DeletedPosts, process_uploaded_image

with open("blocked_ips.json", "r") as infile:
    # NOTE: blocking an IP requires restart of app.py via waitress
    blocked_ips = json.load(infile)

# dictionary with comment by IP address - used to block predatory ips
with open("ip_comment_dict.json", "r") as f:
    IP_COMMENT_DICT = json.load(f)


PATH_COMMENTS = os.path.join("..", "..", "images", "freestuff", "comments")
PATH_IMAGES = os.path.join("..", "..", "images", "freestuff", "images")
PATH_DELETED = os.path.join("..", "..", "images", "freestuff", "deleted")
CLIENT = WebClient(token=os.environ["SLACK_TOKEN"])

app = Flask(__name__)


def post_to_slack(message: str) -> None:
    """Post message to Slack channel."""
    try:
        CLIENT.chat_postMessage(channel="#freestuff", text=message, username="PennyMe")
    except SlackApiError as e:
        assert e.response["ok"] is False
        assert e.response["error"]
        raise e


@app.route("/add_post", methods=["POST"])
def create_posting():
    ip_address = request.remote_addr
    if ip_address in blocked_ips:
        return jsonify({"error": "User IP address is blocked"}), 403

    post_infos = request.args.to_dict()
    jsonify_result, error_code, new_post_id = insert_posting(post_infos, nr_photos=len(request.files))

    # Error case: send error to frontend and slack
    if error_code != 200:
        post_to_slack(f"Error adding post: {jsonify_result['error']}")
        return jsonify_result, error_code

    # Process images
    # if len(request.files) == 0:
    #     return jsonify({"error": "No image file found"}), 400

    for idx, img_file in enumerate(request.files):
        img_path = os.path.join(PATH_IMAGES, f"{new_post_id}_{idx}.jpg")
        request.files[img_file].save(img_path)
        process_uploaded_image(img_path)

    # send message to slack
    post_to_slack(f"New post added: {post_infos}")

    return jsonify_result, error_code


@app.route("/postings.json", methods=["GET"])
def get_all_postings():
    session = Session()
    try:
        # Check for bounding box parameters
        nelat = request.args.get("nelat", type=float)
        nelng = request.args.get("nelng", type=float)
        swlat = request.args.get("swlat", type=float)
        swlng = request.args.get("swlng", type=float)

        query = session.query(Postings)

        if None not in (nelat, nelng, swlat, swlng):
            envelope = ST_MakeEnvelope(swlng, swlat, nelng, nelat, 4326)
            query = query.filter(Postings.geometry.ST_Within(envelope))

        postings = query.all()

        features = []
        for post in postings:
            geom = to_shape(post.geometry)
            feature = {
                "type": "Feature",
                "geometry": mapping(geom),
                "properties": {
                    "id": post.id,
                    "name": post.name,
                    "time_posted": post.time_posted.split(".")[0][:-3],
                    "photo_id": post.photo_id,
                    "category": post.category,
                    "description": post.description,
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

    post_to_slack(f"New comment for post {post_id}: {comment}")

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
    mode = request.args.get("mode", "pickup")

    session = Session()
    try:
        post = session.query(Postings).filter_by(id=post_id).first()
        if not post:
            return {"error": "Post not found"}, 404
        # Create a DeletedPosts object using data from the original post
        deleted = DeletedPosts(
            id=post.id,
            name=post.name,
            time_posted=post.time_posted,
            photo_id=post.photo_id,
            category=post.category,
            description=post.description,
            external_url=post.external_url,
            status=post.status,
            geometry=post.geometry,
            deleted_at=datetime.now(),
            deletion_mode=mode,
        )

        # Add to deleted_posts and remove from postings
        session.add(deleted)
        session.delete(post)
        session.commit()

        post_to_slack(f"Deleted post {post_id} ({mode})")

        # move images to deleted folder
        photo_ids = post.photo_id.split(",")
        for photo_id in photo_ids:
            photo_fn = f"{post_id}{photo_id}.jpg"
            os.rename(os.path.join(PATH_IMAGES, photo_fn), os.path.join(PATH_DELETED, photo_fn))
        # remove comment file
        comment_fn = os.path.join(PATH_COMMENTS, f"{post_id}.json")
        if os.path.exists(comment_fn):
            os.rename(comment_fn, os.path.join(PATH_DELETED, f"{post_id}.json"))

        return {"status": "success", "message": f"Post {post_id} deleted."}, 200
    except Exception as e:
        session.rollback()
        post_to_slack(f"Error in deletion of {post_id}: {e}")
        return {"error": str(e)}, 500
    finally:
        session.close()


if __name__ == "__main__":
    app.run(debug=True, port=5000)
