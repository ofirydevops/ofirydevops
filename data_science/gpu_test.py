# import tensorflow as tf
import torch

def check_tensorflow_gpu():
    print("🔍 Checking TensorFlow GPU availability...")
    try:
        gpus = tf.config.list_physical_devices('GPU')
        if gpus:
            print(f"✅ TensorFlow can access {len(gpus)} GPU(s): {[gpu.name for gpu in gpus]}")
        else:
            print("❌ TensorFlow cannot access any GPUs.")
    except Exception as e:
        print(f"⚠️ TensorFlow GPU check failed: {e}")

def check_pytorch_gpu():
    print("\n🔍 Checking PyTorch GPU availability...")
    try:
        if torch.cuda.is_available():
            print(f"✅ PyTorch can access GPU: {torch.cuda.get_device_name(0)}")
        else:
            print("❌ PyTorch cannot access any GPUs.")
    except Exception as e:
        print(f"⚠️ PyTorch GPU check failed: {e}")

if __name__ == "__main__":
    check_pytorch_gpu()
    # check_tensorflow_gpu()
