import XCTest
@testable import KsApi
@testable import Library
@testable import ReactiveExtensions_TestHelpers
@testable import ReactiveSwift
@testable import Result

internal final class SignupViewModelTests: TestCase {
  fileprivate let vm = SignupViewModel()
  fileprivate let configureWithText = TestObserver<String, NoError>()
  fileprivate let emailTextFieldBecomeFirstResponder = TestObserver<(), NoError>()
  fileprivate let isSignupButtonEnabled = TestObserver<Bool, NoError>()
  fileprivate let logIntoEnvironment = TestObserver<AccessTokenEnvelope, NoError>()
  fileprivate let nameTextFieldBecomeFirstResponder = TestObserver<(), NoError>()
  fileprivate let passwordTextFieldBecomeFirstResponder = TestObserver<(), NoError>()
  fileprivate let postNotification = TestObserver<Notification.Name, NoError>()
  fileprivate let setWeeklyNewsletterState = TestObserver<Bool, NoError>()
  fileprivate let showError = TestObserver<String, NoError>()

  fileprivate var configureWithTextSignal: Signal<String, NoError>!

  override func setUp() {
    super.setUp()

    let (
      configureWithText,
      emailTextFieldBecomeFirstResponder,
      isSignupButtonEnabled,
      logIntoEnvironment,
      passwordTextFieldBecomeFirstResponder,
      postNotification,
      nameTextFieldBecomeFirstResponder,
      setWeeklyNewsletterState,
      showError
    ) = self.vm.outputs()

    self.configureWithTextSignal = configureWithText

    emailTextFieldBecomeFirstResponder
      .observe(self.emailTextFieldBecomeFirstResponder.observer)
    isSignupButtonEnabled.observe(self.isSignupButtonEnabled.observer)
    logIntoEnvironment.observe(self.logIntoEnvironment.observer)
    nameTextFieldBecomeFirstResponder.observe(self.nameTextFieldBecomeFirstResponder.observer)
    passwordTextFieldBecomeFirstResponder.observe(self.passwordTextFieldBecomeFirstResponder.observer)
    postNotification.map { $0.name }.observe(self.postNotification.observer)
    setWeeklyNewsletterState.observe(self.setWeeklyNewsletterState.observer)
    showError.observe(self.showError.observer)
  }

  func testConfigureWithText() {
    // 1. send a value to configureWithTextObserver
    self.vm.inputs.configureWithTextObserver.send(value: "hello")
    // 1a. send a second value to confirm that only the last value is sent
    self.vm.inputs.configureWithTextObserver.send(value: "bye")

    // 2. bind signal observer
    self.configureWithTextSignal.observe(self.configureWithText.observer)

    // 3. assert that nothing is emitted until viewDidLoad is sent a value
    self.configureWithText.assertValues([], "No signal emitted")

    // 4. send value to viewDidLoadObserver
    self.vm.inputs.viewDidLoadObserver.send(value: ())

    // 5. emits with last value of configureWithTextProperty
    self.configureWithText.assertValues(["bye"], "Emits with last value")
  }

  // Tests a standard flow for signing up.
  func testSignupFlow() {
    self.nameTextFieldBecomeFirstResponder.assertDidNotEmitValue()
    self.emailTextFieldBecomeFirstResponder.assertDidNotEmitValue()
    self.passwordTextFieldBecomeFirstResponder.assertDidNotEmitValue()

    self.vm.inputs.viewDidLoadObserver.send(value: ())

    XCTAssertEqual(["User Signup", "Viewed Signup"], self.trackingClient.events)
    self.setWeeklyNewsletterState.assertValues([false], "Unselected when view loads.")
    self.isSignupButtonEnabled.assertValues([false], "Disabled when view loads.")
    self.nameTextFieldBecomeFirstResponder
      .assertValueCount(1, "Name field is first responder when view loads.")
    self.emailTextFieldBecomeFirstResponder.assertDidNotEmitValue("Not first responder when view loads.")
    self.passwordTextFieldBecomeFirstResponder.assertDidNotEmitValue("Not first responder when view loads.")

    self.vm.inputs.nameTextChangedObserver.send(value: "Native Squad")
    self.vm.inputs.nameTextFieldDidReturnObserver.send(value: ())
    self.isSignupButtonEnabled.assertValues([false], "Disable while form is incomplete.")
    self.nameTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit again.")
    self.emailTextFieldBecomeFirstResponder.assertValueCount(1, "First responder after editing name.")
    self.passwordTextFieldBecomeFirstResponder
      .assertDidNotEmitValue("Not first responder after editing name.")

    self.vm.inputs.emailTextChangedObserver.send(value: "therealnativesquad@gmail.com")
    self.vm.inputs.emailTextFieldDidReturnObserver.send(value: ())
    self.isSignupButtonEnabled.assertValues([false], "Disabled while form is incomplete.")
    self.nameTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit again.")
    self.emailTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit again.")
    self.passwordTextFieldBecomeFirstResponder.assertValueCount(1, "First responder after editing email.")

    self.vm.inputs.passwordTextChangedObserver.send(value: "0773rw473rm3l0n")
    self.isSignupButtonEnabled.assertValues([false, true], "Enabled when form is valid.")

    self.vm.inputs.passwordTextFieldDidReturnObserver.send(value: ())
    self.vm.inputs.signupButtonPressedObserver.send(value: ())
    XCTAssertEqual(["User Signup", "Viewed Signup"], self.trackingClient.events)
    self.logIntoEnvironment.assertDidNotEmitValue("Does not immediately emit after signup button is pressed.")

    self.scheduler.advance()
    XCTAssertEqual(["User Signup", "Viewed Signup", "New User", "Signed Up"], self.trackingClient.events)
    // swiftlint:disable:next force_unwrapping
    XCTAssertEqual("Email", trackingClient.properties.last!["auth_type"] as? String)
    self.logIntoEnvironment.assertValueCount(1, "Login after scheduler advances.")
    self.postNotification.assertDidNotEmitValue("Does not emit until environment logged in.")

    self.vm.inputs.environmentLoggedInObserver.send(value: ())

    self.scheduler.advance()
    XCTAssertEqual(["User Signup", "Viewed Signup", "New User", "Signed Up", "Login", "Logged In"],
                   self.trackingClient.events)
    self.postNotification.assertValues([.ksr_sessionStarted],
                                  "Notification posted after scheduler advances.")
  }

  func testBecomeFirstResponder() {
    self.vm.inputs.viewDidLoadObserver.send(value: ())
    self.nameTextFieldBecomeFirstResponder.assertValueCount(1, "Name starts as first responder.")
    self.emailTextFieldBecomeFirstResponder.assertDidNotEmitValue("Not first responder yet.")
    self.passwordTextFieldBecomeFirstResponder.assertDidNotEmitValue("Not first responder yet.")

    self.vm.inputs.nameTextFieldDidReturnObserver.send(value: ())
    self.nameTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit another value.")
    self.emailTextFieldBecomeFirstResponder.assertValueCount(1, "Email becomes first responder.")
    self.passwordTextFieldBecomeFirstResponder.assertDidNotEmitValue("Not first responder yet.")

    self.vm.inputs.emailTextFieldDidReturnObserver.send(value: ())
    self.nameTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit another value.")
    self.emailTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit another value.")
    self.passwordTextFieldBecomeFirstResponder.assertValueCount(1, "Password becomes first responder.")

    self.vm.inputs.passwordTextFieldDidReturnObserver.send(value: ())
    self.nameTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit another value.")
    self.emailTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit another value.")
    self.passwordTextFieldBecomeFirstResponder.assertValueCount(1, "Does not emit another value.")
  }

  func testSetWeeklyNewsletterStateFalseOnViewDidLoad() {
    self.setWeeklyNewsletterState.assertDidNotEmitValue("Should not emit until view loads")

    self.withEnvironment(config: Config.deConfig) {
      self.vm.inputs.viewDidLoadObserver.send(value: ())
      self.setWeeklyNewsletterState.assertValues([false], "False by default for non-US users.")
    }
  }

  func testShowError() {
    let error = "Password is too short (minimum is 6 characters)"
    let errorEnvelope = ErrorEnvelope(
      errorMessages: [error],
      ksrCode: nil,
      httpCode: 422,
      exception: nil
    )

    self.withEnvironment(apiService: MockService(signupError: errorEnvelope)) {
      self.vm.inputs.viewDidLoadObserver.send(value: ())

      XCTAssertEqual(["User Signup", "Viewed Signup"], self.trackingClient.events)
      self.vm.inputs.emailTextChangedObserver.send(value: "nativesquad@kickstarter.com")
      self.vm.inputs.nameTextChangedObserver.send(value: "Native Squad")
      self.vm.inputs.passwordTextChangedObserver.send(value: "!")
      self.vm.inputs.signupButtonPressedObserver.send(value: ())

      self.showError.assertDidNotEmitValue("Should not emit until scheduler advances.")

      self.scheduler.advance()
      self.logIntoEnvironment.assertValueCount(0, "Should not login.")
      self.showError.assertValues([error], "Signup error.")
      XCTAssertEqual(["User Signup", "Viewed Signup", "Errored User Signup", "Errored Signup"],
                     self.trackingClient.events)

      self.vm.inputs.passwordTextFieldDidReturnObserver.send(value: ())
      self.showError.assertValueCount(1)

      scheduler.advance()
      self.showError.assertValues([error, error], "Signup error.")
      XCTAssertEqual(["User Signup", "Viewed Signup", "Errored User Signup", "Errored Signup",
        "Errored User Signup", "Errored Signup"], self.trackingClient.events)
      // swiftlint:disable:next force_unwrapping
      XCTAssertEqual("Email", trackingClient.properties.last!["auth_type"] as? String)
    }
  }

  func testWeeklyNewsletterChanged() {
    self.vm.inputs.viewDidLoadObserver.send(value: ())
    XCTAssertEqual(["User Signup", "Viewed Signup"], self.trackingClient.events)

    self.vm.inputs.weeklyNewsletterChangedObserver.send(value: true)
    XCTAssertEqual(["User Signup", "Viewed Signup", "Subscribed To Newsletter", "Signup Newsletter Toggle"],
                   self.trackingClient.events)
    XCTAssertEqual([true],
                   self.trackingClient.properties.compactMap { $0["send_newsletters"] as? Bool })

    self.vm.inputs.weeklyNewsletterChangedObserver.send(value: false)
    XCTAssertEqual(
      ["User Signup", "Viewed Signup", "Subscribed To Newsletter", "Signup Newsletter Toggle",
       "Unsubscribed From Newsletter", "Signup Newsletter Toggle"],
      self.trackingClient.events
    )
    XCTAssertEqual([true, false],
                   self.trackingClient.properties.compactMap { $0["send_newsletters"] as? Bool })
  }
}
