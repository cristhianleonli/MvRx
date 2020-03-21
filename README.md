# MvRx

A description of this package.

```swift
func test_elementCount() {
	let model = ViewModel()
	model.increaseCount(by: 1)

	let count = model.stateOf {
		$0.elementCount
	}

	let result = try? count
		.toBlocking()
		.first()

	XCTAssertEqual(result, 1)
}
```
