import Testing
@testable import Forge

struct ValidationTests {

    @Test func emptyStringReturnsNil() {
        #expect(Validation.trimmedName("") == nil)
    }

    @Test func whitespaceOnlyReturnsNil() {
        #expect(Validation.trimmedName("   ") == nil)
    }

    @Test func normalStringReturnsTrimmed() {
        #expect(Validation.trimmedName("  Bench Press  ") == "Bench Press")
    }

    @Test func stringAtMaxLengthIsUnchanged() {
        let name = String(repeating: "A", count: 50)
        #expect(Validation.trimmedName(name) == name)
    }

    @Test func stringOverMaxLengthIsTruncated() {
        let result = Validation.trimmedName(String(repeating: "A", count: 60))
        #expect(result?.count == 50)
    }

    @Test func singleCharacterIsValid() {
        #expect(Validation.trimmedName("A") == "A")
    }
}
