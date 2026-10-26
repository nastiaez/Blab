import XCTest
final class ReviewTests: XCTestCase {
 func testDirect() { review("direct", title: "Alice") }
 func testGroup() { review("group", title: "Weekend plans") }
 func testPrivate() { review("private", title: "Blab") }
 func review(_ scenario: String, title: String) {
  let app = XCUIApplication(bundleIdentifier: "com.blab.notificationreview")
  app.launchEnvironment["BLAB_REVIEW_CASE"] = scenario
  app.launch()
  let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
  if sb.buttons["Allow"].waitForExistence(timeout: 3) { sb.buttons["Allow"].tap() }
  XCUIDevice.shared.press(.home)
  let notification = sb.staticTexts[title].firstMatch
  guard notification.waitForExistence(timeout: 12) else { print(sb.debugDescription); XCTFail("Fixture missing"); return }
  capture("\(scenario)-compact")
  notification.press(forDuration: 1.5)
  sleep(3)
  capture("\(scenario)-expanded")
  print(sb.debugDescription)
  XCUIDevice.shared.press(.home)
  app.terminate()
 }
 func capture(_ name: String) {
  let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
 }
}
