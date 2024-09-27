package com.example.vision_assist_app;

import android.os.Bundle;
import android.view.KeyEvent;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.vision_assist_app/volume_buttons";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL).setMethodCallHandler(
            (call, result) -> {
                if (call.method.equals("volumeUpPressed")) {
                    result.success("volumeUpPressed");
                } else if (call.method.equals("volumeDownPressed")) {
                    result.success("volumeDownPressed");
                } else {
                    result.notImplemented();
                }
            }
        );
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("volumeUpPressed", null);
            return true;
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("volumeDownPressed", null);
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }
}
