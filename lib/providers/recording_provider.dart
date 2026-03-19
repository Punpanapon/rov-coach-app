import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/services/screen_recording_service.dart';
import 'package:web/web.dart' as web;

/// State class for screen recording
class RecordingState {
  final bool isRecording;
  final bool isUploading;
  final int elapsedSeconds;
  final double uploadProgress; // 0.0 to 1.0
  final String? downloadUrl;
  final String? errorMessage;

  const RecordingState({
    this.isRecording = false,
    this.isUploading = false,
    this.elapsedSeconds = 0,
    this.uploadProgress = 0.0,
    this.downloadUrl,
    this.errorMessage,
  });

  RecordingState copyWith({
    bool? isRecording,
    bool? isUploading,
    int? elapsedSeconds,
    double? uploadProgress,
    String? downloadUrl,
    String? errorMessage,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isUploading: isUploading ?? this.isUploading,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for managing screen recording state and lifecycle
class ScreenRecordingNotifier extends Notifier<RecordingState> {
  final _service = ScreenRecordingService();
  web.Blob? _recordedBlob;

  @override
  RecordingState build() {
    return const RecordingState();
  }

  /// Starts screen + microphone recording
  Future<void> startRecording() async {
    state = state.copyWith(
      isRecording: true,
      elapsedSeconds: 0,
      errorMessage: null,
    );

    try {
      await _service.startRecording(
        onDurationUpdate: (seconds) {
          state = state.copyWith(elapsedSeconds: seconds);
        },
        onError: (error) {
          state = state.copyWith(
            isRecording: false,
            errorMessage: error,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        errorMessage: 'Failed to start recording: $e',
      );
      await _service.cleanup();
    }
  }

  /// Stops the current recording and prepares it for upload
  Future<void> stopRecording() async {
    state = state.copyWith(isRecording: false);

    try {
      _recordedBlob = await _service.stopRecording();

      if (_recordedBlob == null) {
        state = state.copyWith(
          errorMessage: 'No recording data collected',
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to stop recording: $e',
      );
    } finally {
      // Don't cleanup yet - we need the blob for upload
    }
  }

  /// Uploads the recorded blob to Firebase Storage with slot overwrite
  Future<void> uploadRecording(String roomId) async {
    if (_recordedBlob == null) {
      state = state.copyWith(
        errorMessage: 'No recording to upload',
      );
      return;
    }

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      errorMessage: null,
    );

    try {
      var uploadError = '';
      var uploadProgress = 0.0;
      
      final downloadUrl = await _service.uploadToFirebaseStorage(
        roomId: roomId,
        videoBlob: _recordedBlob!,
        onProgress: (progress) {
          uploadProgress = progress;
          state = state.copyWith(uploadProgress: progress);
        },
        onError: (error) {
          uploadError = error;
          state = state.copyWith(
            errorMessage: error,
            isUploading: false,
          );
        },
      );

      if (downloadUrl != null && uploadError.isEmpty) {
        state = state.copyWith(
          isUploading: false,
          uploadProgress: 1.0,
          downloadUrl: downloadUrl,
          errorMessage: null,
        );
      } else if (uploadError.isEmpty) {
        state = state.copyWith(
          isUploading: false,
          errorMessage: 'Upload returned no URL',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Upload error: $e',
      );
    } finally {
      // Clean up blob after upload attempt
      _recordedBlob = null;
      await _service.cleanup();
    }
  }

  /// Cancels the current recording and cleanup
  Future<void> cancelRecording() async {
    state = state.copyWith(
      isRecording: false,
      isUploading: false,
      errorMessage: null,
    );
    _recordedBlob = null;
    await _service.cleanup();
  }

  /// Clears error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Riverpod provider for screen recording state
final screenRecordingProvider =
    NotifierProvider<ScreenRecordingNotifier, RecordingState>(
  ScreenRecordingNotifier.new,
);
