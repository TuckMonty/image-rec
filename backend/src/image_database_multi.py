import numpy as np
import faiss
import os

class ImageDatabaseMulti:
    def __init__(self, features_path):
        self.features_path = features_path
        self.item_ids = []
        self.features = None  # shape: (total_images, feature_dim)
        self.item_image_map = []  # list of (item_id, image_idx)
        self.index = None
        self._load_features()
        self._build_index()

    def _load_features(self):
        data = np.load(self.features_path, allow_pickle=True).item()
        all_features = []
        self.item_ids = list(data.keys())
        self.item_image_map = []
        for item_id in self.item_ids:
            feats = data[item_id]
            for f in feats:
                all_features.append(f)
                self.item_image_map.append(item_id)
        self.features = np.stack(all_features).astype('float32')

    def _build_index(self):
        dim = self.features.shape[1]
        self.index = faiss.IndexFlatL2(dim)
        self.index.add(self.features)

    def search(self, query_feature, top_k=5):
        query_feature = np.array(query_feature).astype('float32').reshape(1, -1)
        D, I = self.index.search(query_feature, len(self.features))
        # Aggregate by item: take the best (min) distance for each item
        item_best = {}
        for idx, dist in zip(I[0], D[0]):
            item_id = self.item_image_map[idx]
            if item_id not in item_best or dist < item_best[item_id]:
                item_best[item_id] = dist
        # Sort by best distance and return top_k
        sorted_items = sorted(item_best.items(), key=lambda x: x[1])[:top_k]
        return sorted_items

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Search for similar items in the database (multi-image per item).")
    parser.add_argument("--features", required=True, help="Path to .npy features file")
    parser.add_argument("--query", required=True, help="Path to query image")
    parser.add_argument("--topk", type=int, default=5, help="Number of top matches to return")
    args = parser.parse_args()

    from .feature_extractor import FeatureExtractor
    extractor = FeatureExtractor()
    query_feat = extractor.extract(args.query)
    db = ImageDatabaseMulti(args.features)
    results = db.search(query_feat, top_k=args.topk)
    print("Top matches:")
    for item_id, dist in results:
        print(f"{item_id}\tDistance: {dist:.4f}")
