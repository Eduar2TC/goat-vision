# El GPUDelegate de tflite_flutter referencia
# org.tensorflow.lite.gpu.GpuDelegateFactory$Options, que solo existe en
# la dependencia opcional tensorflow-lite-gpu (no listada). El delegate
# solo se usa si se instancia en runtime; sin él, la app cae a CPU.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.**
