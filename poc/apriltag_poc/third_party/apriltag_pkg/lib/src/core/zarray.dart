// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../g/apriltag.g.dart' as C;
import 'base.dart';
import 'tag_family.dart';

class ZArray extends NativeObject<C.zarray_t> {
  static final _finalizer = ffi.NativeFinalizer(C.addresses.apriltag_detections_destroy_dart_api);

  ZArray.fromPointer(super.ptr, {super.attach, super.externalSize});

  factory ZArray.create(int eachElemSize) {
    final p = C.zarray_create_dart_api(eachElemSize);
    return ZArray.fromPointer(p);
  }

  ZArray copy() {
    final p = C.zarray_copy_dart_api(ptr);
    return ZArray.fromPointer(p);
  }

  C.zarray_t get ref => ptr.cast<C.zarray_t>().ref;
  int get size => ref.size;
  int get eachElemSize => ref.el_sz;

  Detection get(int index) =>
      Detection.fromPointer(C.zarray_get_detection_dart_api(ptr, index), attach: false);

  @override
  ffi.NativeFinalizer get finalizer => _finalizer;

  @override
  List<Object?> get props => [ptr.address];

  @override
  void release() {
    if (ptr == ffi.nullptr) {
      return;
    }
    C.apriltag_detections_destroy(ptr);
  }

  @override
  String toString() {
    return "ZArray(address=0x${ptr.address.toRadixString(16)}, size=$size, elemSize=$eachElemSize)";
  }
}

class Detection extends NativeObject<C.apriltag_detection_t> {
  static final _finalizer = ffi.NativeFinalizer(C.addresses.apriltag_detection_destroy_dart_api);

  Detection.fromPointer(super.ptr, {super.attach, super.externalSize});

  C.apriltag_detection_t get ref => ptr.cast<C.apriltag_detection_t>().ref;

  AprilTagFamily get family {
    final name = ref.family.cast<C.apriltag_family_t>().ref.name.cast<Utf8>().toDartString();
    final type = FamilyType.fromName(name);
    return AprilTagFamily.fromPointer(ref.family, type: type, attach: false);
  }

  /// The decoded ID of the tag
  int get id => ref.id;

  /// How many error bits were corrected? Note: accepting large numbers of
  /// corrected errors leads to greatly increased false positive rates.
  /// NOTE: As of this implementation, the detector cannot detect tags with
  /// a hamming distance greater than 2.
  int get hamming => ref.hamming;

  /// A measure of the quality of the binary decoding process: the
  /// average difference between the intensity of a data bit versus
  /// the decision threshold. Higher numbers roughly indicate better
  /// decodes. This is a reasonable measure of detection accuracy
  /// only for very small tags-- not effective for larger tags (where
  /// we could have sampled anywhere within a bit cell and still
  /// gotten a good detection.)
  double get decisionMargin => ref.decision_margin;

  /// The center of the detection in pixel coordinates
  (double, double) get center => (ref.c[0], ref.c[1]);
  (double, double) get c => center;

  /// The corners of the tag in image pixel coordinates. These always
  /// wrap counter-clock wise around the tag.
  List<(double, double)> get corners => [
    (ref.p[0][0], ref.p[0][1]),
    (ref.p[1][0], ref.p[1][1]),
    (ref.p[2][0], ref.p[2][1]),
    (ref.p[3][0], ref.p[3][1]),
  ];

  List<(double, double)> get p => corners;

  @override
  ffi.NativeFinalizer get finalizer => _finalizer;

  @override
  List<Object?> get props => [ptr.address];

  @override
  void release() {
    if (ptr == ffi.nullptr) {
      return;
    }
    C.apriltag_detection_destroy(ptr);
  }

  @override
  String toString() {
    return "Detection(address=0x${ptr.address.toRadixString(16)}, id=${ref.id})";
  }
}
