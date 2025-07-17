import os
import json

METADATA_PATH = "data/item_metadata.json"

def load_metadata():
    if os.path.exists(METADATA_PATH):
        with open(METADATA_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def save_metadata(metadata):
    with open(METADATA_PATH, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

def add_item_metadata(item_id, item_name):
    metadata = load_metadata()
    metadata[item_id] = item_name
    save_metadata(metadata)

def remove_item_metadata(item_id):
    metadata = load_metadata()
    if item_id in metadata:
        del metadata[item_id]
        save_metadata(metadata)

def get_item_name(item_id):
    metadata = load_metadata()
    return metadata.get(item_id, "")
