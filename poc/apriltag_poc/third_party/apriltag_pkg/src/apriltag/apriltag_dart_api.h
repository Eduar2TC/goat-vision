#ifndef APRILTAG_DART_API_H_
#define APRILTAG_DART_API_H_

#include "apriltag.h"
#include "common/image_types.h"
#include "common/zarray.h"
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef void (*dart_run_callback_0)(void);

void image_u8_destroy_dart_api(void *im);
void apriltag_detector_destroy_dart_api(void *detector);
void apriltag_detections_destroy_dart_api(void *detections);
void apriltag_detection_destroy_dart_api(void *detection);

apriltag_detection_t *zarray_get_detection_dart_api(zarray_t *detections, int index);

zarray_t *apriltag_detector_detect_dart_api(
    apriltag_detector_t *td, image_u8_t *img_buffer, dart_run_callback_0 callback
);

image_u8_t *image_u8_from_buffer(uint8_t *data, int width, int height);

zarray_t *zarray_create_dart_api(int eachElemSize);
void      zarray_destroy_dart_api(void *zarray);
zarray_t *zarray_copy_dart_api(zarray_t *zarray);

#ifdef __cplusplus
}
#endif

#endif // APRILTAG_DART_API_H_
