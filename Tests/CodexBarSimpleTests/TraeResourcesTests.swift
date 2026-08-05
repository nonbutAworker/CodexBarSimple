import Testing

@testable import CodexBarSimple

struct TraeResourcesTests {
    @Test
    func `JetBrains Mono fonts are bundled`() {
        #expect(
            TraeResources.url(
                forResource: "JetBrainsMono-SemiBold",
                withExtension: "ttf",
                subdirectory: "Fonts") != nil)
    }
}
