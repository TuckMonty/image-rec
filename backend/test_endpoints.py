import requests
import os

API_URL = os.getenv("API_URL", "http://127.0.0.1:8000")

# Test data
TEST_ITEM_ID = "testitem1"
TEST_ITEM_NAME = "Test Item 1"
TEST_IMAGE_PATH = "test_image.jpg"  # Place a test image in the backend directory


def test_upload():
    print("Testing /upload/ ...")
    with open(TEST_IMAGE_PATH, "rb") as img_file:
        files = {"file": (os.path.basename(TEST_IMAGE_PATH), img_file, "image/jpeg")}
        data = {"item_id": TEST_ITEM_ID, "item_name": TEST_ITEM_NAME}
        r = requests.post(f"{API_URL}/upload/", files=files, data=data)
        print("Upload response:", r.status_code, r.json())

def test_list_items():
    print("Testing /items/ ...")
    r = requests.get(f"{API_URL}/items/")
    print("Items response:", r.status_code, r.json())

def test_list_item_images():
    print("Testing /item_images/{item_id} ...")
    r = requests.get(f"{API_URL}/item_images/{TEST_ITEM_ID}")
    print("Item images response:", r.status_code, r.json())

def test_query():
    print("Testing /query/ ...")
    with open(TEST_IMAGE_PATH, "rb") as img_file:
        files = {"file": (os.path.basename(TEST_IMAGE_PATH), img_file, "image/jpeg")}
        data = {"topk": 3}
        r = requests.post(f"{API_URL}/query/", files=files, data=data)
        print("Query response:", r.status_code, r.json())

def test_delete_image():
    print("Testing /item_image/{item_id}/{filename} ...")
    # Get the filename from the DB or use the test image name
    filename = os.path.basename(TEST_IMAGE_PATH)
    r = requests.delete(f"{API_URL}/item_image/{TEST_ITEM_ID}/{filename}")
    print("Delete image response:", r.status_code, r.json())

def test_delete_item():
    print("Testing /item/{item_id} ...")
    r = requests.delete(f"{API_URL}/item/{TEST_ITEM_ID}")
    print("Delete item response:", r.status_code, r.json())

if __name__ == "__main__":
    test_upload()
    test_list_items()
    test_list_item_images()
    test_query()
    test_delete_image()
    test_delete_item()
