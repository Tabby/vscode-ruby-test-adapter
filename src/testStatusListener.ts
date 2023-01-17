import * as vscode from 'vscode'
import { IChildLogger } from '@vscode-logging/logger'
import { Status, TestStatus } from './testStatus'

/**
 * Updates the TestRun when test status events are received
 */
export class TestStatusListener {
  public static listen(
    rootLog: IChildLogger,
    profile: vscode.TestRunProfile,
    testRun: vscode.TestRun,
    testStatusEmitter: vscode.EventEmitter<TestStatus>
  ): vscode.Disposable {
    let log = rootLog.getChildLogger({ label: `${TestStatusListener.name}(${profile.label})`})
    return testStatusEmitter.event((event: TestStatus) => {

      switch(event.status) {
        case Status.skipped:
          log.info('Test skipped: %s', event.testItem.id)
          testRun.skipped(event.testItem)
          break;
        case Status.passed:
          if (this.isTestLoad(profile)) {
            log.info('Test loaded: %s (duration: %d)', event.testItem.id, event.duration)
          } else {
            log.info('Test passed: %s (duration: %d)', event.testItem.id, event.duration)
            testRun.passed(event.testItem, event.duration)
          }
          break;
        case Status.errored:
          log.info('Test errored: %s (duration: %d)', event.testItem.id, event.duration, event.message)
          if (event.message) {
            testRun.errored(event.testItem, event.message, event.duration)
          }
          break;
        case Status.failed:
          log.info('Test failed: %s (duration: %d)', event.testItem.id, event.duration, event.message)
          if (event.message) {
            testRun.failed(event.testItem, event.message, event.duration)
          }
          break;
        case Status.running:
          if (this.isTestLoad(profile)) {
            log.debug('Ignored test started event from test load: %s (duration: %d)', event.testItem.id, event.duration)
          } else {
            log.info('Test started: %s', event.testItem.id)
            testRun.started(event.testItem)
          }
          break;
        default:
          log.warn('Unexpected status: %s', event.status)
      }
    })
  }

  /**
   * Checks if the current test run is for loading tests rather than running them
   */
  private static isTestLoad(profile: vscode.TestRunProfile): boolean {
    return profile.label == 'ResolveTests'
  }
}
