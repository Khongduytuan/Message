import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart';
import 'package:mapp/models/chat_user.dart';
import 'package:mapp/models/message.dart';

class APIs {
  // Biến để lấy xác thực người dùng
  static FirebaseAuth auth = FirebaseAuth.instance;

  // Biến để lấy firebase store
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Biến để lấy dữ liệu từ storage
  static FirebaseStorage storage = FirebaseStorage.instance;

  static late ChatUser me;

  // Lấy ra thông tin của user
  static User get user => auth.currentUser!;

  // Biến dùng để truy cập firebase messaging(Push notification)
  static FirebaseMessaging fMessaging = FirebaseMessaging.instance;

  // Dùng để tạo ra firebase messagin token
  static Future<void> getFirebaseMessagingToken() async {
    await fMessaging.requestPermission(
      sound: true,
    );
    await fMessaging.getToken().then((t) {
      if (t != null) {
        me.pushToken = t;
        log("Push token => $t");
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Got a message whilst in the foreground!');
      log('Message data: ${message.data}');

      if (message.notification != null) {
        log('Message also contained a notification: ${message.notification}');
      }
    });
  }

  // Dùng để gửi thông báo
  static Future<void> sendPushNotification(
      ChatUser chatUser, String msg) async {
    try {
      final body = {
        "to": chatUser.pushToken,
        "notification": {
          "title": chatUser.name,
          "body": msg,
          "android_channel_id": "chats",
        },
        "data": {
          "some_data": "USER ID: ${me.id}",
        },
      };
      // var url = Uri.https('example.com', 'whatsit/create');
      var res = await post(Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.authorizationHeader:
                'key=AAAA8LD8-Lc:APA91bGopRJs85ASqUzD7Tq79tCNgRNqKqSLfY0xpP4ww9WPkZiQbrxJNPIhef39lIUmiynnshb_1uGJCTLjbIIH2tNQtiQUWyoKZmjhNRFdZcQuVjHQDMBsQQseE4mTYQvICvwg-v_E'
          },
          body: jsonEncode(body));
      log('Response status: ${res.statusCode}');
      log('Response body: ${res.body}');
    } catch (e) {
      log('\nsendPushNotificationE=> $e');
    }
  }

  // Kiểm tra xem tài khoản đã tồn tại hay chưa
  static Future<bool> userExits() async {
    log('User.uid => ${user.uid}');
    log('UserExits => ${(await firestore.collection('users').doc(user.uid).get()).exists}');
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  // Thêm người dùng bằng email
  static Future<bool> addChatUser(String email) async {
    final data = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    log('dataAddUser => ${data.docs}');
    if (data.docs.isNotEmpty && data.docs.first.id != user.uid) {
      log('User exists in Add User => ${data.docs.first.data()}');
      // Nếu người dùng tồn tại
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});
      return true;
    } else {
      // Nếu người dùng không tồn tại
      return false;
    }
  }

  // Cập nhật thông tin tài khoản
  static Future<void> sendFirstMessage(
      ChatUser chatUser, String msg, Type type) async {
    await firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({}).then((value) => sendMessage(chatUser, msg, type));
  }

  // Cập nhật thông tin tài khoản
  static Future<void> updateUserInfor() async {
    await firestore
        .collection('users')
        .doc(user.uid)
        .update({'name': me.name, 'about': me.about});
  }

  // Lấy thông tin người dùng hiện tại
  static Future<void> getSelfInfor() async {
    await firestore.collection('users').doc(user.uid).get().then((user) async {
      if (user.exists) {
        me = ChatUser.fromJson(user.data()!);
        await getFirebaseMessagingToken();
        APIs.updateActiveStatus(true);
        log('My Data => ${user.data()}');
      } else {
        await createUser().then((value) => getSelfInfor());
      }
    });
  }

  // Tạo 1 tài khoản người dùng mới
  static Future<void> createUser() async {
    final time = DateTime.now().microsecondsSinceEpoch.toString();
    final chatUser = ChatUser(
        image: user.photoURL.toString(),
        name: user.displayName.toString(),
        about: "Hi! Im Newbie Using Message App By KTuan",
        createdAt: time,
        id: user.uid,
        isOnline: false,
        lastActive: time,
        email: user.email.toString(),
        pushToken: '');
    return await firestore
        .collection('users')
        .doc(user.uid)
        .set(chatUser.toJson());
  }

  // Lấy thông tin tất cả người dùng
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyUserId() {
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .snapshots();
  }

  // Lấy thông tin tất cả người dùng
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUser(
      List<String> userIds) {
    log('\nUserIds => $userIds');
    return firestore
        .collection('users')
        .where('id', whereIn: userIds)
        // .where('id', isNotEqualTo: user.uid)
        .snapshots();
  }

  static Future<void> updateProfilePicture(File file) async {
    final ext = file.path.split('.').last;
    log('Extension => $ext');
    final ref = storage.ref().child('profile_pictures/${user.uid}.$ext');
    await ref
        .putFile(file, SettableMetadata(contentType: 'image/$ext'))
        .then((p0) {
      log('Data Transferred => ${p0.bytesTransferred / 1000} kb');
    });
    me.image = await ref.getDownloadURL();
    await firestore
        .collection('users')
        .doc(user.uid)
        .update({'image': me.image});
  }

  // ================Phần lấy thông tin tin nhắn================================
  static String getConversataionID(String id) =>
      user.uid.hashCode <= id.hashCode
          ? '${user.uid}_$id'
          : '${id}_${user.uid}';

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMesages(
      ChatUser user) {
    return firestore
        .collection('chats/${getConversataionID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  // Lấy thông tin cụ thể của người dùng is_online, last_active
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfor(
      ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isEqualTo: chatUser.id)
        .snapshots();
  }

  // Cập nhật thông tin là online hay không(is_online)
  static Future<void> updateActiveStatus(bool isOnline) async {
    firestore.collection('users').doc(user.uid).update({
      'is_online': isOnline,
      'last_active': DateTime.now().millisecondsSinceEpoch.toString(),
      'push_token': me.pushToken
    });
    log('updateActiveStatus => Đã cập nhật trạng thái $isOnline');
  }

  // Chats(collection) --> coversation_id(doc) --> messages(collection) --> message(doc)

  // Hàm gửi tin nhắn
  static Future<void> sendMessage(
      ChatUser chatUser, String msg, Type type) async {
    // Thời gian gửi tin nhắn và cũng dùng làm id luôn
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    // Tin nhắn được gửi đi
    final Message message = Message(
        msg: msg,
        read: '',
        toId: chatUser.id,
        type: type,
        sent: time,
        fromId: user.uid);
    final ref = firestore
        .collection('chats/${getConversataionID(chatUser.id)}/messages/');
    await ref.doc(time).set(message.toJson()).then((value) =>
        sendPushNotification(chatUser, type == Type.text ? msg : 'image'));
  }

  // Cập nhật trạng thái đã đọc của tin nhắn
  static Future<void> updateMessageReadStatus(Message message) async {
    firestore
        .collection('chats/${getConversataionID(message.fromId)}/messages/')
        .doc(message.sent)
        .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  // Lấy tin nhắn mới nhất
  static Stream<QuerySnapshot> getLastMessage(ChatUser user) {
    return firestore
        .collection('chats/${getConversataionID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    final ext = file.path.split('.').last;

    final ref = storage.ref().child(
        'iamges/${getConversataionID(chatUser.id)}/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref
        .putFile(file, SettableMetadata(contentType: 'image/$ext'))
        .then((p0) {
      log('Data Transferred => ${p0.bytesTransferred / 1000} kb');
    });
    final imageUrl = await ref.getDownloadURL();
    await sendMessage(chatUser, imageUrl, Type.image);
  }

  // Delete tin nhắn của bản thân
  static Future<void> deleteMessage(Message message) async {
    await firestore
        .collection('chats/${getConversataionID(message.toId)}/messages/')
        .doc(message.sent)
        .delete();

    if (message.type == Type.image)
      await storage.refFromURL(message.msg).delete();
  }

  // Cập nhật tin nhắn của bản thân
  static Future<void> updateMessage(Message message, String updatedMsg) async {
    await firestore
        .collection('chats/${getConversataionID(message.toId)}/messages/')
        .doc(message.sent)
        .update({'msg': updatedMsg});
  }
}
