import 'dart:io';

import 'package:maps_toolkit/maps_toolkit.dart';
import 'dart:convert';


class MapKitHelper {

  static double getMarkerRotation(sourceLat, sourceLng, destinationLat,
      destinationLng) {
    var rotation = SphericalUtil.computeHeading(
        LatLng(sourceLat, sourceLng),
        LatLng(destinationLat, destinationLng)
    );

    return rotation;
  }

}