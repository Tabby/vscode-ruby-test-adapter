import * as vscode from 'vscode'
import path from 'path'
import { IChildLogger } from '@vscode-logging/logger';
import { Config } from './config';

export type TestItemCallback = (item: vscode.TestItem) => void

/**
 * Manages the contents and state of the test suite
 *
 * Responsible for creating, deleting and finding test items
 */
export class TestSuiteManager {
  private readonly log: IChildLogger;

  constructor(
    readonly rootLog: IChildLogger,
    public readonly controller: vscode.TestController,
    public readonly config: Config
  ) {
    this.log = rootLog.getChildLogger({label: 'TestSuite'});
  }

  public deleteTestItem(testId: string | vscode.Uri) {
    let log = this.log.getChildLogger({label: 'deleteTestItem'})
    testId = this.uriToTestId(testId)
    log.debug('Deleting test', testId)
    let testItem = this.getTestItem(testId)
    if (!testItem) {
      log.error('No test item found with given ID', testId)
      return
    }
    let collection = testItem.parent ? testItem.parent.children : this.controller.items
    if (collection) {
      collection.delete(testId);
      log.debug('Removed test', testId)
    } else {
      log.error('Parent collection not found')
    }
  }

  /**
   * Get the {@link vscode.TestItem} for a test ID
   * @param testId Test ID to lookup
   * @param onItemCreated Optional callback to be notified when test items are created
   * @returns The test item for the ID
   * @throws if test item could not be found
   */
  public getOrCreateTestItem(testId: string | vscode.Uri, onItemCreated?: TestItemCallback): vscode.TestItem {
    let log = this.log.getChildLogger({label: 'getOrCreateTestItem'})
    return this.getTestItemInternal(log, testId, true, onItemCreated)!
  }

  /**
   * Gets a TestItem from the list of tests
   * @param testId ID of the TestItem to get
   * @returns TestItem if found, else undefined
   */
  public getTestItem(testId: string | vscode.Uri): vscode.TestItem | undefined {
    let log = this.log.getChildLogger({label: 'getTestItem'})
    return this.getTestItemInternal(log, testId, false)
  }

  /**
   * Takes a test ID from the test runner output and normalises it to a consistent format
   *
   * - Removes leading './' if present
   * - Removes leading test dir if present
   */
  public normaliseTestId(testId: string): string {
    let log = this.log.getChildLogger({label: `normaliseTestId(${testId})`})
    if (testId.startsWith(`.${path.sep}`)) {
      testId = testId.substring(2)
    }
    if (testId.startsWith(this.config.getRelativeTestDirectory())) {
      testId = testId.replace(this.config.getRelativeTestDirectory(), '')
    }
    if (testId.startsWith(path.sep)) {
      testId = testId.substring(1)
    }
    log.debug('Normalised ID', testId)
    return testId
  }

  /**
   * Converts a test URI into a test ID
   * @param uri URI of test
   * @returns test ID
   */
  private uriToTestId(uri: string | vscode.Uri): string {
    let log = this.log.getChildLogger({label: `uriToTestId(${uri})`})
    if (typeof uri === "string") {
      log.debug("uri is string. Returning unchanged")
      return uri
    }
    let fullTestDirPath = this.config.getAbsoluteTestDirectory()
    log.debug('Full path to test dir', fullTestDirPath)
    let strippedUri = uri.fsPath.replace(fullTestDirPath + path.sep, '')
    log.debug('Stripped URI', strippedUri)
    return strippedUri
  }

  private testIdToUri(testId: string): vscode.Uri {
    return vscode.Uri.file(path.resolve(this.config.getAbsoluteTestDirectory(), testId.replace(/\[.*\]/, '')))
  }

  /**
   * Creates a TestItem and adds it to a TestItemCollection
   * @param collection
   * @param testId
   * @param label
   * @param uri
   * @param canResolveChildren
   * @returns
   */
  private createTestItem(
    testId: string,
    label: string,
    parent?: vscode.TestItem,
    onItemCreated: TestItemCallback = (_) => {},
    canResolveChildren: boolean = true,
  ): vscode.TestItem {
    let log = this.log.getChildLogger({ label: `${this.createTestItem.name}(${testId})` })
    let uri = this.testIdToUri(testId)
    log.debug('Creating test item', {label: label, parentId: parent?.id, canResolveChildren: canResolveChildren, uri: uri})
    let item = this.controller.createTestItem(testId, label, uri)
    item.canResolveChildren = canResolveChildren;
    (parent?.children || this.controller.items).add(item);
    log.debug('Added test', item.id)
    onItemCreated(item)
    return item
  }

  /**
   * Splits a test ID into an array of all parent IDs to reach the given ID from the test tree root
   * @param testId test ID to split
   * @returns array of test IDs
   */
  private getParentIdsFromId(testId: string): string[] {
    let log = this.log.getChildLogger({label: `${this.getParentIdsFromId.name}(${testId})`})
    testId = this.normaliseTestId(testId)

    // Split path segments
    let idSegments = testId.split(path.sep)
    log.debug('id segments', idSegments)
    if (idSegments[0] === "") {
      idSegments.splice(0, 1)
    }
    log.trace('ID segments split by path', idSegments)
    for (let i = 1; i < idSegments.length - 1; i++) {
      let currentSegment = idSegments[i]
      let precedingSegments = idSegments.slice(0, i + 1)
      log.trace(`segment: ${currentSegment}. preceding segments`, precedingSegments)
      idSegments[i] = path.join(...precedingSegments)
    }
    log.trace('ID segments joined with preceding segments', idSegments)

    // Split location
    const match = idSegments.at(-1)?.match(/(?<fileId>[^\[]*)(?:\[(?<location>[0-9:]+)\])?/)
    if (match && match.groups) {
      // Get file ID (with path to it if there is one)
      let fileId = match.groups["fileId"]
      log.trace('Filename', fileId)
      if (idSegments.length > 1) {
        fileId = path.join(idSegments.at(-2)!, fileId)
        log.trace('Filename with path', fileId)
      }
      // Add file ID to array
      idSegments.splice(-1, 1, fileId)
      log.trace('ID segments with file ID inserted', idSegments)

      if (match.groups["location"]) {
        let locations = match.groups["location"].split(':')
        log.trace('ID location segments', locations)
        if (locations.length == 1) {
          // Insert ID for minitest location
          let contextId = `${fileId}[${locations[0]}]`
          idSegments.push(contextId)
        } else {
          // Insert IDs for each nested RSpec context if there are any
          for (let i = 1; i < locations.length; i++) {
            let contextId = `${fileId}[${locations.slice(0, i + 1).join(':')}]`
            idSegments.push(contextId)
          }
        }
        log.trace('ID segments with location IDs appended', idSegments)
      }
    }
    return idSegments
  }

  private getTestItemInternal(
    log: IChildLogger,
    testId: string | vscode.Uri,
    createIfMissing: boolean,
    onItemCreated?: TestItemCallback
  ): vscode.TestItem | undefined {
    testId = this.normaliseTestId(this.uriToTestId(testId))

    log.debug('Looking for test', testId)
    let parentIds = this.getParentIdsFromId(testId)
    let item: vscode.TestItem | undefined = undefined
    let itemCollection: vscode.TestItemCollection = this.controller.items

    // Walk through test folders to find the collection containing our test file,
    // creating parent items as needed
    for (const id of parentIds) {
      log.debug('Getting item from parent collection', id, item?.id || 'controller')
      let child = itemCollection.get(id)
      if (!child) {
        if (createIfMissing) {
          child = this.createTestItem(
            id,
            id, // Temporary label
            item,
            onItemCreated,
            !(id == testId) // Only the test ID will be a test case. All parents need this set to true
          )
        } else {
          return undefined
        }
      }
      item = child
      itemCollection = child.children
    }

    return item
  }
}
