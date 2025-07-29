from sqlalchemy import create_engine, Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
import os
from datetime import datetime
import os
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))

# Example: postgresql://user:password@host:port/dbname
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/image_rec")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Item(Base):
    __tablename__ = "items"
    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    meta_text = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    images = relationship("Image", back_populates="item")


from sqlalchemy.dialects.postgresql import BYTEA
import numpy as np

class Image(Base):
    __tablename__ = "images"
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(String, ForeignKey("items.id"), nullable=False)
    filename = Column(String, nullable=False)
    s3_key = Column(String, nullable=False)
    vector = Column(BYTEA, nullable=True)  # Store feature vector as bytes
    created_at = Column(DateTime, default=datetime.utcnow)
    item = relationship("Item", back_populates="images")

# Utility to create tables
if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
