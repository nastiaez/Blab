import XCTest
final class Picker18633: XCTestCase {
 func testRecoveryJourney() {
  addUIInterruptionMonitor(withDescription: "Task-owned Camera denial") { alert in
   guard alert.label.contains("Camera") else { return false }
   let deny=alert.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'Don'")).firstMatch
   if deny.exists {
    let permission=XCTAttachment(screenshot:XCUIScreen.main.screenshot());permission.name="Actual native Camera permission before denial";permission.lifetime = .keepAlways;self.add(permission)
    deny.tap(); return true
   }
   return false
  }
  let app=XCUIApplication(bundleIdentifier:"blab.nastia.ez.test")
  app.launch()
  sleep(12)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.09,dy:0.125)).tap()
  sleep(8)
  let spring=XCUIApplication(bundleIdentifier:"com.apple.springboard")
  let denial=spring.alerts.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'Don'")).firstMatch
  if denial.waitForExistence(timeout: 4) {
   let permission=XCTAttachment(screenshot:XCUIScreen.main.screenshot());permission.name="Actual native Camera permission before explicit denial";permission.lifetime = .keepAlways;add(permission)
   denial.tap()
  }
  if app.alerts.buttons["OK"].waitForExistence(timeout: 8) { app.alerts.buttons["OK"].tap() }
  let recovery=XCTAttachment(screenshot:XCUIScreen.main.screenshot());recovery.name="Native cancellation and unavailable-camera recovery";recovery.lifetime = .keepAlways;add(recovery)
  sleep(12)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.16,dy:0.44)).tap()
  sleep(2)
 }
 func testSelectSystemPhoto() {
  let app=XCUIApplication(bundleIdentifier:"blab.nastia.ez.test")
  app.launch()
  sleep(20)
  let before=XCTAttachment(screenshot:XCUIScreen.main.screenshot());before.name="Actual OS picker before selection";before.lifetime = .keepAlways;add(before)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.16,dy:0.44)).tap()
  sleep(3)
  let after=XCTAttachment(screenshot:XCUIScreen.main.screenshot());after.name="After actual photo tap";after.lifetime = .keepAlways;add(after)
  print("BLA39_AFTER_PHOTO_TAP "+app.debugDescription)
  // Release XCTest accessibility ownership before Flutter end-of-test checks.
  let final=XCTAttachment(screenshot:XCUIScreen.main.screenshot());final.name="Native flow final";final.lifetime = .keepAlways;add(final)
 }
 func testCancelAndCameraDiagnostic() {
  let app=XCUIApplication(bundleIdentifier:"blab.nastia.ez.test")
  app.launch()
  sleep(20)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.09,dy:0.125)).tap()
  sleep(3)
  let cancel=XCTAttachment(screenshot:XCUIScreen.main.screenshot());cancel.name="Actual native Photo cancel";cancel.lifetime = .keepAlways;add(cancel)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.445)).tap()
  sleep(2)
  let camera=XCTAttachment(screenshot:XCUIScreen.main.screenshot());camera.name="Actual simulator Camera attempt";camera.lifetime = .keepAlways;add(camera)
 }
}
