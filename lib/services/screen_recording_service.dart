import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;


/// Manages screen + microphone recording, stream merging,
/// MediaRecorder lifecycle, and Firebase Storage upload with slot overwrite logic.
class ScreenRecordingService {
  // MediaRecorder state
  html.MediaRecorder? _recorder;
  html.MediaStream? _displayStream;
  html.MediaStream? _audioStream;
  html.MediaStream? _combinedStream;
  final List<dynamic> _chunks = [];

  // Recording limits
  static const int maxDurationSeconds = 30 * 60; // 30 minutes
  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  /// Starts recording by requesting screen + microphone and merging streams
  Future<void> startRecording({
    required Function(int elapsedSeconds) onDurationUpdate,
    required Function(String error) onError,
  }) async {
    try {
      // Reset state
      _chunks.clear();
      _elapsedSeconds = 0;

      // 1. Get display media (screen + system audio) - use dynamic dispatch
      try {
        final dynamic navMediaDevices = (html.window.navigator as dynamic).mediaDevices;
        if (navMediaDevices == null) {
          onError('Screen capture not supported in this browser');
          return;
        }
        
        // Call getDisplayMedia dynamically
        final displayPromise = (navMediaDevices as dynamic).getDisplayMedia({
          'video': {'cursor': 'always'},
          'audio': true
        });
        _displayStream = await (displayPromise as dynamic) as html.MediaStream;
      } catch (e) {
        onError('Screen capture denied or unavailable: $e');
        return;
      }

      // 2. Get microphone
      try {
        final dynamic navMediaDevices = (html.window.navigator as dynamic).mediaDevices;
        final audioPromise = (navMediaDevices as dynamic).getUserMedia({
          'audio': true
        });
        _audioStream = await (audioPromise as dynamic) as html.MediaStream;
      } catch (e) {
        onError('Microphone access denied: $e');
        _displayStream?.getTracks().forEach((track) => track.stop());
        return;
      }

      // 3. Merge streams
      _combinedStream = _mergeStreams(_displayStream!, _audioStream!);

      // 4. Create MediaRecorder
      try {
        _recorder = html.MediaRecorder(_combinedStream!, {
          'mimeType': 'video/webm;codecs=vp8,opus',
          'videoBitsPerSecond': 1500000,
          'audioBitsPerSecond': 128000,
        } as dynamic);
      } catch (e) {
        _recorder = html.MediaRecorder(_combinedStream!);
      }

      // Collect chunks
      _recorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        _chunks.add(blobEvent.data);
      });

      _recorder!.start();

      // Handle stop
      _recorder!.addEventListener('stop', (_) {
        _durationTimer?.cancel();
        _durationTimer = null;
      });

      // Duration tracking
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsedSeconds++;
        onDurationUpdate(_elapsedSeconds);

        if (_elapsedSeconds >= maxDurationSeconds) {
          stopRecording();
        }
      });
    } catch (e) {
      onError('Failed to start recording: $e');
      await cleanup();
    }
  }

  /// Stops the MediaRecorder and returns the recorded Blob
  Future<dynamic> stopRecording() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    if (_recorder == null) return null;

    _recorder!.stop();

    // Wait for chunks to be flushed
    await Future.delayed(const Duration(milliseconds: 100));

    if (_chunks.isEmpty) return null;

    // Combine all chunks into single Blob
    final videoBlob = html.Blob(_chunks, 'video/webm');
    return videoBlob;
  }

  /// Uploads the recorded blob to Firebase Storage with slot rotation
  Future<String?> uploadToFirebaseStorage({
    required String roomId,
    required dynamic videoBlob,
    required Function(double progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      // 1. Determine which slot to use (toggle between 1 and 2)
      final slotNumber = await _determineActiveSlot(roomId);
      final nextSlot = slotNumber == 1 ? 2 : 1;

      // 2. Upload to Firebase Storage
      final fileName = 'recordings/room_${roomId}_slot_$nextSlot.webm';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      // Convert Blob to Uint8List
      final fileData = await _blobToUint8List(videoBlob);

      if (fileData.isEmpty) {
        onError('Blob data is empty');
        return null;
      }

      // Upload with progress tracking
      final uploadTask = ref.putData(fileData);
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        },
        onError: (e) => onError('Upload error: $e'),
      );

      await uploadTask;

      // 3. Get download URL
      final downloadUrl = await ref.getDownloadURL();

      // 4. Save metadata to Firestore
      await _recordSlotMetadata(roomId, nextSlot, downloadUrl);

      return downloadUrl;
    } catch (e) {
      onError('Upload failed: $e');
      return null;
    }
  }

  /// Converts HTML Blob to Dart Uint8List
  Future<Uint8List> _blobToUint8List(dynamic blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onLoad.listen((event) {
      try {
        final dynamic result = reader.result;
        if (result is Uint8List) {
          completer.complete(result);
        } else if (result is List<int>) {
          completer.complete(Uint8List.fromList(result));
        } else {
          // result should be an ArrayBuffer
          completer.completeError('Unexpected result type');
        }
      } catch (e) {
        completer.completeError('Error reading blob: $e');
      }
    });

    reader.onError.listen((_) {
      completer.completeError('FileReader error');
    });

    reader.readAsArrayBuffer(blob as html.Blob);
    return completer.future;
  }

  /// Determines which slot to upload to (returns 1 or 2)
  Future<int> _determineActiveSlot(String roomId) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
      final doc = await docRef.get();

      if (!doc.exists) return 1;

      final lastSlot = doc.data()?['lastRecordingSlot'] as int? ?? 1;
      return lastSlot == 1 ? 2 : 1;
    } catch (e) {
      return 1;
    }
  }

  /// Records slot metadata in Firestore
  Future<void> _recordSlotMetadata(
    String roomId,
    int slotNumber,
    String downloadUrl,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
      await docRef.set(
        {
          'lastRecordingSlot': slotNumber,
          'lastRecordingUrl': downloadUrl,
          'lastRecordingTime': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Merges display stream video + both audio sources
  html.MediaStream _mergeStreams(
    html.MediaStream displayStream,
    html.MediaStream audioStream,
  ) {
    final tracks = <dynamic>[];

    // Video from display
    final videoTracks = displayStream.getVideoTracks();
    if (videoTracks.isNotEmpty) tracks.add(videoTracks[0]);

    // System audio from display
    final sysAudio = displayStream.getAudioTracks();
    if (sysAudio.isNotEmpty) tracks.add(sysAudio[0]);

    // Microphone audio
    final micAudio = audioStream.getAudioTracks();
    if (micAudio.isNotEmpty) tracks.add(micAudio[0]);

    // Create combined stream
    return html.MediaStream(tracks);
  }

  /// Cleans up all resources
  Future<void> cleanup() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      if (_recorder != null && _recorder!.state.toString() != 'inactive') {
        _recorder!.stop();
      }
    } catch (_) {}

    _displayStream?.getTracks().forEach((t) => t.stop());
    _audioStream?.getTracks().forEach((t) => t.stop());
    _combinedStream?.getTracks().forEach((t) => t.stop());

    _displayStream = null;
    _audioStream = null;
    _combinedStream = null;
    _recorder = null;
    _chunks.clear();
  }

  int get elapsedSeconds => _elapsedSeconds;
  bool get isRecording => _recorder?.state.toString() == 'recording';
}
