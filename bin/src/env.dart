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

library codecov.bin.src.env;

import 'package:args/args.dart';

late Env env;

class Env {
  List<String> filePaths;
  bool html;
  bool lcov;
  List<String> reportOn;
  bool verbose;

  Env(this.filePaths, this.reportOn, this.html, this.lcov, this.verbose);
}

void setupEnv(List<String> args) {
  final parser = ArgParser();
  parser.addOption('report-on', abbr: 'r');
  parser.addFlag('html', defaultsTo: true);
  parser.addFlag('lcov', defaultsTo: true);
  parser.addFlag('verbose', abbr: 'v');

  final results = parser.parse(args);
  List<String> filePaths =
      results.rest.length > 0 ? results.rest : <String>['test'];

  env = Env(
    filePaths,
    results['report-on'] ?? <String>[],
    results['html'],
    results['lcov'],
    results['verbose'] ?? false,
  );
}
