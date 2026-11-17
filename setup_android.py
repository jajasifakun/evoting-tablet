import os
import shutil
import re

def main():
    print("=== Setting up Android configuration ===")

    # 1. Update AndroidManifest.xml
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            content = f.read()

        perms = """    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
"""
        if "android.permission.CAMERA" not in content:
            content = content.replace("<application", perms + "    <application")

        content = re.sub(r'android:label="[^"]*"', 'android:label="E-Voting Karang Mukti"', content)
        if "android:roundIcon" not in content:
            content = content.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher"')

        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("AndroidManifest.xml updated successfully.")

    # 2. Update Launcher Icons dengan Logo Resmi Pilkades
    logo_src = "assets/images/pilkades-logo.png"
    if os.path.exists(logo_src):
        try:
            from PIL import Image
            img = Image.open(logo_src).convert("RGBA")
            sizes = {
                "mipmap-mdpi": (48, 48),
                "mipmap-hdpi": (72, 72),
                "mipmap-xhdpi": (96, 96),
                "mipmap-xxhdpi": (144, 144),
                "mipmap-xxxhdpi": (192, 192),
            }
            res_dir = "android/app/src/main/res"
            for folder, sz in sizes.items():
                d = os.path.join(res_dir, folder)
                os.makedirs(d, exist_ok=True)
                resized = img.resize(sz, Image.LANCZOS if hasattr(Image, "LANCZOS") else Image.Resampling.LANCZOS)
                resized.save(os.path.join(d, "ic_launcher.png"), "PNG")

            # Adaptive foreground icon
            fg_dir = os.path.join(res_dir, "drawable")
            os.makedirs(fg_dir, exist_ok=True)
            fg = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
            fit = img.resize((360, 360), Image.LANCZOS if hasattr(Image, "LANCZOS") else Image.Resampling.LANCZOS)
            fg.paste(fit, (76, 76), fit)
            fg.save(os.path.join(fg_dir, "ic_launcher_foreground.png"), "PNG")
            print("Multi-density icons generated with PIL.")
        except Exception as e:
            print("PIL not available, using file copy fallback:", e)
            for root, dirs, files in os.walk("android/app/src/main/res"):
                for fn in files:
                    if "ic_launcher" in fn and fn.endswith(".png"):
                        shutil.copy(logo_src, os.path.join(root, fn))

        val_dir = "android/app/src/main/res/values"
        os.makedirs(val_dir, exist_ok=True)
        with open(os.path.join(val_dir, "colors.xml"), "w", encoding="utf-8") as f:
            f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>""")
        print("Launcher icons set successfully.")

    # 3. Update MainActivity.kt dengan Native Bluetooth ESC/POS Thermal Printer Channel
    kt_code = """package com.evoting.evoting_karangmukti

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import java.io.OutputStream
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.evoting/thermal_printer"
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPairedDevices" -> {
                    try {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        if (adapter == null || !adapter.isEnabled) {
                            result.success(emptyList<Map<String, String>>())
                            return@setMethodCallHandler
                        }
                        val devices = adapter.bondedDevices.map { device ->
                            mapOf("name" to (device.name ?: "Unknown"), "address" to device.address)
                        }
                        result.success(devices)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    val device = adapter?.getRemoteDevice(address)
                    if (device != null) {
                        Thread {
                            try {
                                outputStream?.close()
                                bluetoothSocket?.close()
                                val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                                bluetoothSocket = device.createRfcommSocketToServiceRecord(sppUuid)
                                bluetoothSocket?.connect()
                                outputStream = bluetoothSocket?.outputStream
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                outputStream = null
                                bluetoothSocket = null
                                runOnUiThread { result.success(false) }
                            }
                        }.start()
                    } else {
                        result.success(false)
                    }
                }
                "printRaw" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (outputStream != null && bytes != null) {
                        Thread {
                            try {
                                outputStream?.write(bytes)
                                outputStream?.flush()
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.success(false) }
                            }
                        }.start()
                    } else {
                        result.success(false)
                    }
                }
                "disconnect" -> {
                    try {
                        outputStream?.close()
                        bluetoothSocket?.close()
                    } catch (e: Exception) {}
                    outputStream = null
                    bluetoothSocket = null
                    result.success(true)
                }
                "isConnected" -> {
                    result.success(bluetoothSocket?.isConnected ?: false)
                }
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "Surat_Undangan.png"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        try {
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                                val values = android.content.ContentValues().apply {
                                    put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                    put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "image/png")
                                    put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, android.os.Environment.DIRECTORY_DOWNLOADS)
                                }
                                val uri = contentResolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                if (uri != null) {
                                    contentResolver.openOutputStream(uri)?.use { os ->
                                        os.write(bytes)
                                        os.flush()
                                    }
                                    result.success(true)
                                    return@setMethodCallHandler
                                }
                            } else {
                                val file = java.io.File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), fileName)
                                file.outputStream().use { os ->
                                    os.write(bytes)
                                    os.flush()
                                }
                                result.success(true)
                                return@setMethodCallHandler
                            }
                        } catch (e: Exception) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }
}
"""
    for root, dirs, files in os.walk("android"):
        if "MainActivity.kt" in files:
            target = os.path.join(root, "MainActivity.kt")
            with open(target, "w", encoding="utf-8") as f:
                f.write(kt_code)
            print("MainActivity.kt written at:", target)

    print("=== Android setup complete ===")

if __name__ == "__main__":
    main()
