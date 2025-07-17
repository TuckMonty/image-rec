import os
import json
from fastapi.responses import FileResponse
from fastapi import HTTPException

METADATA_PATH = "data/item_metadata.json"
DATA_DIR = "data/images"

def load_metadata():
    if os.path.exists(METADATA_PATH):
        with open(METADATA_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def get_item_list():
    metadata = load_metadata()
    items = []
    for item_id, item_name in metadata.items():
        item_dir = os.path.join(DATA_DIR, item_id)
        if os.path.isdir(item_dir):
            images = [f for f in os.listdir(item_dir) if f.lower().endswith((".jpg", ".jpeg", ".png"))]
            if images:
                # Use file creation time for sorting
                first_image = min(images, key=lambda f: os.path.getctime(os.path.join(item_dir, f)))
                first_image_path = os.path.join(item_dir, first_image)
                ctime = os.path.getctime(first_image_path)
                items.append({
                    "item_id": item_id,
                    "item_name": item_name,
                    "preview_image": f"/item_image/{item_id}/{first_image}",
                    "ctime": ctime
                })
    # Sort by ctime (most recent last)
    items.sort(key=lambda x: x["ctime"])
    return items

def get_item_image(item_id, filename):
    item_dir = os.path.join(DATA_DIR, item_id)
    file_path = os.path.join(item_dir, filename)
    if os.path.isfile(file_path):
        return FileResponse(file_path)
    raise HTTPException(status_code=404, detail="Image not found")

def get_item_images(item_id):
    item_dir = os.path.join(DATA_DIR, item_id)
    if os.path.isdir(item_dir):
        images = [f for f in os.listdir(item_dir) if f.lower().endswith((".jpg", ".jpeg", ".png"))]
        return images
    return []
