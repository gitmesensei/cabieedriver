import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cabieedriver/global_variables.dart';
import 'package:cabieedriver/size_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'collect_payment.dart';
import 'helper_methods.dart';
import 'mapkit.dart';

class NewTrip extends StatefulWidget {
  GeoPoint pickUpLocation;
  GeoPoint destination;
  String locationName;
  String destinationName;
  String rideID;
  LatLng driverPosition;
  int fare;
  String paymentMethod;

  NewTrip(this.pickUpLocation, this.destination, this.locationName,
      this.destinationName, this.rideID, this.driverPosition, this.fare, this.paymentMethod);
  @override
  _NewTripState createState() => _NewTripState();
}

String kGoogleApiKey;

class _NewTripState extends State<NewTrip> with SingleTickerProviderStateMixin {
  Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = Set<Marker>();
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = kGoogleApiKey;
  var tween = Tween(begin: Offset(1.0, 0.0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.elasticInOut));
  AnimationController _animationController;
  Animation _animation2;
  GoogleMapController rideMapController;
  Animation _animation;
  double totalDistance = 0.0;
  double _placeDistance;
  BitmapDescriptor sourceIcon;
  StreamSubscription<Position> positionStream;
  Position _position;
  var markerCenter;
  int _markerIdCounter = 0;
  GoogleMapController controller;

  String tripStatus = "accepted";
  String tripDuration = '';

  var destination;
  var driverLocation;

  bool isRequestingDirection = false;
  String buttonTitle = 'ARRIVED';

  Color buttonColor = Colors.deepOrange;

  Timer timer;

  int durationCounter = 0;

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }

  getMarker() async {
    final Uint8List markerIcon =
        await getBytesFromAsset('assets/car_android.png', 80);
    setState(() {
      sourceIcon = BitmapDescriptor.fromBytes(markerIcon);
    });
  }

  updateLocation() async {
    LatLng oldPosition = LatLng(0, 0);

    positionStream = Geolocator.getPositionStream(distanceFilter: 15)
        .listen((Position position) {
      print(position == null
          ? 'Unknown'
          : position.latitude.toString() +
              ', ' +
              position.longitude.toString());
      LatLng pos = LatLng(position.latitude, position.longitude);
      driverLocation = pos;
      var rotation = MapKitHelper.getMarkerRotation(oldPosition.latitude,
          oldPosition.longitude, pos.latitude, pos.longitude);

      print('my rotation = $rotation');

      Marker movingMaker = Marker(
          markerId: MarkerId('moving'),
          position: pos,
          icon: sourceIcon,
          rotation: rotation,
          infoWindow: InfoWindow(title: 'Current Location'));

      setState(() {
        CameraPosition cp = new CameraPosition(target: pos, zoom: 17);
        rideMapController.animateCamera(CameraUpdate.newCameraPosition(cp));
        _markers.removeWhere((marker) => marker.markerId.value == 'moving');
        _markers.add(movingMaker);

        updateDestination();
        updateLocationToDatabase(pos);
      });
      oldPosition = pos;
    });
  }

  updateLocationToDatabase(pos) async {
    User user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('Drivers')
        .doc(user.uid.toString())
        .update({
      'coords': GeoPoint(pos.latitude, pos.longitude),
    });
  }

  updateDestination() async {
    if (!isRequestingDirection) {
      isRequestingDirection = true;

      if (driverLocation == null) {
        return;
      }

      if (tripStatus == 'accepted') {
        destination = LatLng(
            widget.pickUpLocation.latitude, widget.pickUpLocation.longitude);
      } else {
        destination =
            LatLng(widget.destination.latitude, widget.destination.longitude);
      }
      _addMarker(LatLng(destination.latitude, destination.longitude),
          "destination", BitmapDescriptor.defaultMarker);
      var directionDetails =
          await HelperMethods.getDirectionDetails(driverLocation, destination);

      if (directionDetails != null) {
        setState(() {
          tripDuration = directionDetails.durationText;
        });
      }
      isRequestingDirection = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _acceptTrip();
    getMarker();
    if (Platform.isAndroid) {
      // Android-specific code
      kGoogleApiKey = Global.kAndroidGoogleApiKey;
    } else if (Platform.isIOS) {
      // iOS-specific code
      kGoogleApiKey = Global.kIOSGoogleApiKey;
    }
    _animationController = AnimationController(
        duration: Duration(milliseconds: 1500), vsync: this);
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animation2 = Tween(begin: 0.0, end: 1.0).animate(_animationController);

    /// destination marker
    driverLocation = widget.driverPosition;
    print('fbhsbfshjbsjhbdjs: $driverLocation');
    destination = LatLng(widget.pickUpLocation.latitude, widget.pickUpLocation.longitude);
    _getPolyline();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            widget.destination == null
                ? Center(
                    child: Container(
                      color: Theme.of(context).canvasColor,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Text('loading...')
                        ],
                      ),
                    ),
                  )
                : FadeTransition(
                    opacity: _animation,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                          target: LatLng(widget.pickUpLocation.latitude,
                              widget.pickUpLocation.longitude),
                          zoom: 13),
                      myLocationEnabled: false,
                      tiltGesturesEnabled: true,
                      compassEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      markers: _markers,
                      polylines: Set<Polyline>.of(polylines.values),
                      onMapCreated: (GoogleMapController controller) async {
                        _mapController.complete(controller);
                        rideMapController = controller;
                        updateLocation();
                      },
                    ),
                  ),
            SlideTransition(
              position: _animation2.drive(tween),
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    elevation: 10,
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30)),
                    child: Container(
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 10,
                            ),
                            Text(
                              'New Trip Started',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 0, top: 10, bottom: 20),
                                      child: Text(
                                          'Time Remaining : $tripDuration'),
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_pin,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(
                                        width: 20,
                                      ),
                                      Expanded(
                                          child: Text(
                                        widget.locationName,
                                        style: TextStyle(fontSize: 18),
                                      )),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 15,
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                      ),
                                      SizedBox(
                                        width: 20,
                                      ),
                                      Expanded(
                                          child: Text(
                                        widget.destinationName,
                                        style: TextStyle(fontSize: 18),
                                      )),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ButtonTheme(
                                height: 45,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                child: RaisedButton(
                                  onPressed: () async {
                                    User user = FirebaseAuth.instance.currentUser;
                                    if (tripStatus == 'accepted') {
                                      tripStatus = 'arrived';

                                      await FirebaseFirestore.instance
                                          .collection('RideRequest')
                                          .doc(user.uid.toString()).update({

                                        "status":"arrived"
                                      });

                                      setState(() {
                                        buttonTitle = 'START TRIP';
                                        buttonColor = Colors.green.shade500;
                                      });
                                      polylines.clear();

                                      HelperMethods.showProgressDialog(context);

                                      updateDestination();
                                      _getPolyline();

                                      Navigator.pop(context);
                                    } else if (tripStatus == 'arrived') {
                                      tripStatus = 'ontrip';

                                      await FirebaseFirestore.instance
                                          .collection('RideRequest')
                                          .doc(user.uid.toString()).update({

                                        "status":"onTrip"
                                      });
                                      setState(() {
                                        buttonTitle = 'END TRIP';
                                        buttonColor = Colors.red[400];
                                      });

                                    } else if (tripStatus == 'ontrip') {
                                    //  endTrip;
                                      showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (BuildContext context) => CollectPayment(paymentMethod: widget.paymentMethod,
                                          fares: widget.fare,)
                                      );
                                      positionStream.cancel();
                                    }
                                  },
                                  color: buttonColor,
                                  child: Center(
                                    child: Text(
                                      buttonTitle,
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.white,fontWeight: FontWeight.w500,letterSpacing: 2),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        )),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  void _acceptTrip() async {
    String rideId = widget.rideID;
    User user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection("Drivers")
        .doc(user.uid.toString())
        .get()
        .then((value) async {
      await FirebaseFirestore.instance
          .collection("RideRequest")
          .doc(rideId)
          .update({
        "tripStatus": "accepted",
        "driver_name": value.data()['name'],
        "car_details": value.data()['model'],
        "driver_phone": value.data()['number'],
        "driver_id": value.data()['user_id'],
        "driver_location": GeoPoint(
            value.data()['coords'].latitude, value.data()['coords'].longitude),
      });
    });
  }

  _addMarker(LatLng position, String id, BitmapDescriptor descriptor) {
    MarkerId markerId = MarkerId(id);
    Marker marker =
        Marker(markerId: markerId, icon: descriptor, position: position);
    _markers.add(marker);
  }

  _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.lightBlue,
        points: polylineCoordinates,
        width: 5);
    polylines[id] = polyline;
    setState(() {});
  }

  _getPolyline() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      kGoogleApiKey,
      PointLatLng(driverLocation.latitude, driverLocation.longitude),
      PointLatLng(destination.latitude, destination.longitude),
      travelMode: TravelMode.driving,
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }
    _addPolyLine();
  }

}
