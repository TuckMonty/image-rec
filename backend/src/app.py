# Update item metadata endpoint
from fastapi import Body

import os
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))
from fastapi import FastAPI, File, UploadFile, Form, Path, Query
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
import os
import numpy as np

from .feature_extractor import FeatureExtractor
from .image_database_multi import ImageDatabaseMulti
from .db import SessionLocal, Item, Image, Base, engine
from sqlalchemy.orm import Session
from .storage import upload_fileobj_to_s3, generate_presigned_url, delete_file_from_s3

app = FastAPI()

# Create database tables on startup if they don't exist
Base.metadata.create_all(bind=engine)

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

# def update_features():
#     # This function is no longer needed since we use database-based FAISS index
#     # Re-extract features for all images in DATA_DIR, grouped by item (subfolder)
#     features = {}
#     for item_id in os.listdir(DATA_DIR):
#         item_path = os.path.join(DATA_DIR, item_id)
#         if os.path.isdir(item_path):
#             item_features = []
#             for fname in os.listdir(item_path):
#                 if fname.lower().endswith((".jpg", ".jpeg", ".png")):
#                     fpath = os.path.join(item_path, fname)
#                     feat = extractor.extract(fpath)
#                     item_features.append(feat)
#             if item_features:
#                 features[item_id] = item_features
#     np.save(FEATURES_PATH, features)



@app.post("/upload/")
async def upload_image(item_id: str = Form(...), file: UploadFile = File(...), item_name: str = Form(None), meta_text: str = Form(None)):
    import tempfile
    db: Session = SessionLocal()
    # Ensure item exists or create it
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        item = Item(id=item_id, name=item_name or item_id, meta_text=meta_text)
        db.add(item)
        db.commit()
        db.refresh(item)
        # Prepare item dict before session closes
        item_dict = {
            "item_id": item.id,
            "item_name": item.name,
            "meta_text": item.meta_text,
            "ctime": item.created_at.timestamp() if item.created_at else 0
        }
    else:
        if meta_text is not None:
            item.meta_text = meta_text
            db.commit()
        item_dict = {
            "item_id": item.id,
            "item_name": item.name,
            "meta_text": item.meta_text,
            "ctime": item.created_at.timestamp() if item.created_at else 0
        }
    # Read file content into memory once
    from io import BytesIO
    file.file.seek(0)
    file_bytes = file.file.read()
    s3_key = f"{item_id}/{file.filename}"
    # Upload to S3 from memory
    upload_fileobj_to_s3(BytesIO(file_bytes), s3_key, content_type=file.content_type)
    # Save to temp file for feature extraction
    suffix = os.path.splitext(file.filename)[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(file_bytes)
        temp_path = tmp.name
    feat = extractor.extract(temp_path)
    feat_bytes = np.asarray(feat, dtype=np.float32).tobytes()
    os.remove(temp_path)
    # Add image record to DB with vector
    image = Image(item_id=item_id, filename=file.filename, s3_key=s3_key, vector=feat_bytes)
    db.add(image)
    db.commit()
    db.refresh(image)
    # Rebuild FAISS index after adding new image
    rebuild_faiss_index()
    presigned_url = generate_presigned_url(s3_key)
    db.close()
    return {
        "item": item_dict,
        "filename": file.filename,
        "s3_key": s3_key,
        "url": presigned_url,
        "meta_text": item_dict["meta_text"],
        "status": "uploaded to S3 and DB with vector"
    }


import faiss

# Helper to load all vectors from DB into FAISS
def build_faiss_index():
    db: Session = SessionLocal()
    images = db.query(Image).filter(Image.vector != None).all()
    if not images:
        db.close()
        return None, [], []
    vectors = [np.frombuffer(img.vector, dtype=np.float32) for img in images]
    vectors = np.stack(vectors).astype('float32')
    index = faiss.IndexFlatL2(vectors.shape[1])
    index.add(vectors)
    db.close()
    return index, images, vectors

faiss_index, faiss_images, faiss_vectors = build_faiss_index()

def rebuild_faiss_index():
    """Rebuild the global FAISS index after database changes"""
    global faiss_index, faiss_images, faiss_vectors
    faiss_index, faiss_images, faiss_vectors = build_faiss_index()

@app.post("/query/")
async def query_image(file: UploadFile = File(...), topk: int = Form(5)):
    import tempfile
    global faiss_index, faiss_images, faiss_vectors
    with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as tmp:
        shutil.copyfileobj(file.file, tmp)
        temp_path = tmp.name
    query_feat = extractor.extract(temp_path)
    os.remove(temp_path)
    if faiss_index is None or len(faiss_images) == 0:
        return JSONResponse({"matches": []})
    query_feat = np.asarray(query_feat, dtype=np.float32).reshape(1, -1)
    D, I = faiss_index.search(query_feat, min(topk, len(faiss_images)))
    matches = []
    for idx, dist in zip(I[0], D[0]):
        if idx < len(faiss_images):
            img = faiss_images[idx]
            preview_url = generate_presigned_url(img.s3_key) if hasattr(img, "s3_key") else None
            matches.append({
                "item_id": img.item_id,
                "filename": img.filename,
                "distance": float(dist),
                "preview_image": preview_url
            })
    return JSONResponse({"matches": matches})



@app.delete("/item/{item_id}")
async def delete_item(item_id: str):
    db: Session = SessionLocal()
    # Delete all images for this item from S3 and DB
    images = db.query(Image).filter(Image.item_id == item_id).all()
    for img in images:
        try:
            delete_file_from_s3(img.s3_key)
        except Exception:
            pass
        db.delete(img)
    # Delete item
    item = db.query(Item).filter(Item.id == item_id).first()
    if item:
        db.delete(item)
    db.commit()
    db.close()
    rebuild_faiss_index()  # Rebuild FAISS index after deletion
    return {"item_id": item_id, "status": "deleted from S3 and DB"}



@app.delete("/item_image/{item_id}/{filename}")
def delete_item_image(item_id: str, filename: str):
    db: Session = SessionLocal()
    image = db.query(Image).filter(Image.item_id == item_id, Image.filename == filename).first()
    if image:
        try:
            delete_file_from_s3(image.s3_key)
        except Exception:
            pass
        db.delete(image)
        db.commit()
        db.close()
        rebuild_faiss_index()  # Rebuild FAISS index after deletion
        return {"item_id": item_id, "filename": filename, "status": "deleted from S3 and DB"}
    db.close()
    return {"error": "File not found in DB"}

@app.get("/")
def root():
    return {"message": "Image Recognition API is running."}

@app.post("/item/{item_id}/metadata")
async def update_item_metadata(item_id: str = Path(...), meta_text: str = Body(...)):
    db: Session = SessionLocal()
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        db.close()
        return JSONResponse({"error": "Item not found"}, status_code=404)
    item.meta_text = meta_text
    db.commit()
    db.close()
    return {"item_id": item_id, "meta_text": meta_text, "status": "updated"}


@app.get("/items/")
def list_items():
    db: Session = SessionLocal()
    items = db.query(Item).all()
    result = []
    for item in items:
        # Get preview image (first image)
        images = item.images
        preview_url = None
        if images:
            preview_url = generate_presigned_url(images[0].s3_key)
        result.append({
            "item_id": item.id,
            "item_name": item.name,
            "preview_image": preview_url,
            "meta_text": getattr(item, "meta_text", None),
            "ctime": item.created_at.timestamp() if item.created_at else 0
        })
    db.close()
    result.sort(key=lambda x: x["ctime"])
    return {"items": result}

@app.get("/items/recent")
def get_recent_items(limit: int = Query(3, ge=1)):
    db: Session = SessionLocal()
    items = db.query(Item).order_by(Item.created_at.desc()).limit(limit).all()
    result = []
    for item in items:
        images = item.images
        preview_url = None
        if images:
            preview_url = generate_presigned_url(images[0].s3_key)
        result.append({
            "item_id": item.id,
            "item_name": item.name,
            "preview_image": preview_url,
            "meta_text": getattr(item, "meta_text", None),
            "ctime": item.created_at.timestamp() if item.created_at else 0
        })
    db.close()
    return {"items": result}

@app.get("/item_image/{item_id}/{filename}")
def serve_item_image(item_id: str = Path(...), filename: str = Path(...)):
    db: Session = SessionLocal()
    image = db.query(Image).filter(Image.item_id == item_id, Image.filename == filename).first()
    if image:
        url = generate_presigned_url(image.s3_key)
        db.close()
        return {"url": url}
    db.close()
    return {"error": "Image not found"}


@app.get("/item_images/{item_id}")
def list_item_images(item_id: str):
    db: Session = SessionLocal()
    images = db.query(Image).filter(Image.item_id == item_id).all()
    urls = [generate_presigned_url(img.s3_key) for img in images]
    db.close()
    return {"images": urls}
