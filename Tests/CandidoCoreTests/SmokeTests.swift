import Testing

@testable import CandidoCore

@Test
func packageBuildsAndTestsRun() {
    #expect(CandidoCore.specVersion == 1)
}
