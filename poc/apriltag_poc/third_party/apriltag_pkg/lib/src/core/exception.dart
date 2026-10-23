// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

class AprilTagException implements Exception {
  final String message;
  AprilTagException(this.message);
  @override
  String toString() {
    return 'AprilTagException: $message';
  }
}
