import 'package:flutter/material.dart';

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

class ConfirmDialog extends StatefulWidget {
  final String question;
  const ConfirmDialog({super.key, required this.question});
@override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text("Are you sure?"),
        content: Text(widget.question),
        backgroundColor: Colors.amber[100],
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
                    MattDialogButton(onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      label: "yes",
                      icon: const Icon(Icons.check),
                      ),
                    MattDialogButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      label: "no",
                      icon: const Icon(Icons.cancel),
                      ),                    
                  ],
                );    
  }
}

Future <bool> askConfirm (BuildContext context, String question) async {
  bool result = await showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmDialog(question: question);
    });
    return result;
}

class MessageDialog extends StatefulWidget {
  final String message;
  const MessageDialog({super.key, required this.message});
@override
  State<MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<MessageDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text(widget.message),
        // content: Text(widget.message!),
        backgroundColor: Colors.amber[100],
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
                    MattDialogButton(onPressed: () {
                        Navigator.of(context).pop();
                      },
                      label: "Continue",
                      icon: const Icon(Icons.check_circle_outline),
                      ),
                  ],
                );    
  }
}

void showMessageDialog(BuildContext context, String message) async {
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return MessageDialog(message: message);
    });
}

