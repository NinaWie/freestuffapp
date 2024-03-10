import json

import pandas as pd
import psycopg2
from sqlalchemy import create_engine
from telethon import TelegramClient, events

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


class MessageTable(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, autoincrement=False)
    message = Column(String)
    sender = Column(String)
    category = Column(String)


def init_table():
    start_table = pd.DataFrame(columns=["id", "message", "sender", "category"])
    start_table.to_sql(
        "messages", schema="public", if_exists="replace", con=engine, index=False
    )


def find_max_id():
    session = Session()
    max_id = session.query(func.max(MessageTable.id)).scalar()
    return max_id


if __name__ == "__main__":
    init_table()
