#!/usr/bin/env python3
"""Exports BioCLIP to ONNX for mtj-id: visual.onnx (fp32), visual.int8.onnx (dynamic int8), text.onnx (fp32).
  MODEL=hf-hub:imageomics/bioclip-2 export_onnx.py <out_dir>        (run by mtj-id-refs.sh; needs torch + open_clip + onnx + onnxruntime)"""
import os, sys
from pathlib import Path
import torch, open_clip
from onnxruntime.quantization import quantize_dynamic, QuantType

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
model, _, pre = open_clip.create_model_and_transforms(os.environ.get("MODEL", "hf-hub:imageomics/bioclip-2"))
model.eval()
for p in model.parameters():
    p.requires_grad_(False)


class V(torch.nn.Module):
    def __init__(self):
        super().__init__(); self.m = model

    def forward(self, x):
        e = self.m.encode_image(x)
        return e / e.norm(dim=-1, keepdim=True)


class T(torch.nn.Module):
    def __init__(self):
        super().__init__(); self.m = model

    def forward(self, t):
        e = self.m.encode_text(t)
        return e / e.norm(dim=-1, keepdim=True)


with torch.no_grad():
    torch.onnx.export(V(), torch.randn(1, 3, 224, 224), out / "visual.onnx", input_names=["pixels"], output_names=["emb"],
                      dynamic_axes={"pixels": {0: "n"}, "emb": {0: "n"}}, opset_version=17, dynamo=False)
    torch.onnx.export(T(), torch.zeros(1, 77, dtype=torch.long), out / "text.onnx", input_names=["tokens"], output_names=["emb"],
                      dynamic_axes={"tokens": {0: "n"}, "emb": {0: "n"}}, opset_version=17, dynamo=False)
quantize_dynamic(str(out / "visual.onnx"), str(out / "visual.int8.onnx"), weight_type=QuantType.QInt8)
import json
n = [t for t in pre.transforms if type(t).__name__ == "Normalize"][0]
(out / "preprocess.json").write_text(json.dumps({"size": 224, "mean": list(n.mean), "std": list(n.std), "model": os.environ.get("MODEL", "hf-hub:imageomics/bioclip-2")}))
print("exported", *(f"{p.name} {p.stat().st_size >> 20} MB" for p in sorted(out.glob("*.onnx"))))
