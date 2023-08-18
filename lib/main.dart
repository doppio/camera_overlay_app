import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const App());

class App extends HookWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() => requestPermissions, []);

    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      home: const Home(),
    );
  }

  Future<void> requestPermissions() async {
    await Permission.camera.request();
    await Permission.photos.request();
  }
}

class Home extends HookWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final cameraController = useFuture(useMemoized(() => initializeCamera()));
    final overlayOpacity = useState(0.5);
    final overlayImage = useState<ImageProvider?>(null);
    final isSaving = useState(false);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: cameraController.hasData
                    ? CameraPreview(cameraController.data!)
                    : const CircularProgressIndicator(),
              ),
            ),
            if (overlayImage.value != null)
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 5,
                  boundaryMargin: EdgeInsets.all(MediaQuery.of(context).size.longestSide / 2),
                  child: Opacity(
                    opacity: overlayOpacity.value,
                    child: Image(image: overlayImage.value!),
                  ),
                ),
              ),
            if (isSaving.value)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: Slider(
                value: overlayOpacity.value,
                onChanged: (v) => overlayOpacity.value = v,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () async {
              isSaving.value = true;
              await captureImage(cameraController.data!);
              isSaving.value = false;
            },
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () async {
              final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);

              if (pickedImage != null) {
                overlayImage.value = FileImage(File(pickedImage.path));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<CameraController> initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    final camera = CameraController(
      firstCamera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await camera.initialize();

    camera.setZoomLevel(1.0);
    camera.setFlashMode(FlashMode.off);
    camera.setFocusMode(FocusMode.auto);
    camera.setExposureMode(ExposureMode.auto);
    camera.unlockCaptureOrientation();
    return camera;
  }

  Future<void> captureImage(CameraController controller) async {
    try {
      final file = await controller.takePicture();

      final result = await ImageGallerySaver.saveImage(
        await file.readAsBytes(),
        quality: 100,
      );

      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Image saved to $result')),
      );
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Capture error: $e')),
      );
    }
  }
}

final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();
