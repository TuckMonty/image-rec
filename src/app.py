from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
import shutil
import os
import numpy as np
from src.feature_extractor import FeatureExtractor
from src.image_database_multi import ImageDatabaseMulti

app = FastAPI()

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
async def upload_image(item_id: str = Form(...), file: UploadFile = File(...)):
    # Save uploaded image to the item's subfolder
    item_dir = os.path.join(DATA_DIR, item_id)
    os.makedirs(item_dir, exist_ok=True)
    file_path = os.path.join(item_dir, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
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
    # Convert numpy.float32 to float for JSON serialization
    return JSONResponse({
        "matches": [
            {"item_id": item_id, "distance": float(dist)}
            for item_id, dist in results
        ]
    })

@app.get("/")
def root():
    return {"message": "Image Recognition API is running."}
