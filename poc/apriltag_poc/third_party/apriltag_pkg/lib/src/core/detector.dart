// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:ffi' as ffi;

import '../g/apriltag.g.dart' as C;
import 'base.dart';
import 'exception.dart';
import 'image_u8.dart';
import 'tag_family.dart';
import 'zarray.dart';

class AprilTagDetector extends NativeObject<C.apriltag_detector_t> {
  static final _finalizer = ffi.NativeFinalizer(C.addresses.apriltag_detector_destroy_dart_api);
  AprilTagDetector.fromPointer(ffi.Pointer<C.apriltag_detector_t> ptr, {super.attach, super.externalSize})
    : super(ptr.cast());

  factory AprilTagDetector.create({
    int nThreads = 1,
    double quadDecimate = 1.0,
    double quadSigma = 0.0,
    int maxNmaxima = 10,
    int minClusterPixels = 5,
    double maxLineFitMse = 10.0,
    double cosCriticalRad = 0.9,
    int minWhiteBlackDiff = 5,
    bool refineEdges = true,
    double decodeSharpening = 0.25,
    bool debug = false,
  }) {
    final ptr = C.apriltag_detector_create()
      ..ref.nthreads = nThreads
      ..ref.quad_decimate = quadDecimate
      ..ref.quad_sigma = quadSigma
      ..ref.qtp.max_nmaxima = maxNmaxima
      ..ref.qtp.min_cluster_pixels = minClusterPixels
      ..ref.qtp.max_line_fit_mse = maxLineFitMse
      ..ref.qtp.cos_critical_rad = cosCriticalRad
      ..ref.qtp.min_white_black_diff = minWhiteBlackDiff
      ..ref.refine_edges = refineEdges
      ..ref.decode_sharpening = decodeSharpening
      ..ref.debug = debug;
    return AprilTagDetector.fromPointer(ptr);
  }

  void addFamily(AprilTagFamily family, {int bits = 0}) {
    C.apriltag_detector_add_family_bits(ptr, family.ptr, bits);
  }

  void removeFamily(AprilTagFamily family) {
    C.apriltag_detector_remove_family(ptr, family.ptr);
  }

  void clearFamilies() {
    C.apriltag_detector_clear_families(ptr);
  }

  ZArray detect(ImageU8 image) {
    final p = C.apriltag_detector_detect(ptr, image.ptr);
    return ZArray.fromPointer(p);
  }

  Future<ZArray> detectAsync(ImageU8 image) async {
    final completer = Completer<ZArray>();

    late final ffi.NativeCallable<C.dart_run_callback_0Function> ccallback;
    late final ffi.Pointer<C.zarray_t> pResult;

    void onResponse() {
      if (pResult == ffi.nullptr) {
        completer.completeError(AprilTagException("Failed to detect"));
      } else {
        completer.complete(ZArray.fromPointer(pResult));
      }
      ccallback.close();
    }

    ccallback = ffi.NativeCallable.listener(onResponse);

    pResult = C.apriltag_detector_detect_dart_api(ptr, image.ptr, ccallback.nativeFunction);
    return completer.future;
  }

  C.apriltag_detector_t get ref => ptr.cast<C.apriltag_detector_t>().ref;

  int get nThreads => ref.nthreads;
  set nThreads(int value) => ref.nthreads = value;

  double get quadDecimate => ref.quad_decimate;
  set quadDecimate(double value) => ref.quad_decimate = value;

  double get quadSigma => ref.quad_sigma;
  set quadSigma(double value) => ref.quad_sigma = value;

  int get maxNmaxima => ref.qtp.max_nmaxima;
  set maxNmaxima(int value) => ref.qtp.max_nmaxima = value;

  int get minClusterPixels => ref.qtp.min_cluster_pixels;
  set minClusterPixels(int value) => ref.qtp.min_cluster_pixels = value;

  double get maxLineFitMse => ref.qtp.max_line_fit_mse;
  set maxLineFitMse(double value) => ref.qtp.max_line_fit_mse = value;

  double get cosCriticalRad => ref.qtp.cos_critical_rad;
  set cosCriticalRad(double value) => ref.qtp.cos_critical_rad = value;

  int get minWhiteBlackDiff => ref.qtp.min_white_black_diff;
  set minWhiteBlackDiff(int value) => ref.qtp.min_white_black_diff = value;

  bool get refineEdges => ref.refine_edges;
  set refineEdges(bool value) => ref.refine_edges = value;

  double get decodeSharpening => ref.decode_sharpening;
  set decodeSharpening(double value) => ref.decode_sharpening = value;

  bool get debug => ref.debug;
  set debug(bool value) => ref.debug = value;

  @override
  ffi.NativeFinalizer get finalizer => _finalizer;

  @override
  List<Object?> get props => [ptr.address];

  @override
  void release() {
    C.apriltag_detector_destroy(ptr);
  }
}

// Future<T> runDetectAsync<T>(
//   ffi.Pointer<C.zarray_t> Function(C.dart_run_callback_0 callback) func,
//   void Function(Completer<T> completer) onComplete,
// ) async {
//   final completer = Completer<T>();
//   late final ffi.NativeCallable<C.dart_run_callback_0Function> ccallback;
//   void onResponse() {
//     onComplete(completer);
//     ccallback.close();
//   }

//   ccallback = ffi.NativeCallable.listener(onResponse);
//   final pResult = func(ccallback.nativeFunction);
//   if (pResult == ffi.nullptr) {
//     throw AprilTagException("Failed to detect");
//   }
//   return completer.future;
// }
