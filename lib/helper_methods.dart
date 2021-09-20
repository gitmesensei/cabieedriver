import 'dart:io';
import 'package:cabieedriver/progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HelperMethods {
  static Future<DirectionDetails> getDirectionDetails(
      LatLng startPosition, LatLng endPosition) async {
    String kGoogleApiKey;

    if (Platform.isAndroid) {
      // Android-specific code
      kGoogleApiKey = "AIzaSyC9pqyp5r_m4cHbQIGKJjDXY5NG6lwP9Zg";
    } else if (Platform.isIOS) {
      // iOS-specific code
      kGoogleApiKey = "AIzaSyD5qX2Kc9s5ggtsRjoKRKeu6YO8s4zd0PQ";
    }
    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${startPosition.latitude},${startPosition.longitude}&destination=${endPosition.latitude},${endPosition.longitude}&mode=driving&key=$kGoogleApiKey';

    Uri myUri = Uri.parse(url);

    var response = await RequestHelper.getRequest(myUri);

    if (response == 'failed') {
      return null;
    }

    DirectionDetails directionDetails = DirectionDetails();

    directionDetails.durationText =
        response['routes'][0]['legs'][0]['duration']['text'];
    directionDetails.durationValue =
        response['routes'][0]['legs'][0]['duration']['value'];

    directionDetails.distanceText =
        response['routes'][0]['legs'][0]['distance']['text'];
    directionDetails.distanceValue =
        response['routes'][0]['legs'][0]['distance']['value'];

    directionDetails.encodedPoints =
        response['routes'][0]['overview_polyline']['points'];

    return directionDetails;
  }


  static void showProgressDialog(context){

    //show please wait dialog
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => ProgressDialog('Please wait'),
    );
  }

}

class DirectionDetails {
  String distanceText;
  String durationText;
  int distanceValue;
  int durationValue;
  String encodedPoints;

  DirectionDetails({
    this.distanceText,
    this.distanceValue,
    this.durationText,
    this.durationValue,
    this.encodedPoints,
  });
}

class RequestHelper {
  static Future<dynamic> getRequest(url) async {
    http.Response response = await http.get(url);

    try {
      if (response.statusCode == 200) {
        String data = response.body;
        var decodedData = jsonDecode(data);
        return decodedData;
      } else {
        return 'failed';
      }
    } catch (e) {
      return 'failed';
    }
  }
}
