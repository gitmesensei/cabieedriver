
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CollectPayment extends StatelessWidget {

  final String paymentMethod;
  final int fares;

  CollectPayment({this.paymentMethod, this.fares});


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.all(4.0),
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30)
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[

            SizedBox(height: 20,),

            Text('$paymentMethod PAYMENT',style: TextStyle(fontSize: 20),),

            SizedBox(height: 20,),

            Container(
              height: 1,
              color: Colors.grey,
            ),
            SizedBox(height: 16.0,),

            Text('\$$fares', style: TextStyle(fontFamily: 'Brand-Bold', fontSize: 50),),

            SizedBox(height: 16,),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Amount above is the total fares to be charged to the rider', textAlign: TextAlign.center,),
            ),

            SizedBox(height: 30,),

            Container(
              width: 230,
              margin: EdgeInsets.all(10),
              child: ButtonTheme(
                height: 45,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                child: RaisedButton(
                  onPressed: () async {
                    topUpEarnings(fares);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  color: Colors.green.shade400,
                  child: Center(
                    child: Text(
                        paymentMethod == 'CASH'? 'COLLECT CASH' : 'CONFIRM',
                      style: TextStyle(
                          fontSize: 18, color: Colors.white,fontWeight: FontWeight.w500,letterSpacing: 2),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40,)
          ],
        ),
      ),
    );
  }
  void topUpEarnings(int fares){
    User user = FirebaseAuth.instance.currentUser;
    FirebaseFirestore.instance.collection('Drivers').doc(user.uid.toString()).get().then((value){

      if(value.data()['earnings'] != null){

        double oldEarnings = double.parse(value.data()['earnings'].toString());

        double adjustedEarnings = (fares.toDouble() * 0.85) + oldEarnings;

        print(adjustedEarnings);

        FirebaseFirestore.instance.collection("Drivers").doc(user.uid.toString()).update({
          "earnings": adjustedEarnings.toStringAsFixed(2)
        });

      }
      else{
        double adjustedEarnings = (fares.toDouble() * 0.85);
        FirebaseFirestore.instance.collection("Drivers").doc(user.uid.toString()).update({
          "earnings": adjustedEarnings.toStringAsFixed(2)
        });
      }
    });

  }
}