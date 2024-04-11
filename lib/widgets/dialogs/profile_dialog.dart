import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapp/main.dart';
import 'package:mapp/models/chat_user.dart';
import 'package:mapp/screens/view_profile_screen.dart';

class ProflieDialog extends StatelessWidget {
  const ProflieDialog({super.key, required this.user});
  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      backgroundColor: Colors.white.withOpacity(.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: mq.width * .6,
        height: mq.height * .35,
        child: Stack(children: [
          // avatar
          Positioned(
            top: mq.height * .07,
            left: mq.width * .1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(mq.height * .25),
              child: CachedNetworkImage(
                width: mq.width * .5,
                fit: BoxFit.cover,
                imageUrl: user.image,
                errorWidget: (context, url, error) =>
                    const CircleAvatar(child: Icon(CupertinoIcons.person)),
              ),
            ),
          ),
          // username
          Positioned(
            left: mq.width * .04,
            top: mq.height * .02,
            width: mq.width * .55,
            child: Text(
              user.name,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),

          // icon thong tin
          Positioned(
              right: 8,
              top: 4,
              child: MaterialButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ViewProfileScreen(user: user)));
                },
                minWidth: 0,
                padding: EdgeInsets.all(0),
                shape: CircleBorder(),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 30,
                ),
              ))
        ]),
      ),
    );
  }
}
