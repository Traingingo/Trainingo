import 'package:file_picker/file_picker.dart';

class MaterialService {
  Future<String?> pickMaterialFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'txt'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single.name;
  }
}