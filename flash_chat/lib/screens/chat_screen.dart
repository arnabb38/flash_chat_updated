import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flash_chat/constants.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

final _fireStore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;
User loggedInUser;

bool unSend = false;

File _imageFile;
final picker = ImagePicker();
// FirebaseStorage storage = FirebaseStorage.instance;

class ChatScreen extends StatefulWidget {
  static String id = 'chat_screen';
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String messageText;
  var imgURL;
  final messageTextController = TextEditingController();
  @override
  void initState() {
    super.initState();

    getCurrentUser();
    // getMessages();
    // messagesStream();
  }

  Future pickImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    setState(() {
      _imageFile = File(pickedFile.path);
    });

    return true;
  }

  uploadImageToFS() async {
    if (_imageFile != null) {
      FirebaseStorage storage = FirebaseStorage.instance;
      String fileName = basename(_imageFile.path);

      Reference ref = storage.ref().child("userupload/$fileName");
      UploadTask uploadTask = ref.putFile(_imageFile);
      // uploadTask.then((res) async {
      //   imgURL = await res.ref.getDownloadURL();
      // });
      uploadTask.whenComplete(() async {
        imgURL = await ref.getDownloadURL();
        _imageFile = null;
        // print(imgURL);
      }).catchError((onError) {
        print(onError);
      });
      return imgURL;
    } else {
      return;
    }
  }

  void getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
        print(loggedInUser.email);
      }
    } catch (e) {
      print(e);
    }
  }

  // void getMessages() async {
  //   final messages = await _fireStore.collection('messages').getDocuments();
  //   for (var message in messages.documents) {
  //     print(message.data);
  //   }
  // }
  //
  // void messagesStream() async {
  //   await for (var snapshot in _fireStore.collection('messages').snapshots()) {
  //     for (var message in snapshot.documents) {
  //       print(message.data);
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: new BoxDecoration(
              image: new DecorationImage(
                image: new NetworkImage(
                  "https://www.lego.com/cdn/cs/set/assets/blt167d8e20620e4817/DC_-_Character_-_Details_-_Sidekick-Standard_-_Batman.jpg?fit=crop&format=jpg&quality=80&width=800&height=426&dpr=1",
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
              icon: Icon(
                Icons.info_outline_rounded,
                color: Colors.black,
                size: 35.0,
              ),
              onPressed: () {
//                messagesStream();
              }),
        ],
        title: Text(
          'Nash B.',
          style: TextStyle(
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MessagesStream(),
            Container(
              decoration: kMessageContainerDecoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _imageFile != null
                      ? Stack(
                          children: [
                            Container(
                              height: 120.0,
                              child: Image.file(_imageFile),
                            ),
                            Positioned(
                              right: 2.0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _imageFile = null;
                                  });
                                },
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: CircleAvatar(
                                    radius: 10.0,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 20.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(),
                  Expanded(
                    child: TextField(
                      maxLines: 2,
                      controller: messageTextController,
                      onChanged: (value) {
                        messageText = value.trim();
                      },
                      decoration: kMessageTextFieldDecoration,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (messageText.isNotEmpty || (_imageFile != null)) {
                            // print(messageText);
                            // print(_imageFile.path);
                            messageTextController.clear();
                            try {
                              await uploadImageToFS();
                              _fireStore.collection('messages').add({
                                'type': "text",
                                'text': messageText,
                                'sender': loggedInUser.email,
                                'timestamp': DateTime.now(),
                                'imgUrl': "$imgURL",
                              });
                              unSend = false;
                              setState(() {
                                _imageFile = null;
                              });
                              print("send!!!");
                            } catch (e) {
                              unSend = true;
                              print("unsend!!!");
                            }
                          } else {}
                        },
                        icon: Icon(
                          Icons.send,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          pickImage();
                        },
                        icon: Icon(
                          Icons.image_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesStream extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fireStore.collection('messages').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              backgroundColor: Colors.lightBlueAccent,
            ),
          );
        }

        final messages = snapshot.data.docs.reversed;
        List<MessageBubble> messageBubbles = [];
        for (var message in messages) {
          final messageText = message.data()['text'];
          final messagesSender = message.data()['sender'];
          final messageType = message.data()['type'];
          final messageTime = message.data()['timestamp'];
          final imgUrl = message.data()['imgUrl'];

          final currentUser = loggedInUser.email;

          final messageBubble = MessageBubble(
            sender: messagesSender,
            text: messageText,
            type: messageType,
            timestamp: messageTime,
            imgUrl: imgUrl,
            isMe: currentUser == messagesSender,
          );

          messageBubbles.add(messageBubble);
        }
        return Expanded(
          child: ListView(
            reverse: true,
            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
            children: messageBubbles,
          ),
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble(
      {this.sender,
      this.text,
      this.isMe,
      this.type,
      this.timestamp,
      this.imgUrl});

  final String sender;
  final String text;
  final String type;
  final Timestamp timestamp;
  final String imgUrl;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${DateTime.parse(timestamp.toDate().toString())}',
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.black45,
            ),
          ),
          // imgUrl != null
          //     ? Container(
          //         height: 150.0,
          //         decoration: new BoxDecoration(
          //           color: Colors.yellow,
          //           image: new DecorationImage(
          //             image: new NetworkImage(imgUrl),
          //             fit: BoxFit.contain,
          //           ),
          //         ),
          //       )
          //     : Container(),

          imgUrl != null
              ? Image.network(
                  imgUrl,
                  height: 250,
                )
              : Container(),
          Material(
            borderRadius: isMe
                ? BorderRadius.only(
                    topLeft: Radius.circular(0.0),
                    bottomLeft: Radius.circular(0.0),
                    bottomRight: Radius.circular(0.0),
                  )
                : BorderRadius.only(
                    topRight: Radius.circular(0.0),
                    bottomLeft: Radius.circular(0.0),
                    bottomRight: Radius.circular(0.0),
                  ),
            elevation: 1.0,
            color: isMe ? Colors.white : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                '$text',
                style: TextStyle(
                  fontSize: 18.0,
                  color: isMe ? Colors.black : Colors.black,
                ),
              ),
            ),
          ),
          isMe
              ? unSend == true
                  ? Icon(
                      Icons.error_outline_outlined,
                      color: Colors.red,
                      size: 17.0,
                    )
                  : Container()
              : Container(),
        ],
      ),
    );
  }
}
