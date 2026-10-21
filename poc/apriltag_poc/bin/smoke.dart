import 'package:apriltag/apriltag.dart';

void main() {
  final detector = AprilTagDetector.create();
  detector.addFamily(AprilTagFamily.tag36h11(), bits: 1);
  print('smoke: detector created OK');
  detector.dispose();
}
