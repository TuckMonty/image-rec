import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
import numpy as np
import os

class FeatureExtractor:
    def __init__(self, device=None):
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.model = models.resnet50(pretrained=True)
        self.model = torch.nn.Sequential(*list(self.model.children())[:-1])
        self.model.eval()
        self.model.to(self.device)
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])

    def extract(self, image_path):
        image = Image.open(image_path).convert('RGB')
        img_t = self.transform(image).unsqueeze(0).to(self.device)
        with torch.no_grad():
            features = self.model(img_t).cpu().numpy().flatten()
        return features

def extract_features_by_item(images_root, output_path):
    extractor = FeatureExtractor()
    features = {}
    for item_id in os.listdir(images_root):
        item_path = os.path.join(images_root, item_id)
        if os.path.isdir(item_path):
            item_features = []
            for fname in os.listdir(item_path):
                if fname.lower().endswith((".jpg", ".jpeg", ".png")):
                    fpath = os.path.join(item_path, fname)
                    feat = extractor.extract(fpath)
                    item_features.append(feat)
            if item_features:
                features[item_id] = item_features
    np.save(output_path, features)
    print(f"Saved features for {len(features)} items to {output_path}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Extract features for multiple images per item.")
    parser.add_argument("--input", required=True, help="Root folder with item subfolders")
    parser.add_argument("--output", required=True, help="Output .npy file for features")
    args = parser.parse_args()
    extract_features_by_item(args.input, args.output)
