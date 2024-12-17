

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice recorder page',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: BottomSheetScreen(),
    );
  }
}

class BottomSheetScreen extends StatefulWidget {
  @override
  State<BottomSheetScreen> createState() => _BottomSheetScreenState();
}

class _BottomSheetScreenState extends State<BottomSheetScreen> {
  String? _imagePath;
  String? _audioPath;
  String? _audioFilename;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(title: Text('Audio Recorder'),centerTitle: true,backgroundColor: Colors.blue[800],titleTextStyle: TextStyle(color: Colors.white,fontSize: 24,fontWeight: FontWeight.w500),),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imagePath != null)
            Text('Image Path: $_imagePath', textAlign: TextAlign.center),
          if (_audioPath != null)
            Text('Audio Path: $_audioPath', textAlign: TextAlign.center),
          if (_audioFilename != null)
            Text('Filename: $_audioFilename', textAlign: TextAlign.center),
          SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await _showCounterBottomSheet(context);
                if (result['audioPath'] != null) {
                  setState(() {
                    _imagePath = (result['imagePath'] != null)
                        ? result['imagePath']
                        : 'noImage';
                    _audioPath = result['audioPath'];
                    _audioFilename = (result['audioFilename'] != null)
                        ? result['audioFilename']
                        : 'Recording';
                  });
                }
              },
              child: Text('Open Bottom Sheet'),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String?>> _showCounterBottomSheet(
      BuildContext context) async {
    print('Result from bottom sheet: ');
    return await showModalBottomSheet<Map<String, String?>>(
          context: context,
          isScrollControlled: true, // Allows custom height
          builder: (context) => FractionallySizedBox(
            heightFactor: 0.9, // 90% of the screen height
            widthFactor: 1.0, // 100% of the screen width
            child: AllInOneApp(),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ) ??
        {};
    // Return an empty map if dismissed
  }
}

class AllInOneApp extends StatefulWidget {
  @override
  _AllInOneAppState createState() => _AllInOneAppState();
}

class _AllInOneAppState extends State<AllInOneApp> {
  final AudioRecorder _recorder = AudioRecorder(); // Recorder instance
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance
  String? _audioPath;
  String? _audioFilename;
  String? _imagePath;
  bool _isRecording = false;
  bool _isPlaybackAvail = false;
  bool _isPlay = false;
  String _recordDuration = "00:00";
  Timer? _timer;
  int _seconds = 0;
  double currentposition = 0;
  double totalduration = 0;
  File? _imageFile; // For storing picked image
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  // Request microphone and storage permissions
  Future<void> _initializePermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  // Image Picker Functionality
  Future<void> _pickImage() async {
    // Ask user for image source (camera or gallery)
    final pickedSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Pick Image"),
          content: Text("Choose an option:"),
          actions: [
            TextButton(
              child: Text("Gallery"),
              onPressed: () {
                Navigator.of(context).pop(ImageSource.gallery);
              },
            ),
            TextButton(
              child: Text("Camera"),
              onPressed: () {
                Navigator.of(context).pop(ImageSource.camera);
              },
            ),
          ],
        );
      },
    );

    if (pickedSource != null) {
      final pickedFile = await _picker.pickImage(source: pickedSource);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imagePath = _imageFile!.path;
        });
      }
    }
  }

  // Start the recording process
  Future<void> _startRecording() async {
    print('Start record');
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _audioPath = path;
        _isRecording = true;
        _seconds = 0;
        _recordDuration = "00:00";
      });

      _startTimer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Permission not granted")),
      );
    }
  }

  // Stop the recording process
  Future<void> _stopRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _audioPath = path;
        _isRecording = false;
        _isPlaybackAvail = true;
      });
      _stopTimer();

      
    }
  }

  Future<void> _reRecord() async {
    await _recorder.cancel();
    setState(() {
      _audioPath = null;
      _isRecording = false;
      _recordDuration = "00:00";
      totalduration = 0;
      currentposition = 0;
      _isPlaybackAvail = false;
      _isPlay = false;
    });
    _stopTimer();
  }

  // Cancel the recording
  Future<void> _cancelRecording() async {
    await _recorder.cancel();
    setState(() {
      _audioPath = null;
      _isRecording = false;
      _recordDuration = "00:00";
      totalduration = 0;
      currentposition = 0;
    });
    _stopTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Recording canceled")),
    );
  }

  Future<void> _deleteAudio() async {
  if (_audioPath != null) {
    final file = File(_audioPath!);
    if (await file.exists()) {
      await file.delete();
      setState(() {
        _audioPath = null;
        _isPlaybackAvail = false;
        _isPlay = false;
        currentposition = 0;
        totalduration = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Audio file deleted")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Audio file not found")),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No audio file to delete")),
    );
  }
}


  // Play the recorded audio
  Future<void> _playRecording() async {
    if (_audioPath != null) {
      await _audioPlayer.setFilePath(_audioPath!);
      totalduration = _audioPlayer.duration?.inMicroseconds.toDouble()  ?? 0;
      _audioPlayer.play();
      _audioPlayer.positionStream.listen((position) {
        setState(() {
          currentposition = position.inMicroseconds.toDouble();
          _isPlay = true;
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No recording available to play")),
      );
    }
  }

  Future<void> _saveNotify() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Audio saved at: $_audioPath")),
    );
  }

  // Timer to update the duration of the recording
  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        _recordDuration = _formatDuration(_seconds);
      });
    });
  }

  // Stop the timer
  void _stopTimer() {
    _timer?.cancel();
  }

  // Format the duration into mm:ss format
  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${_padZero(minutes)}:${_padZero(remainingSeconds)}';
  }

  // Helper function to pad numbers below 10 with a leading zero
  String _padZero(int number) => number < 10 ? '0$number' : '$number';

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 16),
          child: IconButton(
            icon: Icon(
              Icons.close,
              size: 36,
              color: Colors.grey[800],
            ),
            onPressed: () async {
              await _deleteAudio();
              await _cancelRecording();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 16),
            child: IconButton(
              icon: Icon(
                Icons.check,
                size: 36,
                color: Colors.grey[800],
              ),
              onPressed: () async {
                print('button check');
                await _saveNotify();
                print('ReturnData');
                Navigator.pop(context, {
                  'imagePath': _imagePath,
                  'audioPath': _audioPath,
                  'audioFilename': _audioFilename,
                });
                ;
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 0,
              children: [
                // Default Image Placeholder or Selected Image
                _imageFile == null
                    ? Icon(
                        Icons.music_note,
                        size: 260,
                      )
                    : Image.file(_imageFile!,
                        width: 260, height: 260), // Display picked image
                // Image Picker
                Padding(
                  padding: const EdgeInsets.only(top: 94),
                  child: IconButton(
                      onPressed: _pickImage,
                      icon: Icon(
                        Icons.attach_file,
                        size: 38,
                        color: Colors.indigo[900],
                      )),
                ),
              ],
            ),
            SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.fromLTRB(48.0, 0, 48.0, 20),
              child: TextField(
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Filename',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => {
                  setState(() {
                    _audioFilename = value;
                  }),
                },
              ),
            ),
            _isRecording
                ? Text("$_recordDuration",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900]))
                : Text("$_recordDuration",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900])),
            SizedBox(height: 20),
            if (!_isPlaybackAvail)
              IconButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: !_isRecording
                      ? Icon(
                          size: 48,
                          Icons.mic,
                          color: Colors.indigo[900],
                        )
                      : Icon(size: 48, Icons.mic_off, color: Colors.red)),
            SizedBox(height: 20),
            if (_isPlaybackAvail)
              Padding(
                padding: const EdgeInsets.fromLTRB(48.0, 0, 48.0, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: _reRecord,
                        icon: Icon(
                          size: 48,
                          Icons.replay,
                          color: Colors.indigo[900],
                        )),
                    IconButton(
                        onPressed: _playRecording,
                        icon: Icon(
                          size: 48,
                          Icons.play_circle_outline,
                          color: Colors.indigo[900],
                        ))
                  ],
                ),
              ),
            if (_isPlay)
              Slider(
                  value: (currentposition<totalduration)?currentposition:totalduration,
                  max: totalduration,
                  onChanged: (value) => {
                        setState(() {
                          if(currentposition<totalduration)
                            currentposition = value;
                        }),
                        _audioPlayer.seek(Duration(seconds: value.toInt()))
                      }),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
