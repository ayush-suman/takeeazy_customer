import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:takeeazy_customer/screens/components/customtext.dart';
import 'package:takeeazy_customer/screens/values/colors.dart';

class TEButton extends StatelessWidget{
  final double height;
  final double width;
  final TEText text;
  final Function onPressed;

  TEButton({this.height=50, this.width=100, this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
        height: height,
        width: width,
        child: FlatButton(
          shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            onPressed: onPressed,
            child: text,
        ),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            gradient: LinearGradient(
                begin:  Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  TakeEazyColors.gradient1Color,
                  TakeEazyColors.gradient2Color,
                  TakeEazyColors.gradient3Color,
                  TakeEazyColors.gradient4Color
                ]
            )
        )
    );
  }
}