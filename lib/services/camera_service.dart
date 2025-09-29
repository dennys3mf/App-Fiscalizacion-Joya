import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Captura una foto de la licencia con compresión automática
  static Future<String?> capturarFotoLicencia({
    required String boletaId,
    required BuildContext context,
  }) async {
    try {
      // Mostrar opciones de cámara o galería
      final ImageSource? source = await _showImageSourceDialog(context);
      if (source == null) return null;

      // Capturar imagen
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Calidad inicial del 85%
        maxWidth: 1024,   // Máximo 1024px de ancho
        maxHeight: 1024,  // Máximo 1024px de alto
        preferredCameraDevice: CameraDevice.rear, // Cámara trasera por defecto
      );

      if (image == null) return null;

      // Comprimir imagen para reducir tamaño
      final File compressedImage = await _compressImage(File(image.path));

      // Subir a Firebase Storage
      final String downloadUrl = await _uploadToFirebaseStorage(
        compressedImage,
        boletaId,
      );

      // Limpiar archivo temporal
      await compressedImage.delete();

      return downloadUrl;
    } catch (e) {
      print('Error al capturar foto de licencia: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Muestra diálogo para seleccionar fuente de imagen
  static Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Capturar Foto de Licencia'),
        content: const Text('¿Cómo deseas obtener la foto?'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Cámara'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galería'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Comprime la imagen para reducir su tamaño
  static Future<File> _compressImage(File imageFile) async {
    try {
      // Obtener directorio temporal
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Comprimir imagen
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 70,        // Calidad del 70% (balance entre calidad y tamaño)
        minWidth: 800,      // Ancho mínimo
        minHeight: 600,     // Alto mínimo
        format: CompressFormat.jpeg, // Formato JPEG para mejor compresión
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      } else {
        // Si falla la compresión, devolver archivo original
        return imageFile;
      }
    } catch (e) {
      print('Error al comprimir imagen: $e');
      // Si falla la compresión, devolver archivo original
      return imageFile;
    }
  }

  /// Sube la imagen comprimida a Firebase Storage
  static Future<String> _uploadToFirebaseStorage(File imageFile, String boletaId) async {
    try {
      // Crear referencia única en Firebase Storage
      final String fileName = 'licencia_${boletaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('licencias')
          .child(fileName);

      // Configurar metadata para optimizar
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'boletaId': boletaId,
          'tipo': 'licencia',
          'comprimida': 'true',
        },
      );

      // Subir archivo
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      
      // Obtener URL de descarga
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error al subir imagen a Firebase Storage: $e');
      throw Exception('Error al subir imagen: $e');
    }
  }

  /// Obtiene el tamaño de un archivo en KB
  static Future<double> getFileSizeInKB(File file) async {
    try {
      final int bytes = await file.length();
      return bytes / 1024; // Convertir a KB
    } catch (e) {
      return 0;
    }
  }

  /// Elimina una imagen de Firebase Storage
  static Future<void> eliminarFotoLicencia(String downloadUrl) async {
    try {
      final Reference ref = FirebaseStorage.instance.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      print('Error al eliminar foto de licencia: $e');
    }
  }

  /// Verifica si una URL de imagen es válida
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('https://') && 
           (url.contains('firebasestorage.googleapis.com') || 
            url.contains('storage.googleapis.com'));
  }

  /// Obtiene información de la imagen (tamaño, metadata)
  static Future<Map<String, dynamic>?> getImageInfo(String downloadUrl) async {
    try {
      final Reference ref = FirebaseStorage.instance.refFromURL(downloadUrl);
      final FullMetadata metadata = await ref.getMetadata();
      
      return {
        'size': metadata.size,
        'sizeKB': (metadata.size ?? 0) / 1024,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated,
        'boletaId': metadata.customMetadata?['boletaId'],
        'comprimida': metadata.customMetadata?['comprimida'] == 'true',
      };
    } catch (e) {
      print('Error al obtener información de imagen: $e');
      return null;
    }
  }
}

/// Widget para mostrar vista previa de la imagen capturada
class ImagePreviewWidget extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback? onRetake;
  final VoidCallback? onRemove;

  const ImagePreviewWidget({
    super.key,
    this.imageUrl,
    this.onRetake,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || !CameraService.isValidImageUrl(imageUrl)) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Sin foto de licencia',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      Text('Error al cargar imagen'),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Botones de acción
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRetake != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      onPressed: onRetake,
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                const SizedBox(width: 4),
                if (onRemove != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          
          // Indicador de foto de licencia
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Licencia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
