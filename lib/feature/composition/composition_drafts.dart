import 'package:hive/hive.dart';
import 'package:otraku/feature/composition/composition_model.dart';

abstract class CompositionDrafts {
  CompositionDrafts._();

  static Box<String>? _box;

  static Future<Box<String>> _openBox() async =>
      _box ??= await Hive.openBox<String>('composition_drafts');

  static Future<String?> read(CompositionTag tag) async {
    final box = await _openBox();
    return box.get(tag.draftKey);
  }

  static Future<void> save(CompositionTag tag, String text) async {
    final box = await _openBox();
    if (text.isEmpty) {
      await box.delete(tag.draftKey);
    } else {
      await box.put(tag.draftKey, text);
    }
  }
}
