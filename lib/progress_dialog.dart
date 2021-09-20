import 'package:flutter/material.dart';

class ProgressDialog extends StatelessWidget {

  final String status;
  ProgressDialog(this.status);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30)
      ) ,
      backgroundColor: Colors.transparent,
      child: Container(
        width:double.infinity ,
        margin:EdgeInsets.all(18) ,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8)
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              SizedBox(width: 5,),
              CircularProgressIndicator(),
              SizedBox(width: 25,),
              Text(status,style: TextStyle(fontSize: 16),)

            ],
          ),
        ),
      ),

    );
  }
}
