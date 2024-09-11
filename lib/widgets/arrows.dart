import 'package:flutter/material.dart';

import '../log.dart';

class _ArrowButtonWidget extends StatelessWidget {
  final Function() onPressed;
  final IconData icon;
  void _onPressed() {
    logDebug('button pressed');
    onPressed();
  }
  const _ArrowButtonWidget({required this.onPressed, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(autofocus: false, onPressed: _onPressed, child: Icon(icon),),
    );
  }
}

class ArrowsWidget extends StatelessWidget {
  static const double widgetWidth = 240;
  static const double widgetHeight = 92;

  final Function() leftPressed;
  final Function() upPressed;
  final Function() rightPressed;
  final Function() downPressed;
  const ArrowsWidget({required this.leftPressed, required this.upPressed, required this.downPressed, required this.rightPressed, super.key});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.lightBlue[50]??const Color.fromRGBO(0,0,0,0);
    return Container(
              decoration: BoxDecoration(color:color, border: const Border.fromBorderSide(BorderSide(width:2,color:Colors.black54)),
                                            	borderRadius: const BorderRadius.all(Radius.elliptical(40, 40)),
                                              boxShadow: [BoxShadow(color:color,offset:const Offset(5,5), blurRadius: 10, spreadRadius:2),
                                              BoxShadow(color:color, offset: const Offset(0,0), blurRadius: 0, spreadRadius: 0)
                                              ]
                                              ),
              width:widgetWidth,
              height: widgetHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ArrowButtonWidget(onPressed: leftPressed, icon: Icons.keyboard_arrow_left_rounded),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ArrowButtonWidget(onPressed: upPressed, icon: Icons.keyboard_arrow_up_rounded),
                      _ArrowButtonWidget(onPressed: downPressed,icon: Icons.keyboard_arrow_down_rounded),]),

                      _ArrowButtonWidget(onPressed: rightPressed, icon: Icons.keyboard_arrow_right),
                    ],
                    )
                  );
  }
}