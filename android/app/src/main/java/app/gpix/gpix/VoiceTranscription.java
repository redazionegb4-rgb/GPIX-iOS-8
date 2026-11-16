package app.gpix.gpix;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.Intent;
import android.media.AudioFormat;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

public final class VoiceTranscription {
    private final Context context;
    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel.Result pending;
    private SpeechRecognizer recognizer;
    private ParcelFileDescriptor source;
    private final Runnable timeout = () -> finish(null, "Tempo scaduto durante la trascrizione.");

    public VoiceTranscription(Context context, BinaryMessenger messenger) {
        this.context = context.getApplicationContext();
        new MethodChannel(messenger, "GPIX/transcription").setMethodCallHandler((call, result) -> {
            if (!"transcribe".equals(call.method)) {
                result.notImplemented();
                return;
            }
            if (Build.VERSION.SDK_INT < 33 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(this.context)) {
                result.error("UNAVAILABLE", "Serve Android 13 o successivo con riconoscimento vocale sul dispositivo.", null);
                return;
            }
            if (pending != null) {
                result.error("BUSY", "È già in corso una trascrizione.", null);
                return;
            }
            String path = call.argument("path");
            String language = call.argument("language");
            if (path == null || language == null) {
                result.error("AUDIO", "Vocale non disponibile.", null);
                return;
            }
            pending = result;
            main.postDelayed(timeout, 90000);
            new Thread(() -> prepare(path, language, result), "gpix-transcription").start();
        });
    }

    private void prepare(String path, String language, MethodChannel.Result request) {
        File pcm = null;
        ParcelFileDescriptor descriptor = null;
        try {
            pcm = File.createTempFile("gpix-transcription-", ".pcm", context.getCacheDir());
            MediaFormat format = decode(path, pcm);
            descriptor = ParcelFileDescriptor.open(pcm, ParcelFileDescriptor.MODE_READ_ONLY);
            ParcelFileDescriptor audio = descriptor;
            main.post(() -> {
                if (pending != request) {
                    close(audio);
                    return;
                }
                start(audio, format, language);
            });
        } catch (Exception error) {
            close(descriptor);
            main.post(() -> {
                if (pending == request) finish(null, "Impossibile leggere il vocale.");
            });
        } finally {
            if (pcm != null) pcm.delete();
        }
    }

    private static MediaFormat decode(String path, File pcm) throws IOException {
        MediaExtractor extractor = new MediaExtractor();
        MediaCodec decoder = null;
        try (FileOutputStream output = new FileOutputStream(pcm)) {
            extractor.setDataSource(path);
            MediaFormat input = null;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat track = extractor.getTrackFormat(i);
                String mime = track.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    input = track;
                    extractor.selectTrack(i);
                    break;
                }
            }
            if (input == null) throw new IOException("No audio track");
            decoder = MediaCodec.createDecoderByType(input.getString(MediaFormat.KEY_MIME));
            decoder.configure(input, null, null, 0);
            decoder.start();
            MediaFormat decoded = input;
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            boolean inputEnded = false;
            long deadline = SystemClock.elapsedRealtime() + 45000;
            while (SystemClock.elapsedRealtime() < deadline) {
                if (!inputEnded) {
                    int index = decoder.dequeueInputBuffer(5000);
                    if (index >= 0) {
                        ByteBuffer buffer = decoder.getInputBuffer(index);
                        int size = extractor.readSampleData(buffer, 0);
                        inputEnded = size < 0;
                        decoder.queueInputBuffer(index, 0, Math.max(0, size),
                            inputEnded ? 0 : extractor.getSampleTime(),
                            inputEnded ? MediaCodec.BUFFER_FLAG_END_OF_STREAM : 0);
                        if (!inputEnded) extractor.advance();
                    }
                }
                int index = decoder.dequeueOutputBuffer(info, 5000);
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    decoded = decoder.getOutputFormat();
                    if (decoded.containsKey(MediaFormat.KEY_PCM_ENCODING)
                        && decoded.getInteger(MediaFormat.KEY_PCM_ENCODING) != AudioFormat.ENCODING_PCM_16BIT) {
                        throw new IOException("Unsupported PCM encoding");
                    }
                } else if (index >= 0) {
                    if (info.size > 0) {
                        ByteBuffer buffer = decoder.getOutputBuffer(index);
                        byte[] data = new byte[info.size];
                        buffer.position(info.offset);
                        buffer.get(data);
                        output.write(data);
                    }
                    decoder.releaseOutputBuffer(index, false);
                    if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) return decoded;
                }
            }
            throw new IOException("Audio decoding timed out");
        } finally {
            if (decoder != null) decoder.release();
            extractor.release();
        }
    }

    @TargetApi(33)
    private void start(ParcelFileDescriptor audio, MediaFormat format, String language) {
        source = audio;
        try {
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context);
            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, source)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, format.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, format.getInteger(MediaFormat.KEY_SAMPLE_RATE))
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                .putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE);
            MethodChannel.Result request = pending;
            recognizer.setRecognitionListener(new RecognitionListener() {
                private final StringBuilder text = new StringBuilder();

                private String first(Bundle results) {
                    ArrayList<String> values = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                    return values == null || values.isEmpty() ? "" : values.get(0).trim();
                }

                @Override public void onSegmentResults(Bundle results) {
                    String segment = first(results);
                    if (!segment.isEmpty()) {
                        if (text.length() > 0) text.append(' ');
                        text.append(segment);
                    }
                }
                @Override public void onEndOfSegmentedSession() {
                    if (pending == request) finish(text.toString(), null);
                }
                @Override public void onResults(Bundle results) {
                    if (pending != request) return;
                    // An engine that ignores the injected audio returns a regular microphone result.
                    finish(null, "Il riconoscimento sul dispositivo non supporta questo vocale.");
                }
                @Override public void onError(int error) {
                    if (pending != request) return;
                    if (error == SpeechRecognizer.ERROR_NO_MATCH) finish("", null);
                    else finish(null, "Trascrizione non disponibile. Verifica il riconoscimento vocale italiano sul dispositivo.");
                }
                @Override public void onReadyForSpeech(Bundle params) {}
                @Override public void onBeginningOfSpeech() {}
                @Override public void onRmsChanged(float rms) {}
                @Override public void onBufferReceived(byte[] buffer) {}
                @Override public void onEndOfSpeech() {}
                @Override public void onPartialResults(Bundle results) {}
                @Override public void onEvent(int eventType, Bundle params) {}
            });
            recognizer.startListening(intent);
        } catch (RuntimeException error) {
            finish(null, "Riconoscimento vocale sul dispositivo non disponibile.");
        }
    }

    private static void close(ParcelFileDescriptor descriptor) {
        if (descriptor == null) return;
        try { descriptor.close(); } catch (IOException ignored) {}
    }

    private void finish(String text, String error) {
        MethodChannel.Result result = pending;
        pending = null;
        main.removeCallbacks(timeout);
        if (recognizer != null) {
            recognizer.destroy();
            recognizer = null;
        }
        close(source);
        source = null;
        if (result == null) return;
        if (error == null) result.success(text);
        else result.error("TRANSCRIPTION", error, null);
    }

    public void close() {
        finish(null, "Trascrizione interrotta.");
    }
}
