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

library codecov.bin.src.coverage;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'env.dart';
import 'test.dart' show Test, BrowserTest;

int _coverageCount = 0;
const int _defaultObservatoryPort = 8444;
const String tempCoverageDirPath = '__temp_coverage';
Directory coverageDir = Directory('coverage');

class Coverage {
  static Future<Coverage> merge(List<Coverage> coverages) async {
    if (coverages.isEmpty) {
      throw ArgumentError('Cannot merge an empty list of coverages.');
    }
    final Logger log = Logger('dcg');
    final Coverage merged = Coverage(null);
    merged._tempCoverageDir = coverageDir;

    for (int i = 0; i < coverages.length; i++) {
      if (await coverages[i].coverageFile.exists()) {
        final File coverageFile = coverages[i].coverageFile;
        final String base = path.basename(coverageFile.path);
        coverageFile.rename('${coverageDir.path}/$i-$base');
      }
    }
    log.info('Merging complete');
    return merged;
  }

  Test? test;
  late File lcovOutput;
  late File coverageFile;
  Directory? _tempCoverageDir;
  Coverage(this.test) {
    _coverageCount++;
  }

  Future<bool> collect() async {
    final Logger log = Logger('dcg');
    final bool testSuccess = await test!.run();
    if (!testSuccess) {
      try {
        log.info(test!.process.stderr.transform(utf8.decoder));
      } catch (_) {}
      log.severe('Testing failed.');
      test!.kill();
      return false;
    }

    final int port = test! is BrowserTest
        ? (test! as BrowserTest).observatoryPort
        : _defaultObservatoryPort;

    final Directory _tempCoverageDir =
        Directory('${coverageDir.path}/$_coverageCount');
    await _tempCoverageDir.create(recursive: true);

    log.info('Collecting coverage...');
    final ProcessResult pr = await Process.run('pub', [
      'run',
      'test',
      '--coverage',
      _tempCoverageDir.path,
    ]);
    log.info('Coverage collected');

    test!.kill();
    log.info(pr.stdout);

    final Directory testDir = Directory('${_tempCoverageDir.path}/test');
    final List<FileSystemEntity> entities = testDir.listSync();
    if (entities.length == 1 && entities[0] is File) {
      coverageFile = entities[0] as File;
    }

    if (pr.exitCode == 0) {
      log.info('Coverage collected.');
      return true;
    } else {
      log.info(pr.stderr);
      log.severe('Coverage collection failed.');
      return false;
    }
  }

  Future<bool> format() async {
    final Logger log = Logger('dcg');
    log.info('Formatting coverage...');
    lcovOutput = File('${_tempCoverageDir!.path}/coverage.lcov');
    final List<String> args = [
      'run',
      'coverage:format_coverage',
      '--lcov',
      '--packages=.packages',
      '-i',
      _tempCoverageDir!.path,
      '-o',
      lcovOutput.path,
    ];

    args.addAll(env.reportOn.map((r) => '--report-on=$r'));
    if (env.verbose) {
      args.add('--verbose');
    }
    final ProcessResult pr = await Process.run('pub', args);

    log.info(pr.stdout);
    if (pr.exitCode == 0) {
      log.info('Coverage formatted.');
      return true;
    } else {
      log.info(pr.stderr);
      log.severe('Coverage formatting failed.');
      return false;
    }
  }

  Future<bool> generateHtml() async {
    final Logger log = Logger('dcg');
    log.info('Generating HTML...');
    final ProcessResult pr = await Process.run(
      'genhtml',
      <String>['-o', 'coverage_report', lcovOutput.path],
    );

    log.info(pr.stdout);
    if (pr.exitCode == 0) {
      log.info('HTML generated.');
      return true;
    } else {
      log.info(pr.stderr);
      log.severe('HTML generation failed.');
      return false;
    }
  }

  void cleanUp({bool recursive = false}) {
    if (test != null) {
      test!.cleanUp();
    }
    if (_tempCoverageDir != null) {
      _tempCoverageDir!.deleteSync(recursive: recursive);
    }
  }
}
