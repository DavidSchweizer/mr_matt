import 'dart:async';

import 'package:flutter/material.dart';


class SecondsStopwatch extends Stopwatch {
  int get seconds => elapsed.inSeconds;
  int get minutes => seconds ~/ 60;
  int get hours => minutes ~/ 60;
  
  String elapsedTime() {
    String secStr = (seconds % 60).toString().padLeft(2, "0");
    String minStr = minutes.toString().padLeft(2, "0");
    return hours > 0 ? "$hours:$minStr:$secStr" : "$minStr:$secStr";
  }

}

class StopwatchWidget extends StatefulWidget {
  final SecondsStopwatch stopwatch;
  const StopwatchWidget({super.key, required this.stopwatch});
  @override
  State<StopwatchWidget> createState()=>_StopwatchState();
}

class _StopwatchState extends State<StopwatchWidget> {
  late Timer timer;
  @override
  Widget build(BuildContext context) {
    return Padding( padding: const EdgeInsets.all(2),
      child:Text(widget.stopwatch.elapsedTime())
    );
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});    
    });
  }
}