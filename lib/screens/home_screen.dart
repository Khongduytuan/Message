import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mapp/apis/api.dart';
import 'package:mapp/helper/dialog.dart';
import 'package:mapp/main.dart';
import 'package:mapp/models/chat_user.dart';
import 'package:mapp/screens/profile_screen.dart';
import 'package:mapp/widgets/chat_user_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Danh sách ban đầu người dùng
  List<ChatUser> _list = [];
  // Danh sách sẽ sắp xếp lại khi search
  final List<ChatUser> _searchList = [];
  // kiểm tra trạng thái là đã search chưa
  bool _isSearching = false;
  @override
  void initState() {
    super.initState();
    APIs.getSelfInfor();

    SystemChannels.lifecycle.setMessageHandler((message) {
      log('Message => $message');
      if (APIs.auth.currentUser != null) {
        if (message.toString().contains('resume'))
          APIs.updateActiveStatus(true);
        if (message.toString().contains('pause'))
          APIs.updateActiveStatus(false);
      }
      return Future.value(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        // nếu tìm kiếm được bật và nút quay lại được nhấn thì đóng tìm kiếm
        // hoặc cách khác đơn giản là đóng màn hình hiện tại bằng cách nhấp vào nút quay lại
        onWillPop: () {
          if (_isSearching) {
            setState(() {
              _isSearching = !_isSearching;
            });
            return Future.value(false);
          } else {
            return Future.value(true);
          }

          // False => không làm gì cả
          // True => thực hiện tác vụ nút quay lại bình thường
        },
        child: Scaffold(
          appBar: AppBar(
            leading: Icon(CupertinoIcons.home),
            title: _isSearching
                ? TextField(
                    decoration: InputDecoration(
                        border: InputBorder.none, hintText: 'Name, Email, ...'),
                    autofocus: true,
                    style: TextStyle(fontSize: 16, letterSpacing: 0.5),
                    // Khi text field thay đổi thì cập nhật lại list người dùng
                    onChanged: (val) {
                      _searchList.clear();
                      for (var i in _list) {
                        if (i.name.toLowerCase().contains(val.toLowerCase()) ||
                            i.email.toLowerCase().contains(val.toLowerCase())) {
                          _searchList.add(i);
                          setState(() {
                            _searchList;
                          });
                        }
                      }
                    },
                  )
                : Text("K Message"),
            actions: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                    });
                  },
                  icon: Icon(_isSearching
                      ? CupertinoIcons.clear_circled_solid
                      : Icons.search)),
              IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                                  user: APIs.me,
                                )));
                  },
                  icon: Icon(Icons.more_vert)),
            ],
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: 10.0, right: 6.0),
            child: FloatingActionButton(
              onPressed: () async {
                // await APIs.auth.signOut();
                // await GoogleSignIn().signOut();
                _addChatUserDialog();
              },
              child: Icon(Icons.add_comment_rounded),
            ),
          ),
          body: StreamBuilder(
            stream: APIs.getMyUserId(),
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                case ConnectionState.none:
                  return Center(child: CircularProgressIndicator());
                case ConnectionState.active:
                case ConnectionState.done:
                  return StreamBuilder(
                      stream: APIs.getAllUser(
                          snapshot.data?.docs.map((e) => e.id).toList() ?? []),
                      builder: (context, snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:
                          case ConnectionState.none:
                            return Center(child: CircularProgressIndicator());
                          case ConnectionState.active:
                          case ConnectionState.done:
                            final data = snapshot.data?.docs;
                            _list = data
                                    ?.map((e) => ChatUser.fromJson(e.data()))
                                    .toList() ??
                                [];
                            if (_list.isNotEmpty) {
                              return ListView.builder(
                                  itemCount: _isSearching
                                      ? _searchList.length
                                      : _list.length,
                                  padding:
                                      EdgeInsets.only(top: mq.height * .01),
                                  physics: BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return ChatUserCard(
                                        user: _isSearching
                                            ? _searchList[index]
                                            : _list[index]);
                                    // return Text('Name: }');
                                  });
                            } else {
                              return Center(
                                child: Text(
                                  'No Connection Found!!!',
                                  style: TextStyle(fontSize: 20),
                                ),
                              );
                            }
                        }
                      });
              }
              // return Center(
              //   child: CircularProgressIndicator(
              //     strokeWidth: 2,
              //   ),
              // );
            },
          ),
        ),
      ),
    );
  }

  void _addChatUserDialog() {
    String email = '';
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              contentPadding:
                  EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              // Title của dialog edit message
              title: Row(
                children: [
                  Icon(
                    Icons.person_add_alt,
                    color: Colors.blue,
                  ),
                  Text(' Add Contant'),
                ],
              ),

              // Nội dung của phần ô edit mesage
              content: TextFormField(
                maxLines: null,
                onChanged: (value) => email = value,
                decoration: InputDecoration(
                    hintText: 'Enter Email',
                    prefixIcon: Icon(
                      Icons.email,
                      color: Colors.blue,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15))),
              ),

              // actions
              actions: [
                MaterialButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.blue, fontSize: 16),
                  ),
                ),
                MaterialButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await APIs.addChatUser(email).then((value) {
                      if (!value) {
                        Dialogs.showSnackBar(context, 'User does not exists!');
                      }
                    });
                  },
                  child: Text(
                    'Add',
                    style: TextStyle(color: Colors.blue, fontSize: 16),
                  ),
                )
              ],
            ));
  }
}
