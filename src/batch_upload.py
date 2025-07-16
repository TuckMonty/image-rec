import requests
import os

API_URL = "http://127.0.0.1:8000/upload/"
IMAGES_DIR = "data/images_test"  # Change to your test images folder

def upload_images(images_dir):
    for fname in os.listdir(images_dir):
        if fname.lower().endswith((".jpg", ".jpeg", ".png")):
            fpath = os.path.join(images_dir, fname)
            with open(fpath, "rb") as img_file:
                files = {"file": (fname, img_file, "image/jpeg")}
                response = requests.post(API_URL, files=files)
                print(f"Uploaded {fname}: {response.json()}")

if __name__ == "__main__":
    upload_images(IMAGES_DIR)
