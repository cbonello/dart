// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library codecov.bin.src.executable;

import 'dart:io';

import 'package:logging/logging.dart';

import 'coverage.dart';
import 'env.dart' show env, setupEnv;
import 'test.dart';

const String _testFilePattern = '_test.dart';

void printLog(LogRecord record) {
  if (env.verbose || record.level >= Level.SEVERE) {
    print(record.message);
    if (record.error != null) {
      print(record.error);
    }
    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
  }
}

Future<void> main(List<String> args) async {
  setupEnv(args);

  bool htmlSuccess = false;
  bool lcovSuccess = false;

  final Logger log = Logger('dcg');
  log.onRecord.listen(printLog);
  log.shout('Generating coverage...');

  log.info('Environment:');
  log.info('\treportOn - ${env.reportOn}');
  log.info('\thtml - ${env.html}');
  log.info('\tlcov - ${env.lcov}');
  log.info('\tverbose - ${env.verbose}');

  if (!env.html && !env.lcov) {
    log.severe('You must enable HTML and/or lcov output.');
    exit(1);
  }

  if (env.filePaths.isEmpty) {
    log.severe('No test file given. Please specify at least one test file.');
    exit(1);
  }

  final List<String> testFiles = [];

  env.filePaths.forEach(
    (String filePath) {
      if (FileSystemEntity.isDirectorySync(filePath)) {
        final List<FileSystemEntity> children =
            Directory(filePath).listSync(recursive: true);
        final Iterable<FileSystemEntity> validChildren = children.where(
          (FileSystemEntity e) {
            return
                // Is a file, not a directory
                e is File &&
                    // Is not a package dependency file
                    !Uri.parse(e.path).pathSegments.contains('packages') &&
                    // Is a valid test file (ends with `_test.dart`)
                    e.path.endsWith(_testFilePattern);
          },
        );
        testFiles.addAll(validChildren.map((FileSystemEntity e) => e.path));
      } else if (FileSystemEntity.isFileSync(filePath)) {
        testFiles.add(filePath);
      }
    },
  );

  log.info('Test Files:');
  testFiles.forEach(
    (String filePath) {
      log.info('\tFile path: $filePath');
      if (!FileSystemEntity.isFileSync(filePath)) {
        log.severe(
          'Given test file does not exist: ${File(filePath).absolute.path}',
        );
        exit(1);
      }
      if (!filePath.endsWith('.dart') && !filePath.endsWith('.html')) {
        log.severe(
          'Given test file is invalid: ${File(filePath).absolute.path}',
        );
        exit(1);
      }
    },
  );

  final List<Coverage> coverages = [];
  for (int i = 0; i < testFiles.length; i++) {
    final Test test = await Test.parse(testFiles[i]);
    final Coverage coverage = Coverage(test);
    await coverage.collect();
    coverages.add(coverage);
  }

  final Coverage coverage = await Coverage.merge(coverages);
  coverages.forEach((cov) => cov.cleanUp());
  if (!await coverage.format()) {
    exit(1);
  }
  if (env.lcov) {
    coverage.lcovOutput.copySync('coverage.lcov');
    lcovSuccess = true;
  }
  if (env.html) {
    htmlSuccess = await coverage.generateHtml();
    if (!htmlSuccess) {
      exit(1);
    }
  }
  coverage.cleanUp(recursive: true);

  log.shout('\nCoverage generated!');
  if (lcovSuccess) {
    log.shout('\tlcov:  \tcoverage.lcov');
  }
  if (htmlSuccess) {
    log.shout('\treport:\tcoverage_report/index.html');
  }
}
