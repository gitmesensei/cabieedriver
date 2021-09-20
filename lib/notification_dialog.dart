import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:cabieedriver/new_trip.dart';
import 'package:cabieedriver/progress_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:toast/toast.dart';

class NotificationDialog extends StatelessWidget {
  String destinationName;
  String locationName;
  String rideID;
  GeoPoint destination;
  GeoPoint location;
  LatLng centerPosition;
  int fare;
  String paymentMethod;

  NotificationDialog(this.destinationName, this.locationName, this.rideID, this.destination, this.location, this.centerPosition, this.fare, this.paymentMethod);

  final assetsAudioPlayer = AssetsAudioPlayer();



  @override
  Widget build(BuildContext context) {
    assetsAudioPlayer.open(
        Audio("assets/audio.mp3"),
        loopMode: LoopMode.single
    );
    assetsAudioPlayer.play();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 5,
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.all(8),
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
            ),
            Container(
              width: 100,
              height: 100,
              decoration:
                  BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: Center(
                child: Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            SizedBox(
              height: 18,
            ),
            Text(
              'New Trip Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 25,
            ),
            Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        locationName,
                        style: TextStyle(fontSize: 18),
                      )),
                    ],
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        destinationName,
                        style: TextStyle(fontSize: 18),
                      )),
                    ],
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        child: ButtonTheme(
                          minWidth: 40,
                          child: RaisedButton(
                            elevation: 5.0,
                            splashColor: Colors.white,
                            onPressed: () async {
                              assetsAudioPlayer.stop();
                              _checkRideStatus(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Accept',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18.0),
                              ),
                            ),
                            color: Colors.green,
                          ),
                        ),
                      ),
                      Container(
                        child: ButtonTheme(
                          minWidth: 40,
                          child: RaisedButton(
                            elevation: 5.0,
                            splashColor: Colors.white,
                            onPressed: () async {
                              assetsAudioPlayer.stop();
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Decline',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18.0),
                              ),
                            ),
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkRideStatus(context) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => ProgressDialog("accepting request"));

    User user = FirebaseAuth.instance.currentUser;

    String rideIdDatabase;

    await FirebaseFirestore.instance
        .collection('Drivers')
        .doc(user.uid.toString())
        .get()
        .then((value) {
      Navigator.pop(context);
      Navigator.pop(context);

      if (value.data() != null) {
        rideIdDatabase = value.data()['newTrip'];
      } else {
        Toast.show("ride not found", context, duration: Toast.LENGTH_SHORT, gravity:  Toast.BOTTOM);
      }
      if (rideIdDatabase == rideID) {
        updateInDatbase("xzlmoiX47BZGgn0mYHZxnTqqlan1",user);
        Navigator.push(context, MaterialPageRoute(builder: (context)=>NewTrip(location,destination,locationName,destinationName,rideID,centerPosition,fare,paymentMethod)));
      } else if (rideIdDatabase == "cancelled") {
        print('ride has been cancelled');
        Toast.show("ride has been cancelled", context, duration: Toast.LENGTH_SHORT, gravity:  Toast.BOTTOM);
      } else if (rideIdDatabase == "timeout") {
        print('ride has timed out');
        Toast.show("ride has timed out", context, duration: Toast.LENGTH_SHORT, gravity:  Toast.BOTTOM);

      } else {
        print('ride not found');
        Toast.show("ride not found", context, duration: Toast.LENGTH_SHORT, gravity:  Toast.BOTTOM);

      }
    });
  }

  void updateInDatbase(rideIdDatabase,user) async{
    await FirebaseFirestore.instance
        .collection('Drivers')
        .doc(user.uid.toString())
        .update({"newTrip": rideIdDatabase});
  }

}
