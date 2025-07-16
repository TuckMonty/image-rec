import requests
import os

API_URL = "http://127.0.0.1:8000/upload/"
IMAGES_ROOT = "data/images_test"  # Each subfolder is an item_id

def batch_upload_items(images_root):
    for item_id in os.listdir(images_root):
        item_path = os.path.join(images_root, item_id)
        print(f"Processing item: {item_id}")
        if os.path.isdir(item_path):
            for fname in os.listdir(item_path):
                if fname.lower().endswith((".jpg", ".jpeg", ".png")):
                    fpath = os.path.join(item_path, fname)
                    with open(fpath, "rb") as img_file:
                        files = {"file": (fname, img_file, "image/jpeg")}
                        data = {"item_id": item_id}
                        response = requests.post(API_URL, files=files, data=data)
                        print(f"Uploaded {fname} for item {item_id}: {response.json()}")

if __name__ == "__main__":
    batch_upload_items(IMAGES_ROOT)
