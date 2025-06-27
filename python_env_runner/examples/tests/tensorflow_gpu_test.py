import tensorflow as tf

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

if __name__ == "__main__":
    check_tensorflow_gpu()






