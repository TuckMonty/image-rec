
import os
import json
from fastapi import HTTPException
from .storage import generate_presigned_url

METADATA_PATH = "data/item_metadata.json"

def load_metadata():
    if os.path.exists(METADATA_PATH):
        with open(METADATA_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def get_item_list():
    metadata = load_metadata()
    items = []
    for item_id, item_name in metadata.items():
        # For S3, we assume images are stored as <item_id>/<filename>
        # Here, just list one preview image per item (e.g., first image)
        # In production, image keys should be stored in the DB/metadata
        # For now, we mock with a single preview per item
        # This should be replaced with a DB query in a real app
        preview_s3_key = f"{item_id}/preview.jpg"  # Placeholder: replace with actual logic
        preview_url = generate_presigned_url(preview_s3_key)
        items.append({
            "item_id": item_id,
            "item_name": item_name,
            "preview_image": preview_url,
            "ctime": 0  # Placeholder
        })
    # Sort by ctime (most recent last)
    items.sort(key=lambda x: x["ctime"])
    return items

def get_item_image(item_id, filename):
    s3_key = f"{item_id}/{filename}"
    try:
        url = generate_presigned_url(s3_key)
        return {"url": url}
    except Exception:
        raise HTTPException(status_code=404, detail="Image not found")

def get_item_images(item_id):
    # In production, list images from DB or S3
    # Here, return a list of presigned URLs for all images for the item
    # Placeholder: return a single preview image
    s3_key = f"{item_id}/preview.jpg"  # Replace with actual logic
    return [generate_presigned_url(s3_key)]
