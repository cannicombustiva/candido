import Testing

@testable import JobTrackerCore

@Test
func packageBuildsAndTestsRun() {
    #expect(JobTrackerCore.specVersion == 1)
}
