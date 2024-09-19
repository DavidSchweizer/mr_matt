import 'package:flutter/material.dart';

class MattAppBarButton extends StatefulWidget {
  final Function()? onPressed;
  final IconData iconData;
  const MattAppBarButton({super.key,this.onPressed, required this.iconData});
  @override
  State<MattAppBarButton> createState() => _MattAppBarButtonState();
}

class _MattAppBarButtonState extends State<MattAppBarButton> {
  @override
  Widget build(BuildContext context) {
    return Row(children:[ IconButton(
                    onPressed: widget.onPressed,
                    icon: Icon(
                      widget.iconData,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
                ]);
  }
}


class MattDialogButton extends StatefulWidget {
  final Function()? onPressed;
  final String label;
  final Icon? icon;
  const MattDialogButton({super.key,this.onPressed, required this.label, this.icon});

  @override
  State<MattDialogButton> createState() => _MattDialogButtonState();
}

class _MattDialogButtonState extends State<MattDialogButton> {
  @override
  Widget build(BuildContext context) {
    return widget.icon != null ?
          ElevatedButton.icon(
                onPressed: widget.onPressed,
                label: Text(widget.label),
                icon: widget.icon,
                )    
          :
          ElevatedButton(
                onPressed: widget.onPressed,
                child: Text(widget.label),
                );
  }
}

