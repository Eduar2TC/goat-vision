#include "apriltag_dart_api.h"
#include "apriltag.h"
#include "common/image_types.h"
#include "common/zarray.h"

void image_u8_destroy_dart_api(void *im) { image_u8_destroy((image_u8_t *)im); }
void apriltag_detector_destroy_dart_api(void *detector) {
  apriltag_detector_destroy((apriltag_detector_t *)detector);
}
void apriltag_detections_destroy_dart_api(void *detections) {
  apriltag_detections_destroy((zarray_t *)detections);
}
void apriltag_detection_destroy_dart_api(void *detection) {
  apriltag_detection_destroy((apriltag_detection_t *)detection);
}
apriltag_detection_t *zarray_get_detection_dart_api(zarray_t *detections, int index) {
  apriltag_detection_t *det;
  zarray_get((zarray_t *)detections, index, &det);
  return det;
}

zarray_t *apriltag_detector_detect_dart_api(
    apriltag_detector_t *td, image_u8_t *img, dart_run_callback_0 callback
) {
  zarray_t *detections = apriltag_detector_detect(td, img);
  if (callback != NULL) { callback(); }
  return detections;
}

image_u8_t *image_u8_from_buffer(uint8_t *data, int width, int height) {
  image_u8_t *im = image_u8_create(width, height);
  for (int y = 0; y < height; y++) { memcpy(&im->buf[y * im->stride], &data[y * width], width); }
  return im;
}

zarray_t *zarray_create_dart_api(int eachElemSize) { return zarray_create(eachElemSize); }
void      zarray_destroy_dart_api(void *zarray) { zarray_destroy((zarray_t *)zarray); }
zarray_t *zarray_copy_dart_api(zarray_t *zarray) { return zarray_copy((zarray_t *)zarray); }
