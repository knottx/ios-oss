@testable import KsApi
@testable import Library
import Prelude
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import XCTest

internal final class BackerDashboardProjectsViewModelTests: TestCase {
  private let vm: BackerDashboardProjectsViewModelType = BackerDashboardProjectsViewModel()

  private let emptyStateIsVisible = TestObserver<Bool, Never>()
  private let emptyStateProjectsType = TestObserver<ProfileProjectsType, Never>()
  private let isRefreshing = TestObserver<Bool, Never>()
  private let goToProject = TestObserver<Project, Never>()
  private let goToProjectRefTag = TestObserver<RefTag, Never>()
  private let projects = TestObserver<[Project], Never>()
  private let scrollToProjectRow = TestObserver<Int, Never>()

  override func setUp() {
    super.setUp()

    self.vm.outputs.emptyStateIsVisible.map(first).observe(self.emptyStateIsVisible.observer)
    self.vm.outputs.emptyStateIsVisible.map(second).observe(self.emptyStateProjectsType.observer)
    self.vm.outputs.isRefreshing.observe(self.isRefreshing.observer)
    self.vm.outputs.goToProject.map(first).observe(self.goToProject.observer)
    self.vm.outputs.goToProject.map(third).observe(self.goToProjectRefTag.observer)
    self.vm.outputs.projects.observe(self.projects.observer)
    self.vm.outputs.scrollToProjectRow.observe(self.scrollToProjectRow.observer)
  }

  func testProjects() {
    let projects = (1...3).map { .template |> Project.lens.id .~ $0 }
    let projectsWithNewProject = (1...4).map { .template |> Project.lens.id .~ $0 }
    let projectsWithNewestProject = (1...5).map { .template |> Project.lens.id .~ $0 }
    let env = .template |> DiscoveryEnvelope.lens.projects .~ projects
    let env2 = .template |> DiscoveryEnvelope.lens.projects .~ projectsWithNewProject
    let env3 = .template |> DiscoveryEnvelope.lens.projects .~ projectsWithNewestProject

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: env), currentUser: .template) {
      self.vm.inputs.configureWith(projectsType: .backed, sort: .endingSoon)
      self.vm.inputs.viewWillAppear(false)
      self.vm.inputs.currentUserUpdated()

      self.projects.assertValueCount(0)
      self.emptyStateIsVisible.assertValueCount(0)
      self.isRefreshing.assertValues([true])

      XCTAssertEqual([], self.dataLakeTrackingClient.events)
      XCTAssertEqual([], self.dataLakeTrackingClient.properties(forKey: "type", as: String.self))

      XCTAssertEqual([], self.segmentTrackingClient.events)
      XCTAssertEqual([], self.segmentTrackingClient.properties(forKey: "type", as: String.self))

      self.scheduler.advance()

      self.projects.assertValues([projects])
      self.emptyStateIsVisible.assertValues([false])
      self.emptyStateProjectsType.assertValues([.backed])
      self.isRefreshing.assertValues([true, false])

      self.vm.inputs.viewWillAppear(true)
      self.isRefreshing.assertValues([true, false], "Projects don't refresh.")

      self.scheduler.advance()

      self.projects.assertValues([projects])
      self.emptyStateIsVisible.assertValues([false])
      self.isRefreshing.assertValues([true, false], "Projects don't refresh.")

      let updatedUser = User.template |> \.stats.backedProjectsCount .~ 1

      // Come back after backing a project.
      withEnvironment(apiService: MockService(fetchDiscoveryResponse: env2), currentUser: updatedUser) {
        self.vm.inputs.currentUserUpdated()
        self.vm.inputs.viewWillAppear(false)

        self.isRefreshing.assertValues([true, false, true])

        self.scheduler.advance()

        self.projects.assertValues([projects, projectsWithNewProject])
        self.emptyStateIsVisible.assertValues([false, false])
        self.isRefreshing.assertValues([true, false, true, false])
      }

      // Refresh.
      withEnvironment(apiService: MockService(fetchDiscoveryResponse: env3), currentUser: updatedUser) {
        self.vm.inputs.refresh()

        self.isRefreshing.assertValues([true, false, true, false, true])

        self.scheduler.advance()

        self.projects.assertValues([projects, projectsWithNewProject, projectsWithNewestProject])
        self.emptyStateIsVisible.assertValues([false, false, false])
        self.isRefreshing.assertValues([true, false, true, false, true, false])
      }
    }
  }

  func testNoProjects() {
    let env = .template |> DiscoveryEnvelope.lens.projects .~ []

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: env), currentUser: .template) {
      self.vm.inputs.configureWith(projectsType: .saved, sort: .endingSoon)
      self.vm.inputs.viewWillAppear(false)

      self.projects.assertValueCount(0)
      self.emptyStateIsVisible.assertValueCount(0)
      self.isRefreshing.assertValues([true])

      self.scheduler.advance()

      self.projects.assertValues([[]])
      self.emptyStateIsVisible.assertValues([true], "Empty state is shown for user with no projects.")
      self.emptyStateProjectsType.assertValues([.saved])
      self.isRefreshing.assertValues([true, false])

      XCTAssertEqual([], self.dataLakeTrackingClient.events)
      XCTAssertEqual([], self.dataLakeTrackingClient.properties(forKey: "type", as: String.self))

      XCTAssertEqual([], self.segmentTrackingClient.events)
      XCTAssertEqual([], self.segmentTrackingClient.properties(forKey: "type", as: String.self))

      self.vm.inputs.viewWillAppear(true)

      self.scheduler.advance()

      self.projects.assertValues([[]], "Projects does not emit.")
      self.emptyStateIsVisible.assertValues([true], "Empty state does not emit.")
    }
  }

  func testProjectCellTapped() {
    let project = Project.template
    let projects = (1...3).map { .template |> Project.lens.id .~ $0 }
    let env = .template |> DiscoveryEnvelope.lens.projects .~ projects

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: env), currentUser: .template) {
      self.vm.inputs.configureWith(projectsType: .backed, sort: .endingSoon)
      self.vm.inputs.viewWillAppear(false)

      self.scheduler.advance()

      self.vm.inputs.projectTapped(project)

      self.goToProject.assertValues([project], "Project emmitted.")
      self.goToProjectRefTag.assertValues([.profileBacked], "RefTag = profile_backed emitted.")

      XCTAssertEqual(self.dataLakeTrackingClient.events, ["Card Clicked"])
      XCTAssertEqual(self.segmentTrackingClient.events, ["Card Clicked"])

      XCTAssertEqual(
        ["profile"],
        self.dataLakeTrackingClient.properties(forKey: "context_page", as: String.self)
      )
      XCTAssertEqual(
        ["project"],
        self.dataLakeTrackingClient.properties(forKey: "context_type", as: String.self)
      )
      XCTAssertEqual(
        ["backed"],
        self.dataLakeTrackingClient.properties(forKey: "context_section", as: String.self)
      )
      XCTAssertEqual(
        ["account_menu"],
        self.dataLakeTrackingClient.properties(forKey: "context_location", as: String.self)
      )
      XCTAssertEqual(
        ["profile"],
        self.segmentTrackingClient.properties(forKey: "context_page", as: String.self)
      )
      XCTAssertEqual(
        ["project"],
        self.segmentTrackingClient.properties(forKey: "context_type", as: String.self)
      )
      XCTAssertEqual(
        ["backed"],
        self.segmentTrackingClient.properties(forKey: "context_section", as: String.self)
      )
      XCTAssertEqual(
        ["account_menu"],
        self.segmentTrackingClient.properties(forKey: "context_location", as: String.self)
      )
    }
  }

  func testScrollAndUpdateProjects_ViaProjectNavigator() {
    let playlist = (0...10).map { idx in .template |> Project.lens.id .~ (idx + 42) }
    let projectEnv = .template
      |> DiscoveryEnvelope.lens.projects .~ playlist

    let playlist2 = (0...20).map { idx in .template |> Project.lens.id .~ (idx + 72) }
    let projectEnv2 = .template
      |> DiscoveryEnvelope.lens.projects .~ playlist2

    withEnvironment(apiService: MockService(fetchDiscoveryResponse: projectEnv), currentUser: .template) {
      self.vm.inputs.configureWith(projectsType: .backed, sort: .endingSoon)
      self.vm.inputs.viewWillAppear(false)

      self.scheduler.advance()

      self.projects.assertValues([playlist], "Projects are loaded.")

      self.vm.inputs.projectTapped(playlist[4])
      self.vm.inputs.transitionedToProject(at: 5, outOf: playlist.count)

      self.scrollToProjectRow.assertValues([5])

      self.vm.inputs.transitionedToProject(at: 6, outOf: playlist.count)

      self.scrollToProjectRow.assertValues([5, 6])

      self.vm.inputs.transitionedToProject(at: 7, outOf: playlist.count)

      self.scrollToProjectRow.assertValues([5, 6, 7])

      withEnvironment(apiService: MockService(fetchDiscoveryResponse: projectEnv2)) {
        self.vm.inputs.transitionedToProject(at: 8, outOf: playlist.count)

        self.scheduler.advance()

        self.scrollToProjectRow.assertValues([5, 6, 7, 8])
        self.projects.assertValues([playlist, playlist + playlist2], "More projects are loaded.")

        self.vm.inputs.transitionedToProject(at: 7, outOf: playlist2.count)

        self.scrollToProjectRow.assertValues([5, 6, 7, 8, 7])
      }
    }
  }
}
