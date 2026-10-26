import XCTest
final class FullAppTests: XCTestCase {
 func testDirect() { review("Direct", title: "Alice") }
 func testGroup() { review("Group", title: "Weekend plans") }
 func testPrivate() { review("Private", title: "Blab") }
 func review(_ scenario: String, title: String) {
  let app = XCUIApplication(bundleIdentifier: "blab.nastia.ez.test")
  app.launch()
  let button = app.buttons[scenario].firstMatch
  XCTAssertTrue(button.waitForExistence(timeout: 15))
  button.tap()
  let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
  if sb.buttons["Allow"].waitForExistence(timeout: 2) { sb.buttons["Allow"].tap() }
  let notification = sb.staticTexts[title].firstMatch
  guard notification.waitForExistence(timeout: 12) else { print(sb.debugDescription); XCTFail("Full-app local notification missing"); return }
  capture("full-app-\(scenario.lowercased())-compact")
  notification.press(forDuration: 1.5)
  sleep(3)
  capture("full-app-\(scenario.lowercased())-expanded")
  XCUIDevice.shared.press(.home)
  app.terminate()
 }
 func capture(_ name: String) {
  let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
 }
}
