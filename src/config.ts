import * as vscode from 'vscode';
import * as path from 'path';
import * as childProcess from 'child_process';
import { IChildLogger, IVSCodeExtLogger } from '@vscode-logging/logger';

export abstract class Config {

  /**
   * Full path to the ruby script directory
   */
  public readonly rubyScriptPath: string;

  public readonly workspaceFolder?: vscode.WorkspaceFolder;

  public gemfilePaths?: string[];

  /**
   * @param context Either a vscode.ExtensionContext with the extensionUri field set to the location of the extension,
   *   or a string containing the full path to the ruby script dir (the folder containing custom_formatter.rb)
   */
  constructor(context: vscode.ExtensionContext | string, workspaceFolder?: vscode.WorkspaceFolder) {
    if (typeof context === "object") {
      this.rubyScriptPath = vscode.Uri.joinPath(context?.extensionUri ?? vscode.Uri.file("./"), 'ruby').fsPath;
    } else {
      this.rubyScriptPath = (context as string)
    }
    this.workspaceFolder = workspaceFolder
  }

  /**
   * Printable name of the test framework
   */
  public abstract frameworkName(): string

  /**
   * Get the user-configured test file pattern.
   *
   * @return The file pattern
   */
  public getFilePattern(): Array<string> {
    let pattern: Array<string> =
      vscode.workspace.getConfiguration('rubyTestExplorer', null).get('filePattern') as Array<string>;
    return pattern || ['*_test.rb', 'test_*.rb'];
  }

  /**
   * Get the user-configured test directory relative to the test project root folder, if there is one.
   *
   * @return The test directory
   */
  public abstract getRelativeTestDirectory(): string;

  /**
   * Get the absolute path to user-configured test directory, if there is one.
   *
   * @return The test directory
   */
  public getAbsoluteTestDirectory(): string {
    return path.resolve(this.workspaceFolder?.uri.fsPath || '.', this.getRelativeTestDirectory())
  }

  public async findGemfiles(log: IChildLogger): Promise<string[]> {
    if (this.gemfilePaths) return this.gemfilePaths

    let cwd = this.workspaceFolder?.uri.fsPath || path.resolve('.')
    let gemfilePatterns = [
      // new vscode.RelativePattern(cwd, path.join('**', 'Gemfile')),
      // new vscode.RelativePattern(cwd, path.join('**', 'gems.rb'))
      '**/Gemfile',
      '**/gems.rb'
    ]
    let gemfilePaths: string[] = []
    for (const gemfilePattern of gemfilePatterns) {
      let uris = await vscode.workspace.findFiles(gemfilePattern, '**/gems/*')
      log.debug('Found gemfile uris', uris)
      gemfilePaths = gemfilePaths.concat(uris.map(uri => path.relative(cwd, uri.fsPath)))
    }
    this.gemfilePaths = gemfilePaths
    return gemfilePaths
  }

  public async findParentGemfileForTests(log: IChildLogger, testPaths: string[]) {
    let gemfilePaths = await this.findGemfiles(log)
    if (gemfilePaths.length == 1) {
      let gemfile = gemfilePaths[0]
      log.debug('Only one gemfile found: %s', gemfile)
      return path.resolve(path.dirname(gemfile))
    } else if (gemfilePaths.length > 1) {
      log.debug('Multiple gemfiles found', gemfilePaths)
      for (const gemfile of gemfilePaths) {
        let gemfileDir = path.resolve(path.dirname(gemfile))
        let isParent = true
        for (const testPath of testPaths) {
          const relative = path.relative(gemfileDir, testPath);
          if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
            isParent = false
            break
          }
          if (isParent) return gemfileDir
        }
      }
    } else {
      log.debug('No gemfiles found')
    }
    log.warn('No gemfile found that is a parent of tests to be run')
    return undefined
  }

  /**
   * Gets the arguments to pass to the command from the test items to be run/loaded
   *
   * @param testItem[] Array of test items to be run
   * @param debugConfiguration debug configuration
   */
  public abstract getTestArguments(testItems?: readonly vscode.TestItem[]): string[]

  /**
   * Gets the command to run the test framework.
   *
   * @param debugConfiguration debug configuration
   */
  public abstract getRunTestsCommand(debugConfiguration?: vscode.DebugConfiguration): string

  /**
   * Gets the command to load some or all of the tests in the suite
   *
   * @param testItems Array of TestItems to resolve children of, or undefined to resolve all tests
   */
  public abstract getResolveTestsCommand(): string

  /**
   * Get the env vars to run the subprocess with.
   *
   * @return The env
   */
  public abstract getProcessEnv(): any

  public static getTestFramework(log: IVSCodeExtLogger): string {
    let testFramework: string = vscode.workspace.getConfiguration('rubyTestExplorer', null).get('testFramework') || '';
    // If the test framework is something other than auto, return the value.
    if (['rspec', 'minitest', 'none'].includes(testFramework)) {
      return testFramework;
      // If the test framework is auto, we need to try to detect the test framework type.
    } else {
      return this.detectTestFramework(log);
    }
  }

  /**
   * Detect the current test framework using 'bundle list'.
   */
  private static detectTestFramework(log: IVSCodeExtLogger): string {
    log.info("Getting a list of Bundler dependencies with 'bundle list'.");

    const execArgs: childProcess.ExecOptions = {
      cwd: (vscode.workspace.workspaceFolders || [])[0].uri.fsPath,
      maxBuffer: 8192 * 8192
    };

    try {
      // Run 'bundle list' and set the output to bundlerList.
      // Execute this syncronously to avoid the test explorer getting stuck loading.
      let err, stdout = childProcess.execSync('bundle list', execArgs);

      if (err) {
        log.error('Error while listing Bundler dependencies', err);
        log.error('Output', stdout);
        throw err;
      }

      let bundlerList = stdout.toString();

      // Search for rspec or minitest in the output of 'bundle list'.
      // The search function returns the index where the string is found, or -1 otherwise.
      if (bundlerList.search('rspec-core') >= 0) {
        log.info('Detected RSpec test framework.');
        return 'rspec';
      } else if (bundlerList.search('minitest') >= 0) {
        log.info('Detected Minitest test framework.');
        return 'minitest';
      } else {
        log.info('Unable to automatically detect a test framework.');
        return 'none';
      }
    } catch (error: any) {
      log.error('Error while detecting test suite', error);
      return 'none';
    }
  }
}
