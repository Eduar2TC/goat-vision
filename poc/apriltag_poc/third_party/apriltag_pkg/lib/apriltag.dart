// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.
//
// Copyright (C) 2013-2016, The Regents of The University of Michigan.
// All rights reserved.
// This software was developed in the APRIL Robotics Lab under the
// direction of Edwin Olson, ebolson@umich.edu. This software may be
// available under alternative licensing terms; contact the address above.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// The views and conclusions contained in the software and documentation are those
// of the authors and should not be interpreted as representing official policies,
// either expressed or implied, of the Regents of The University of Michigan.

/// A dart wrapper of apriltag [library](https://github.com/AprilRobotics/apriltag).
///
/// AprilTag is a visual fiducial system popular in robotics research.
///
/// Predefined tag families are available at [apriltag-imgs](https://github.com/AprilRobotics/apriltag-imgs).
///
/// You can generate your own tag family using [apriltag-generation](https://github.com/AprilRobotics/apriltag-generation).
library;

export 'src/core/detector.dart';
export 'src/core/exception.dart';
export 'src/core/image_u8.dart';
export 'src/core/matd.dart';
export 'src/core/pose.dart';
export 'src/core/tag_family.dart';
export 'src/core/zarray.dart';
