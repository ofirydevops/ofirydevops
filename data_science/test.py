import torch

if torch.cuda.is_available():
    print(f"Connected to GPU: {torch.cuda.get_device_name(0)}")
else:
    print("No GPU found")
