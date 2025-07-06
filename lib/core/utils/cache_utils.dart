import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AviiCacheManager {
  static const _key = 'aviiCache';
  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
      repo: JsonCacheInfoRepository(databaseName: _key),
      fileService: HttpFileService(),
    ),
  );

  AviiCacheManager._();
}
