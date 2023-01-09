import * as vscode from 'vscode';
import { IVSCodeExtLogger } from "@vscode-logging/logger";
import { RspecTestRunner } from './rspec/rspecTestRunner';
import { MinitestTestRunner } from './minitest/minitestTestRunner';
import { Config } from './config';
import { TestLoader } from './testLoader';
import { RspecConfig } from './rspec/rspecConfig';
import { MinitestConfig } from './minitest/minitestConfig';
import { TestSuiteManager } from './testSuiteManager';

/**
 * Factory for (re)creating {@link TestRunner} and {@link TestLoader} instances
 *
 * Also takes care of disposing them when required
 */
export class TestFactory implements vscode.Disposable {
  private isDisposed = false;
  private loader: TestLoader | null = null;
  private runner: RspecTestRunner | MinitestTestRunner | null = null;
  protected disposables: { dispose(): void }[] = [];
  protected framework: string;
  private manager: TestSuiteManager

  constructor(
    private readonly log: IVSCodeExtLogger,
    private readonly controller: vscode.TestController,
    private config: Config,
    private readonly profiles: { runProfile: vscode.TestRunProfile, resolveTestsProfile: vscode.TestRunProfile, debugProfile: vscode.TestRunProfile },
    private readonly workspace?: vscode.WorkspaceFolder,
  ) {
    this.disposables.push(this.configWatcher());
    this.framework = Config.getTestFramework(this.log);
    this.manager = new TestSuiteManager(this.log, this.controller, this.config)
  }

  dispose(): void {
    this.isDisposed = true
    for (const disposable of this.disposables) {
      try {
        this.log.debug('Disposing object', disposable)
        disposable.dispose();
      } catch (error) {
        this.log.error('Error when disposing object', disposable, error)
      }
    }
    this.disposables = [];
  }

  /**
   * Returns the current {@link RspecTestRunner} or {@link MinitestTestRunner} instance
   *
   * If one does not exist, a new instance is created according to the current configured test framework,
   * which is then returned
   *
   * @returns Either {@link RspecTestRunner} or {@link MinitestTestRunner}
   * @throws if this factory has been disposed
   */
  public getRunner(): RspecTestRunner | MinitestTestRunner {
    this.checkIfDisposed()
    if (!this.runner) {
      this.runner = this.framework == "rspec"
        ? new RspecTestRunner(
            this.log,
            this.manager,
            this.workspace,
          )
        : new MinitestTestRunner(
            this.log,
            this.manager,
            this.workspace,
          )
      this.disposables.push(this.runner);
    }
    return this.runner
  }

  /**
   * Returns the current {@link TestLoader} instance
   *
   * If one does not exist, a new instance is created which is then returned
   *
   * @returns {@link TestLoader}
   * @throws if this factory has been disposed
   */
  public getLoader(): TestLoader {
    this.checkIfDisposed()
    if (!this.loader) {
      this.loader = new TestLoader(
        this.log,
        this.profiles.resolveTestsProfile,
        this.manager
      )
      this.disposables.push(this.loader)
    }
    return this.loader
  }

  /**
   * Helper method to check the current value of the isDisposed flag and to throw an error
   * if it is set, to prevent objects being created after {@link dispose()} has been called
   */
  private checkIfDisposed(): void {
    if (this.isDisposed) {
      throw new Error("Factory has been disposed")
    }
  }

  /**
   * Registers a listener with VSC to be notified if the configuration is changed to use a different test framework.
   *
   * If an event is received, we dispose the current loader, runner and config so that they can be recreated
   * for the new framework
   *
   * @returns A {@link Disposable} that is used to unregister the config watcher from receiving events
   */
  private configWatcher(): vscode.Disposable {
    return vscode.workspace.onDidChangeConfiguration(configChange => {
      this.log.info('Configuration changed');
      if (configChange.affectsConfiguration("rubyTestExplorer.testFramework")) {
        let newFramework = Config.getTestFramework(this.log);
        if (newFramework !== this.framework) {
          // Config has changed to a different framework - recreate test loader and runner
          this.config = newFramework == "rspec"
            ? new RspecConfig(this.config.rubyScriptPath)
            : new MinitestConfig(this.config.rubyScriptPath)
          if (this.loader) {
            this.disposeInstance(this.loader)
            this.loader = null
          }
          if (this.runner) {
            this.disposeInstance(this.runner)
            this.runner = null
          }
        }
      }
    })
  }

  /**
   * Helper method to dispose of an object and remove it from the list of disposables
   *
   * @param instance the object to be disposed
   */
  private disposeInstance(instance: vscode.Disposable) {
    let index = this.disposables.indexOf(instance);
    if (index !== -1) {
      this.disposables.splice(index)
    }
    else {
      this.log.debug("Factory instance not null but missing from disposables when configuration changed");
    }
    instance.dispose()
  }
}
