@testable import KsApi
@testable import Library
import Prelude
import ReactiveExtensions
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import UIKit
import XCTest

final class ThanksViewModelTests: TestCase {
  let vm: ThanksViewModelType = ThanksViewModel()

  private let backedProjectText = TestObserver<String, Never>()
  private let dismissToRootViewControllerAndPostNotification = TestObserver<Notification.Name, Never>()
  private let goToDiscovery = TestObserver<KsApi.Category, Never>()
  private let goToProject = TestObserver<Project, Never>()
  private let goToProjects = TestObserver<[Project], Never>()
  private let goToRefTag = TestObserver<RefTag, Never>()
  private let showRatingAlert = TestObserver<(), Never>()
  private let showGamesNewsletterAlert = TestObserver<(), Never>()
  private let showGamesNewsletterOptInAlert = TestObserver<String, Never>()
  private let showRecommendationsProjects = TestObserver<[Project], Never>()
  private let showRecommendationsVariant = TestObserver<OptimizelyExperiment.Variant, Never>()
  private let postContextualNotification = TestObserver<(), Never>()
  private let postUserUpdatedNotification = TestObserver<Notification.Name, Never>()
  private let updateUserInEnvironment = TestObserver<User, Never>()
  private let facebookButtonIsHidden = TestObserver<Bool, Never>()
  private let twitterButtonIsHidden = TestObserver<Bool, Never>()

  override func setUp() {
    super.setUp()
    self.vm.outputs.backedProjectText.map { $0.string }.observe(self.backedProjectText.observer)
    self.vm.outputs.dismissToRootViewControllerAndPostNotification.map { $0.name }
      .observe(self.dismissToRootViewControllerAndPostNotification.observer)
    self.vm.outputs.goToDiscovery.map { params in params.category ?? Category.filmAndVideo }
      .observe(self.goToDiscovery.observer)
    self.vm.outputs.goToProject.map { $0.0 }.observe(self.goToProject.observer)
    self.vm.outputs.goToProject.map { $0.1 }.observe(self.goToProjects.observer)
    self.vm.outputs.goToProject.map { $0.2 }.observe(self.goToRefTag.observer)
    self.vm.outputs.postContextualNotification.observe(self.postContextualNotification.observer)
    self.vm.outputs.postUserUpdatedNotification.map { $0.name }
      .observe(self.postUserUpdatedNotification.observer)
    self.vm.outputs.showGamesNewsletterAlert.observe(self.showGamesNewsletterAlert.observer)
    self.vm.outputs.showGamesNewsletterOptInAlert.observe(self.showGamesNewsletterOptInAlert.observer)
    self.vm.outputs.showRatingAlert.observe(self.showRatingAlert.observer)
    self.vm.outputs.showRecommendations.map(first)
      .observe(self.showRecommendationsProjects.observer)
    self.vm.outputs.showRecommendations.map(third).observe(self.showRecommendationsVariant.observer)
    self.vm.outputs.updateUserInEnvironment.observe(self.updateUserInEnvironment.observer)
  }

  func testDismissToRootViewController() {
    self.vm.inputs.configure(with: (Project.template, Reward.template, nil))
    self.vm.inputs.viewDidLoad()

    self.vm.inputs.closeButtonTapped()

    self.dismissToRootViewControllerAndPostNotification.assertValue(Notification.Name.ksr_projectBacked)
  }

  func testGoToDiscovery() {
    let projects = [
      .template |> Project.lens.id .~ 1,
      .template |> Project.lens.id .~ 2,
      .template |> Project.lens.id .~ 3
    ]

    let project = Project.template
    let response = .template |> DiscoveryEnvelope.lens.projects .~ projects

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: response)) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      scheduler.advance()

      showRecommendationsProjects.assertValueCount(1)

      vm.inputs.categoryCellTapped(.illustration)

      goToDiscovery.assertValues([.illustration])
      XCTAssertEqual(
        ["Page Viewed"],
        self.dataLakeTrackingClient.events
      )
      XCTAssertEqual(
        ["Page Viewed"],
        self.segmentTrackingClient.events
      )
      XCTAssertEqual(
        ["new_pledge"],
        self.dataLakeTrackingClient.properties(forKey: "context_type")
      )
      XCTAssertEqual(
        ["new_pledge"],
        self.segmentTrackingClient.properties(forKey: "context_type")
      )
    }
  }

  func testDisplayBackedProjectText() {
    let project = Project.template |> \.category .~ .games
    self.vm.inputs.configure(with: (project, Reward.template, nil))
    self.vm.inputs.viewDidLoad()

    self.backedProjectText.assertValues(
      [
        "You have successfully backed The Project. " +
          "This project is now one step closer to a reality, thanks to you. Spread the word!"
      ], "Name of project emits"
    )
  }

  func testRatingAlert_Initial() {
    withEnvironment(currentUser: .template) {
      showRatingAlert.assertValueCount(0, "Rating Alert does not emit")

      self.vm.inputs.configure(with: (Project.template, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      showRatingAlert.assertValueCount(1, "Rating Alert emits when view did load")
      showGamesNewsletterAlert.assertValueCount(0, "Games alert does not emit")
      XCTAssertEqual(
        ["Page Viewed"],
        self.dataLakeTrackingClient.events
      )
      XCTAssertEqual(
        ["Page Viewed"],
        self.segmentTrackingClient.events
      )
    }
  }

  func testGamesAlert_ShowsOnce() {
    withEnvironment(currentUser: .template) {
      XCTAssertEqual(
        false, AppEnvironment.current.userDefaults.hasSeenGamesNewsletterPrompt,
        "Newsletter pref is not set"
      )

      let project = Project.template |> Project.lens.category .~ .games
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      showRatingAlert.assertValueCount(0, "Rating alert does not show on games project")
      showGamesNewsletterAlert.assertValueCount(1, "Games alert shows on games project")
      XCTAssertEqual(
        true, AppEnvironment.current.userDefaults.hasSeenGamesNewsletterPrompt,
        "Newsletter pref saved"
      )

      let secondVM: ThanksViewModelType = ThanksViewModel()
      let secondShowRatingAlert = TestObserver<(), Never>()
      secondVM.outputs.showRatingAlert.observe(secondShowRatingAlert.observer)
      let secondShowGamesNewsletterAlert = TestObserver<(), Never>()
      secondVM.outputs.showGamesNewsletterAlert.observe(secondShowGamesNewsletterAlert.observer)

      secondVM.inputs.configure(with: (project, Reward.template, nil))
      secondVM.inputs.viewDidLoad()

      secondShowRatingAlert.assertValueCount(1, "Rating alert shows on games project")
      secondShowGamesNewsletterAlert.assertValueCount(0, "Games alert does not show again on games project")
    }
  }

  func testGamesNewsletterAlert_ShouldNotShow_WhenUserIsSubscribed() {
    let newsletters = User.NewsletterSubscriptions.template |> User.NewsletterSubscriptions.lens.games .~ true
    let user = User.template |> \.newsletters .~ newsletters
    let project = Project.template |> Project.lens.category .~ .games

    withEnvironment(currentUser: user) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      showGamesNewsletterAlert.assertValueCount(0, "Games alert does not show on games project")
    }
  }

  func testGamesNewsletterSignup() {
    let project = Project.template |> Project.lens.category .~ .games

    withEnvironment(currentUser: .template) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      showGamesNewsletterAlert.assertValueCount(1)

      vm.inputs.gamesNewsletterSignupButtonTapped()

      scheduler.advance()

      updateUserInEnvironment.assertValueCount(1)
      showGamesNewsletterOptInAlert.assertValueCount(0, "Opt-in alert does not emit")
      XCTAssertEqual(
        ["Page Viewed"],
        self.dataLakeTrackingClient.events
      )
      XCTAssertEqual(
        ["Page Viewed"],
        self.segmentTrackingClient.events
      )

      vm.inputs.userUpdated()

      postUserUpdatedNotification.assertValues(
        [Notification.Name.ksr_userUpdated],
        "User updated notification emits"
      )
    }
  }

  func testContextualNotificationEmitsWhen_userPledgedFirstProject() {
    let user = User.template |> \.stats.backedProjectsCount .~ 0

    withEnvironment(currentUser: user) {
      vm.inputs.viewDidLoad()
      postContextualNotification.assertDidEmitValue()
    }
  }

  func testContextualNotificationDoesNotEmitWhen_userPledgedMoreThanOneProject() {
    let user = User.template |> \.stats.backedProjectsCount .~ 2

    withEnvironment(currentUser: user) {
      vm.inputs.viewDidLoad()
      postContextualNotification.assertDidNotEmitValue()
    }
  }

  func testGamesNewsletterOptInAlert() {
    let project = Project.template |> Project.lens.category .~ .games

    withEnvironment(countryCode: "DE", currentUser: User.template) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      showGamesNewsletterAlert.assertValueCount(1)

      vm.inputs.gamesNewsletterSignupButtonTapped()

      showGamesNewsletterOptInAlert.assertValues(["Kickstarter Loves Games"], "Opt-in alert emits with title")
      XCTAssertEqual(
        ["Page Viewed"],
        self.dataLakeTrackingClient.events
      )
      XCTAssertEqual(
        ["Page Viewed"],
        self.segmentTrackingClient.events
      )
    }
  }

  func testGoToProject() {
    let projects = [
      .template |> Project.lens.id .~ 1,
      .template |> Project.lens.id .~ 2,
      .template |> Project.lens.id .~ 3
    ]

    let project = Project.template
    let response = .template |> DiscoveryEnvelope.lens.projects .~ projects
    let mockOptimizelyClient = MockOptimizelyClient()

    withEnvironment(
      apiService: MockService(fetchDiscoveryResponse: response),
      optimizelyClient: mockOptimizelyClient
    ) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      scheduler.advance()

      showRecommendationsProjects.assertValueCount(1)

      vm.inputs.projectTapped(project)

      goToProject.assertValues([project])
      goToProjects.assertValueCount(1)
      goToRefTag.assertValues([.thanks])
      XCTAssertEqual(
        [
          "Page Viewed",
          "Card Clicked"
        ],
        self.dataLakeTrackingClient.events
      )
      XCTAssertEqual(
        [
          "Page Viewed",
          "Card Clicked"
        ],
        self.segmentTrackingClient.events
      )
      XCTAssertEqual("Project Card Clicked", mockOptimizelyClient.trackedEventKey)
    }
  }

  func testRecommendationsWithProjects() {
    let projects = [
      .template |> Project.lens.id .~ 1,
      .template |> Project.lens.id .~ 2,
      .template |> Project.lens.id .~ 1,
      .template |> Project.lens.id .~ 2,
      .template |> Project.lens.id .~ 5,
      .template |> Project.lens.id .~ 8
    ]

    let response = .template |> DiscoveryEnvelope.lens.projects .~ projects
    let project = Project.template |> Project.lens.id .~ 12

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: response)) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      scheduler.advance()

      self.showRecommendationsProjects.assertValueCount(1, "Recommended projects emit, shuffled.")
      self.showRecommendationsVariant.assertValues([.control])
    }
  }

  func testRecommendationsWithoutProjects() {
    let response = .template |> DiscoveryEnvelope.lens.projects .~ []
    let project = Project.template |> Project.lens.category .~ .games

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: response)) {
      self.vm.inputs.configure(with: (project, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      scheduler.advance()

      self.showRecommendationsProjects.assertValueCount(0, "Recommended projects did not emit")
      self.showRecommendationsVariant.assertDidNotEmitValue()
    }
  }

  func testRecommendationsProjects_ExperimentalVariant() {
    let recommendedProject = Project.template
      |> \.id .~ 3
    let response = .template |> DiscoveryEnvelope.lens.projects .~ [recommendedProject]
    let mockOptimizelyClient = MockOptimizelyClient()
      |> \.experiments .~ [
        OptimizelyExperiment.Key.nativeProjectCards.rawValue: OptimizelyExperiment.Variant.variant1.rawValue
      ]

    withEnvironment(
      apiService: MockService(fetchDiscoveryResponse: response),
      optimizelyClient: mockOptimizelyClient
    ) {
      self.vm.inputs.configure(with: (Project.template, Reward.template, nil))
      self.vm.inputs.viewDidLoad()

      scheduler.advance()

      self.showRecommendationsProjects.assertValues([[recommendedProject]])
      self.showRecommendationsVariant.assertValues([.variant1])
    }
  }

  func testThanksPageViewed_Properties() {
    let checkoutData = KSRAnalytics.CheckoutPropertiesData(
      addOnsCountTotal: 2,
      addOnsCountUnique: 1,
      addOnsMinimumUsd: "8.00",
      amount: "43.00",
      bonusAmount: "10.00",
      bonusAmountInUsd: "10.00",
      checkoutId: 1,
      estimatedDelivery: 12_345_678,
      paymentType: "CREDIT_CARD",
      revenueInUsd: 20.00,
      rewardId: 2,
      rewardMinimumUsd: "5.00",
      rewardTitle: "SUPER reward",
      shippingEnabled: true,
      shippingAmount: 10,
      shippingAmountUsd: "10.00",
      userHasStoredApplePayCard: true
    )

    self.vm.inputs.configure(with: (Project.template, Reward.template, checkoutData))
    self.vm.inputs.viewDidLoad()

    let dataLakeTrackingClientProps = self.dataLakeTrackingClient.properties.last
    let segmentClientProps = self.segmentTrackingClient.properties.last

    XCTAssertEqual(
      ["Page Viewed"],
      self.dataLakeTrackingClient.events
    )
    XCTAssertEqual(
      ["Page Viewed"],
      self.segmentTrackingClient.events
    )

    // Checkout properties
    XCTAssertEqual(2, dataLakeTrackingClientProps?["checkout_add_ons_count_total"] as? Int)
    XCTAssertEqual(1, dataLakeTrackingClientProps?["checkout_add_ons_count_unique"] as? Int)
    XCTAssertEqual("8.00", dataLakeTrackingClientProps?["checkout_add_ons_minimum_usd"] as? String)
    XCTAssertEqual("43.00", dataLakeTrackingClientProps?["checkout_amount"] as? String)
    XCTAssertEqual("10.00", dataLakeTrackingClientProps?["checkout_bonus_amount"] as? String)
    XCTAssertEqual("10.00", dataLakeTrackingClientProps?["checkout_bonus_amount_usd"] as? String)
    XCTAssertEqual("CREDIT_CARD", dataLakeTrackingClientProps?["checkout_payment_type"] as? String)
    XCTAssertEqual("SUPER reward", dataLakeTrackingClientProps?["checkout_reward_title"] as? String)
    XCTAssertEqual("5.00", dataLakeTrackingClientProps?["checkout_reward_minimum_usd"] as? String)
    XCTAssertEqual(2, dataLakeTrackingClientProps?["checkout_reward_id"] as? Int)
    XCTAssertEqual(20.00, dataLakeTrackingClientProps?["checkout_amount_total_usd"] as? Double)
    XCTAssertEqual(true, dataLakeTrackingClientProps?["checkout_reward_is_limited_quantity"] as? Bool)
    XCTAssertEqual(true, dataLakeTrackingClientProps?["checkout_reward_shipping_enabled"] as? Bool)
    XCTAssertEqual(
      true,
      dataLakeTrackingClientProps?["checkout_user_has_eligible_stored_apple_pay_card"] as? Bool
    )
    XCTAssertEqual(10.00, dataLakeTrackingClientProps?["checkout_shipping_amount"] as? Double)
    XCTAssertEqual("10.00", dataLakeTrackingClientProps?["checkout_shipping_amount_usd"] as? String)
    XCTAssertEqual(
      12_345_678,
      dataLakeTrackingClientProps?["checkout_reward_estimated_delivery_on"] as? TimeInterval
    )

    XCTAssertEqual(2, segmentClientProps?["checkout_add_ons_count_total"] as? Int)
    XCTAssertEqual(1, segmentClientProps?["checkout_add_ons_count_unique"] as? Int)
    XCTAssertEqual("8.00", segmentClientProps?["checkout_add_ons_minimum_usd"] as? String)
    XCTAssertEqual("43.00", segmentClientProps?["checkout_amount"] as? String)
    XCTAssertEqual("10.00", segmentClientProps?["checkout_bonus_amount"] as? String)
    XCTAssertEqual("10.00", segmentClientProps?["checkout_bonus_amount_usd"] as? String)
    XCTAssertEqual("CREDIT_CARD", segmentClientProps?["checkout_payment_type"] as? String)
    XCTAssertEqual("SUPER reward", segmentClientProps?["checkout_reward_title"] as? String)
    XCTAssertEqual("5.00", segmentClientProps?["checkout_reward_minimum_usd"] as? String)
    XCTAssertEqual(2, segmentClientProps?["checkout_reward_id"] as? Int)
    XCTAssertEqual(20.00, segmentClientProps?["checkout_amount_total_usd"] as? Double)
    XCTAssertEqual(true, segmentClientProps?["checkout_reward_is_limited_quantity"] as? Bool)
    XCTAssertEqual(true, segmentClientProps?["checkout_reward_shipping_enabled"] as? Bool)
    XCTAssertEqual(true, segmentClientProps?["checkout_user_has_eligible_stored_apple_pay_card"] as? Bool)
    XCTAssertEqual(10.00, segmentClientProps?["checkout_shipping_amount"] as? Double)
    XCTAssertEqual("10.00", segmentClientProps?["checkout_shipping_amount_usd"] as? String)
    XCTAssertEqual(12_345_678, segmentClientProps?["checkout_reward_estimated_delivery_on"] as? TimeInterval)

    // Pledge properties
    XCTAssertEqual(true, dataLakeTrackingClientProps?["pledge_backer_reward_has_items"] as? Bool)
    XCTAssertEqual(1, dataLakeTrackingClientProps?["pledge_backer_reward_id"] as? Int)
    XCTAssertEqual(10.00, dataLakeTrackingClientProps?["pledge_backer_reward_minimum"] as? Double)

    XCTAssertEqual(true, segmentClientProps?["pledge_backer_reward_has_items"] as? Bool)
    XCTAssertEqual(1, segmentClientProps?["pledge_backer_reward_id"] as? Int)
    XCTAssertEqual(10.00, segmentClientProps?["pledge_backer_reward_minimum"] as? Double)

    // Project properties
    XCTAssertEqual(1, dataLakeTrackingClientProps?["project_pid"] as? Int)

    XCTAssertEqual(1, segmentClientProps?["project_pid"] as? Int)
  }
}
