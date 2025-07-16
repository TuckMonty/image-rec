import numpy as np
import faiss
import os

class ImageDatabase:
    def __init__(self, features_path):
        self.features_path = features_path
        self.filenames = []
        self.features = None
        self.index = None
        self._load_features()
        self._build_index()

    def _load_features(self):
        data = np.load(self.features_path, allow_pickle=True).item()
        self.filenames = list(data.keys())
        self.features = np.stack([data[f] for f in self.filenames]).astype('float32')

    def _build_index(self):
        dim = self.features.shape[1]
        self.index = faiss.IndexFlatL2(dim)
        self.index.add(self.features)

    def search(self, query_feature, top_k=5):
        query_feature = np.array(query_feature).astype('float32').reshape(1, -1)
        D, I = self.index.search(query_feature, top_k)
        results = [(self.filenames[i], float(D[0][idx])) for idx, i in enumerate(I[0])]
        return results

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Search for similar images in the database.")
    parser.add_argument("--features", required=True, help="Path to .npy features file")
    parser.add_argument("--query", required=True, help="Path to query image")
    parser.add_argument("--topk", type=int, default=5, help="Number of top matches to return")
    args = parser.parse_args()

    from feature_extractor import FeatureExtractor
    extractor = FeatureExtractor()
    query_feat = extractor.extract(args.query)
    db = ImageDatabase(args.features)
    results = db.search(query_feat, top_k=args.topk)
    print("Top matches:")
    for fname, dist in results:
        print(f"{fname}\tDistance: {dist:.4f}")
