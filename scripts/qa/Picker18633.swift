import XCTest
final class Picker18633: XCTestCase {
 func testSelectSystemPhoto() {
  let app=XCUIApplication(bundleIdentifier:"blab.nastia.ez.test")
  app.launch()
  sleep(7)
  let before=XCTAttachment(screenshot:XCUIScreen.main.screenshot());before.name="Actual OS picker before selection";before.lifetime = .keepAlways;add(before)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.16,dy:0.44)).tap()
  sleep(3)
  let after=XCTAttachment(screenshot:XCUIScreen.main.screenshot());after.name="After actual photo tap";after.lifetime = .keepAlways;add(after)
  print("BLA39_AFTER_PHOTO_TAP "+app.debugDescription)
  sleep(35)
  let final=XCTAttachment(screenshot:XCUIScreen.main.screenshot());final.name="Native flow final";final.lifetime = .keepAlways;add(final)
 }
}
