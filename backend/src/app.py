from fastapi import FastAPI, File, UploadFile, Form, Path
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
import os
import numpy as np
from .feature_extractor import FeatureExtractor
from .image_database_multi import ImageDatabaseMulti
from .item_metadata import add_item_metadata, remove_item_metadata, get_item_name
from .item_list import get_item_list, get_item_image, get_item_images

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development, allow all. For production, specify allowed origins.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATA_DIR = "data/images"
FEATURES_PATH = "data/features_multi.npy"

os.makedirs(DATA_DIR, exist_ok=True)
extractor = FeatureExtractor()

def update_features():
    # Re-extract features for all images in DATA_DIR, grouped by item (subfolder)
    features = {}
    for item_id in os.listdir(DATA_DIR):
        item_path = os.path.join(DATA_DIR, item_id)
        if os.path.isdir(item_path):
            item_features = []
            for fname in os.listdir(item_path):
                if fname.lower().endswith((".jpg", ".jpeg", ".png")):
                    fpath = os.path.join(item_path, fname)
                    feat = extractor.extract(fpath)
                    item_features.append(feat)
            if item_features:
                features[item_id] = item_features
    np.save(FEATURES_PATH, features)

@app.post("/upload/")
async def upload_image(item_id: str = Form(...), file: UploadFile = File(...), item_name: str = Form(None)):
    # Save uploaded image to the item's subfolder
    item_dir = os.path.join(DATA_DIR, item_id)
    os.makedirs(item_dir, exist_ok=True)
    file_path = os.path.join(item_dir, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    # Save item name if provided
    if item_name:
        add_item_metadata(item_id, item_name)
    update_features()
    return {"item_id": item_id, "filename": file.filename, "status": "uploaded and features updated"}

@app.post("/query/")
async def query_image(file: UploadFile = File(...), topk: int = Form(5)):
    temp_path = os.path.join(DATA_DIR, "_query_temp_" + file.filename)
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    query_feat = extractor.extract(temp_path)
    db = ImageDatabaseMulti(FEATURES_PATH)
    results = db.search(query_feat, top_k=topk)
    os.remove(temp_path)
    return JSONResponse({
        "matches": [
            {"item_id": item_id, "item_name": get_item_name(item_id), "distance": float(dist)}
            for item_id, dist in results
        ]
    })

@app.delete("/item/{item_id}")
async def delete_item(item_id: str):
    # Remove item images
    item_dir = os.path.join(DATA_DIR, item_id)
    if os.path.isdir(item_dir):
        for fname in os.listdir(item_dir):
            os.remove(os.path.join(item_dir, fname))
        os.rmdir(item_dir)
    # Remove metadata
    remove_item_metadata(item_id)
    update_features()
    return {"item_id": item_id, "status": "deleted"}

@app.delete("/item_image/{item_id}/{filename}")
def delete_item_image(item_id: str, filename: str):
    item_dir = os.path.join(DATA_DIR, item_id)
    file_path = os.path.join(item_dir, filename)
    if os.path.isfile(file_path):
        os.remove(file_path)
        update_features()
        return {"item_id": item_id, "filename": filename, "status": "deleted"}
    return {"error": "File not found"}

@app.get("/")
def root():
    return {"message": "Image Recognition API is running."}

@app.get("/items/")
def list_items():
    return {"items": get_item_list()}

@app.get("/item_image/{item_id}/{filename}")
def serve_item_image(item_id: str = Path(...), filename: str = Path(...)):
    return get_item_image(item_id, filename)

@app.get("/item_images/{item_id}")
def list_item_images(item_id: str):
    return {"images": get_item_images(item_id)}
