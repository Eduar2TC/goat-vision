// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../g/apriltag.g.dart' as C;
import 'base.dart';
import 'matd.dart';
import 'zarray.dart';

/// Estimate pose of the tag using the homography method described in [1].
/// @outparam pose
AprilTagPose estimatePoseForTagHomography(AprilTagDetectionInfo info) {
  final pose = calloc<C.apriltag_pose_t>();
  C.estimate_pose_for_tag_homography(info.ptr, pose);
  // [PoC patch, goat-vision] copiar antes de destruir el matd nativo:
  // toMatD envuelve la memoria del heap de C, que pose.dispose() libera.
  final rval = AprilTagPose(pose.ref.R.toMatD.copy(), pose.ref.t.toMatD.copy());
  pose.dispose();
  return rval;
}

/// Estimate tag pose.
/// This method is an easier to use interface to estimate_tag_pose_orthogonal_iteration.
///
/// @outparam pose
/// @return Object-space error of returned pose.
(double error, AprilTagPose pose) estimateTagPose(AprilTagDetectionInfo info) {
  final pose = calloc<C.apriltag_pose_t>();
  final error = C.estimate_tag_pose(info.ptr, pose);
  // [PoC patch, goat-vision] copiar antes de destruir el matd nativo.
  final rval = AprilTagPose(pose.ref.R.toMatD.copy(), pose.ref.t.toMatD.copy());
  pose.dispose();
  return (error, rval);
}

class AprilTagDetectionInfo extends NativeObject<C.apriltag_detection_info_t> {
  static final _finalizer = ffi.NativeFinalizer(calloc.nativeFree);
  AprilTagDetectionInfo.fromPointer(
    ffi.Pointer<C.apriltag_detection_info_t> ptr, {
    super.attach,
    super.externalSize,
  }) : super(ptr.cast());

  /// Create a [AprilTagDetectionInfo] from a [Detection].
  ///
  /// - [detection] The [Detection] to create the [AprilTagDetectionInfo] from.
  /// - [tagSize] The size of the tag in meters.
  /// - [fx] In pixels.
  /// - [fy] In pixels.
  /// - [cx] In pixels.
  /// - [cy] In pixels.
  factory AprilTagDetectionInfo(
    Detection detection, {
    double tagSize = 0.0,
    double fx = 0.0,
    double fy = 0.0,
    double cx = 0.0,
    double cy = 0.0,
  }) {
    final ptr = calloc<C.apriltag_detection_info_t>()
      ..ref.det = detection.ptr
      ..ref.tagsize = tagSize
      ..ref.fx = fx
      ..ref.fy = fy
      ..ref.cx = cx
      ..ref.cy = cy;
    return AprilTagDetectionInfo.fromPointer(ptr);
  }

  @override
  ffi.NativeFinalizer get finalizer => _finalizer;

  @override
  List<Object?> get props => [ptr.address];

  @override
  void release() {
    calloc.free(ptr);
  }
}

/// This struct holds the transformation from the camera optical frame to
/// the April tag frame. The pose refers to the position of the tag within
/// the camera frame.
class AprilTagPose {
  /// Rotation matrix 3x3 of doubles.
  final MatD R;

  /// Translation matrix 3x1 of doubles.
  final MatD t;

  /// Create a [AprilTagPose] from a [MatD] rotation matrix and a [MatD] translation matrix.
  ///
  /// - [R] The rotation matrix 3x3 of doubles.
  /// - [t] The translation matrix 3x1 of doubles.
  AprilTagPose(this.R, this.t);

  ffi.Pointer<C.apriltag_pose_t> get toNative {
    final p = calloc<C.apriltag_pose_t>()
      ..ref.R = R.toNative
      ..ref.t = t.toNative;
    return p;
  }
}

extension AprilTagPosePointerExtension on ffi.Pointer<C.apriltag_pose_t> {
  void dispose() {
    ref.R.dispose();
    ref.t.dispose();
    calloc.free(this);
  }
}
