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
    <uses-feature android:name="android.hardware.usb.host" android:required="false" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
"""
        if "android.permission.CAMERA" not in content:
            content = content.replace("<application", perms + "    <application")

        if "android.hardware.usb.host" not in content:
            content = content.replace("<application", '    <uses-feature android:name="android.hardware.usb.host" android:required="false" />\n    <application')

        if 'android:requestLegacyExternalStorage="true"' not in content:
            content = content.replace("<application", '<application android:requestLegacyExternalStorage="true"')

        content = re.sub(r'android:label="[^"]*"', 'android:label="E-Voting Pilkades Tati"', content)
        if "android:roundIcon" not in content:
            content = content.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher"')

        # FileProvider for opening and sharing PDF files
        file_provider_xml = """        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>"""
        if "androidx.core.content.FileProvider" not in content:
            content = content.replace("</application>", file_provider_xml)

        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("AndroidManifest.xml updated successfully.")

    gradle_path = "android/app/build.gradle"
    if os.path.exists(gradle_path):
        with open(gradle_path, "r", encoding="utf-8") as f:
            g_content = f.read()
        g_content = re.sub(r'applicationId\s+"[^"]*"', 'applicationId "com.evoting.pilkades_tati"', g_content)
        with open(gradle_path, "w", encoding="utf-8") as f:
            f.write(g_content)
        print("build.gradle applicationId updated to com.evoting.pilkades_tati.")

    # 1b. Create res/xml/file_paths.xml for FileProvider
    xml_dir = "android/app/src/main/res/xml"
    os.makedirs(xml_dir, exist_ok=True)
    with open(os.path.join(xml_dir, "file_paths.xml"), "w", encoding="utf-8") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-files-path name="external_files" path="." />
    <external-path name="external_storage" path="." />
    <cache-path name="cache" path="." />
    <files-path name="internal_files" path="." />
</paths>""")
    print("file_paths.xml created successfully.")

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

    # 3. Update MainActivity.kt dengan Dual Thermal Printer (Bluetooth + USB Cable OTG) & Native PDF Generator
    kt_code = """package com.evoting.evoting_karangmukti

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.evoting/thermal_printer"

    // Bluetooth printer state
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private var connectedBtName: String? = null
    private var connectedBtAddress: String? = null

    // USB Cable printer state
    private var usbManager: UsbManager? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var usbEndpointOut: UsbEndpoint? = null
    private var connectedUsbName: String? = null
    private var connectedUsbDeviceId: String? = null

    // Multi-page PDF generator state
    private var activePdfDocument: PdfDocument? = null
    private var activePdfFileName: String = ""
    private var activePdfPageCount: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ==================== BLUETOOTH PRINTER ====================
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
                    if (address.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val ok = connectBluetoothInternal(address)
                        runOnUiThread { result.success(ok) }
                    }.start()
                }
                "disconnect" -> {
                    disconnectBluetoothInternal()
                    result.success(true)
                }

                // ==================== USB CABLE PRINTER ====================
                "getUsbDevices" -> {
                    val list = getUsbPrintersInternal()
                    result.success(list)
                }
                "connectUsb" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val ok = connectUsbInternal(deviceId)
                    result.success(ok)
                }
                "disconnectUsb" -> {
                    disconnectUsbInternal()
                    result.success(true)
                }

                // ==================== COMMON PRINTER STATUS & AUTO-CONNECT ====================
                "isConnected" -> {
                    val isUsb = (usbConnection != null && usbEndpointOut != null)
                    val isBt = (bluetoothSocket?.isConnected == true)
                    result.success(isUsb || isBt)
                }
                "getConnectionStatus" -> {
                    val isUsb = (usbConnection != null && usbEndpointOut != null)
                    val isBt = (bluetoothSocket?.isConnected == true)
                    val map = mutableMapOf<String, Any?>()
                    map["connected"] = (isUsb || isBt)
                    if (isUsb) {
                        map["type"] = "USB"
                        map["name"] = connectedUsbName ?: "Printer Kabel USB"
                    } else if (isBt) {
                        map["type"] = "BLUETOOTH"
                        map["name"] = connectedBtName ?: "Printer Bluetooth"
                    } else {
                        map["type"] = "NONE"
                        map["name"] = null
                    }
                    result.success(map)
                }
                "autoConnect" -> {
                    Thread {
                        // 1. Cek USB terlebih dahulu (koneksi kabel prioritas tinggi & sangat stabil)
                        val usbList = getUsbPrintersInternal()
                        if (usbList.isNotEmpty()) {
                            val firstUsb = usbList.first()
                            val devId = firstUsb["deviceId"]?.toString()
                            val usbOk = connectUsbInternal(devId)
                            if (usbOk) {
                                runOnUiThread {
                                    result.success(mapOf(
                                        "success" to true,
                                        "type" to "USB",
                                        "name" to (firstUsb["name"] ?: "Printer Kabel USB")
                                    ))
                                }
                                return@Thread
                            }
                        }

                        // 2. Jika tidak ada USB, cek printer Bluetooth yang sudah dipair
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        if (adapter != null && adapter.isEnabled) {
                            val bonded = adapter.bondedDevices
                            val matched = bonded.find { d ->
                                val n = (d.name ?: "").lowercase()
                                n.contains("print") || n.contains("pos") || n.contains("rpp") ||
                                n.contains("mpt") || n.contains("thermal") || n.contains("58") || n.contains("80")
                            } ?: bonded.firstOrNull()

                            if (matched != null) {
                                val btOk = connectBluetoothInternal(matched.address)
                                if (btOk) {
                                    runOnUiThread {
                                        result.success(mapOf(
                                            "success" to true,
                                            "type" to "BLUETOOTH",
                                            "name" to (matched.name ?: "Printer Bluetooth")
                                        ))
                                    }
                                    return@Thread
                                }
                            }
                        }

                        runOnUiThread {
                            result.success(mapOf("success" to false, "type" to "NONE"))
                        }
                    }.start()
                }
                "printRaw" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null && bytes.isNotEmpty()) {
                        Thread {
                            val sent = sendRawInternal(bytes)
                            runOnUiThread { result.success(sent) }
                        }.start()
                    } else {
                        result.success(false)
                    }
                }

                // ==================== PDF ENGINE & EXPORT ====================
                "createSinglePdf" -> {
                    val fileName = call.argument<String>("fileName") ?: "Surat_Undangan_C6.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        try {
                            val pdf = PdfDocument()
                            drawBitmapToA4(pdf, 1, bytes)
                            val res = savePdfDocument(pdf, fileName)
                            result.success(res)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            result.success(mapOf("success" to false, "error" to (e.message ?: "Gagal membuat dokumen PDF")))
                            return@setMethodCallHandler
                        }
                    }
                    result.success(mapOf("success" to false, "error" to "Data gambar kosong"))
                }
                "startMultiPagePdf" -> {
                    val fileName = call.argument<String>("fileName") ?: "Surat_Undangan_C6_Semua_Pemilih.pdf"
                    try {
                        activePdfDocument?.close()
                        activePdfDocument = PdfDocument()
                        activePdfFileName = fileName
                        activePdfPageCount = 0
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "addPageToPdf" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val doc = activePdfDocument
                    if (doc != null && bytes != null) {
                        try {
                            activePdfPageCount++
                            drawBitmapToA4(doc, activePdfPageCount, bytes)
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(false)
                }
                "finishMultiPagePdf" -> {
                    val doc = activePdfDocument
                    val fileName = activePdfFileName
                    if (doc != null && activePdfPageCount > 0) {
                        try {
                            val res = savePdfDocument(doc, fileName)
                            activePdfDocument = null
                            activePdfPageCount = 0
                            result.success(res)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            activePdfDocument?.close()
                            activePdfDocument = null
                            activePdfPageCount = 0
                            result.success(mapOf("success" to false, "error" to (e.message ?: "Gagal menyimpan dokumen PDF")))
                            return@setMethodCallHandler
                        }
                    }
                    activePdfDocument?.close()
                    activePdfDocument = null
                    result.success(mapOf("success" to false, "error" to "Tidak ada halaman yang ditambahkan"))
                }
                "openPdf" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val ok = openPdfFile(filePath)
                        result.success(ok)
                    } else {
                        result.success(false)
                    }
                }
                "sharePdf" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val ok = sharePdfFile(filePath)
                        result.success(ok)
                    } else {
                        result.success(false)
                    }
                }
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "Surat_Undangan.png"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        try {
                            val docsDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                            val f = File(docsDir, fileName)
                            FileOutputStream(f).use { it.write(bytes) }
                            result.success(true)
                            return@setMethodCallHandler
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

    // ==================== HELPER: BLUETOOTH ====================
    private fun connectBluetoothInternal(address: String): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        val device = adapter.getRemoteDevice(address) ?: return false

        try {
            adapter.cancelDiscovery()
            disconnectBluetoothInternal()

            val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            var socket: BluetoothSocket? = null

            // 1. Percobaan standar UUID SPP
            try {
                socket = device.createRfcommSocketToServiceRecord(sppUuid)
                socket.connect()
            } catch (e1: Exception) {
                // 2. Fallback reflection untuk printer thermal mini (PT-210, RPP, POS-58, dll)
                try {
                    val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    socket = m.invoke(device, 1) as BluetoothSocket
                    socket.connect()
                } catch (e2: Exception) {
                    socket?.close()
                    return false
                }
            }

            bluetoothSocket = socket
            outputStream = socket?.outputStream
            connectedBtName = device.name ?: "Printer Bluetooth"
            connectedBtAddress = address
            return true
        } catch (e: Exception) {
            disconnectBluetoothInternal()
            return false
        }
    }

    private fun disconnectBluetoothInternal() {
        try {
            outputStream?.close()
            bluetoothSocket?.close()
        } catch (e: Exception) {}
        outputStream = null
        bluetoothSocket = null
        connectedBtName = null
        connectedBtAddress = null
    }

    // ==================== HELPER: USB CABLE ====================
    private fun getUsbPrintersInternal(): List<Map<String, Any>> {
        val manager = usbManager ?: return emptyList()
        val list = mutableListOf<Map<String, Any>>()

        for (device in manager.deviceList.values) {
            var isPrinter = (device.deviceClass == UsbConstants.USB_CLASS_PRINTER)
            var hasBulkOut = false

            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                    isPrinter = true
                }
                for (j in 0 until iface.endpointCount) {
                    val ep = iface.getEndpoint(j)
                    if (ep.direction == UsbConstants.USB_DIR_OUT && ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                        hasBulkOut = true
                    }
                }
            }

            if (isPrinter || hasBulkOut) {
                val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val prod = device.productName ?: "Printer Kasir USB"
                    val mfg = device.manufacturerName ?: "Thermal"
                    "$prod ($mfg)"
                } else {
                    "Printer USB (${device.deviceName})"
                }
                list.add(mapOf(
                    "name" to name,
                    "deviceId" to device.deviceId.toString(),
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "deviceName" to device.deviceName
                ))
            }
        }
        return list
    }

    private fun connectUsbInternal(deviceId: String?): Boolean {
        val manager = usbManager ?: return false
        val device = if (!deviceId.isNullOrEmpty()) {
            manager.deviceList.values.find { it.deviceId.toString() == deviceId }
        } else {
            manager.deviceList.values.firstOrNull()
        } ?: return false

        try {
            disconnectUsbInternal()

            if (!manager.hasPermission(device)) {
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                val pi = PendingIntent.getBroadcast(this, 0, Intent("com.evoting.USB_PERMISSION"), flags)
                manager.requestPermission(device, pi)
            }

            val conn = manager.openDevice(device) ?: return false

            var targetIface: UsbInterface? = null
            var targetEp: UsbEndpoint? = null

            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                for (j in 0 until iface.endpointCount) {
                    val ep = iface.getEndpoint(j)
                    if (ep.direction == UsbConstants.USB_DIR_OUT && ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                        targetIface = iface
                        targetEp = ep
                        break
                    }
                }
                if (targetEp != null) break
            }

            if (targetIface == null || targetEp == null) {
                conn.close()
                return false
            }

            conn.claimInterface(targetIface, true)
            usbConnection = conn
            usbInterface = targetIface
            usbEndpointOut = targetEp
            connectedUsbDeviceId = device.deviceId.toString()
            connectedUsbName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                device.productName ?: "Printer Kabel USB"
            } else {
                "Printer Kabel USB"
            }
            return true
        } catch (e: Exception) {
            disconnectUsbInternal()
            return false
        }
    }

    private fun disconnectUsbInternal() {
        try {
            if (usbConnection != null && usbInterface != null) {
                usbConnection?.releaseInterface(usbInterface)
            }
            usbConnection?.close()
        } catch (e: Exception) {}
        usbConnection = null
        usbInterface = null
        usbEndpointOut = null
        connectedUsbName = null
        connectedUsbDeviceId = null
    }

    // ==================== HELPER: RAW DATA TRANSMISSION ====================
    private fun sendRawInternal(bytes: ByteArray): Boolean {
        // 1. Coba kirim via USB jika aktif
        val conn = usbConnection
        val ep = usbEndpointOut
        if (conn != null && ep != null) {
            try {
                val count = conn.bulkTransfer(ep, bytes, bytes.size, 5000)
                if (count >= 0) return true
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 2. Coba kirim via Bluetooth jika aktif
        val stream = outputStream
        if (stream != null) {
            try {
                stream.write(bytes)
                stream.flush()
                return true
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 3. Jika belum terhubung, coba auto-connect otomatis sekali lagi
        try {
            val usbPrinters = getUsbPrintersInternal()
            if (usbPrinters.isNotEmpty()) {
                val devId = usbPrinters.first()["deviceId"]?.toString()
                if (connectUsbInternal(devId)) {
                    val c = usbConnection
                    val p = usbEndpointOut
                    if (c != null && p != null) {
                        val count = c.bulkTransfer(p, bytes, bytes.size, 5000)
                        if (count >= 0) return true
                    }
                }
            }
        } catch (e: Exception) {}

        return false
    }

    // ==================== HELPER: PDF GENERATION ====================
    private fun drawBitmapToA4(doc: PdfDocument, pageNumber: Int, imageBytes: ByteArray) {
        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: return
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, pageNumber).create()
        val page = doc.startPage(pageInfo)
        val canvas = page.canvas

        val pageWidth = 595f
        val pageHeight = 842f
        val margin = 20f

        val maxW = pageWidth - (margin * 2)
        val maxH = pageHeight - (margin * 2)

        val scale = Math.min(maxW / bitmap.width.toFloat(), maxH / bitmap.height.toFloat())
        val destW = bitmap.width.toFloat() * scale
        val destH = bitmap.height.toFloat() * scale

        val left = (pageWidth - destW) / 2f
        val top = (pageHeight - destH) / 2f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val srcRect = Rect(0, 0, bitmap.width, bitmap.height)
        val destRect = RectF(left, top, left + destW, top + destH)

        canvas.drawBitmap(bitmap, srcRect, destRect, paint)
        doc.finishPage(page)
        bitmap.recycle()
    }

    private fun savePdfDocument(doc: PdfDocument, fileName: String): Map<String, Any> {
        val safeFileName = if (fileName.endsWith(".pdf", ignoreCase = true)) fileName else "$fileName.pdf"
        val docsDir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS) ?: filesDir
        if (!docsDir.exists()) docsDir.mkdirs()
        val file = File(docsDir, safeFileName)

        FileOutputStream(file).use { os ->
            doc.writeTo(os)
        }
        doc.close()

        var publicDisplayPath = file.absolutePath

        // Coba simpan ke folder publik Downloads jika diizinkan OS
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                    val selectionArgs = arrayOf(safeFileName)
                    contentResolver.delete(MediaStore.Downloads.EXTERNAL_CONTENT_URI, selection, selectionArgs)
                } catch (_: Exception) {}

                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, safeFileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/")
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { os ->
                        file.inputStream().use { it.copyTo(os) }
                    }
                    publicDisplayPath = "Folder Download/$safeFileName"
                }
            } else {
                val pubDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (pubDir.exists() || pubDir.mkdirs()) {
                    val pubFile = File(pubDir, safeFileName)
                    file.copyTo(pubFile, overwrite = true)
                    MediaScannerConnection.scanFile(this, arrayOf(pubFile.absolutePath), arrayOf("application/pdf"), null)
                    publicDisplayPath = pubFile.absolutePath
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return mapOf(
            "success" to true,
            "filePath" to file.absolutePath,
            "fileName" to safeFileName,
            "displayPath" to publicDisplayPath
        )
    }

    private fun openPdfFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(Intent.createChooser(intent, "Buka Dokumen PDF Surat Undangan"))
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun sharePdfFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(Intent.createChooser(intent, "Bagikan / Cetak PDF Surat Undangan"))
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
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
