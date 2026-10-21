// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../g/apriltag.g.dart' as C;
import 'base.dart';
import 'exception.dart';

class ImageU8 extends NativeObject<C.image_u8_t> {
  static final _finalizer = ffi.NativeFinalizer(C.addresses.image_u8_destroy_dart_api);

  ImageU8.fromPointer(super.ptr, {super.attach, super.externalSize});

  factory ImageU8.fromBuffer(Uint8List data, int width, int height) {
    final pdata = calloc<ffi.Uint8>(data.length);
    pdata.asTypedList(data.length).setAll(0, data);
    final p = C.image_u8_from_buffer(pdata, width, height);
    calloc.free(pdata);
    return ImageU8.fromPointer(p);
  }

  factory ImageU8.empty(int width, int height) {
    final p = C.image_u8_create(width, height);
    if (p == ffi.nullptr) {
      throw AprilTagException("image_u8_create failed");
    }
    return ImageU8.fromPointer(p);
  }

  C.image_u8_t get ref => ptr.cast<C.image_u8_t>().ref;
  int get width => ref.width;
  int get height => ref.height;
  int get stride => ref.stride;
  Uint8List get data => ref.buf.asTypedList(height * stride);

  @override
  ffi.NativeFinalizer get finalizer => _finalizer;

  @override
  List<Object?> get props => [ptr.address];

  @override
  void release() {
    if (ptr == ffi.nullptr) {
      return;
    }
    C.image_u8_destroy(ptr);
  }

  @override
  String toString() {
    return "ImageU8(address=0x${ptr.address.toRadixString(16)}, width=$width, height=$height, stride=$stride)";
  }
}
