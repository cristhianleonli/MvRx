import MvRx
import XCTest
import RxBlocking

final class MvRxTests: XCTestCase {
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
	
	func test_shouldShowBanner() {
		let shouldShow = ViewModel().stateOf {
			$0.shouldShowBanner
		}
		
		let result = try? shouldShow
			.toBlocking()
			.first()
		
		XCTAssertTrue(result ?? false)
	}
	
	func test_shouldNotShowBanner() {
		let model = ViewModel()
		model.increaseCount(by: 10)
		
		let shouldShow = model.stateOf {
			$0.shouldShowBanner
		}
		
		let result = try? shouldShow
			.toBlocking()
			.first()
		
		XCTAssertFalse(result ?? true)
	}

    static var allTests = [
        ("test_elementCount", test_elementCount),
		("test_shouldShowBanner", test_shouldShowBanner),
		("test_shouldNotShowBanner", test_shouldNotShowBanner)
    ]
}

struct TestViewState: Equatable {
	var elementCount: Int
	
	var shouldShowBanner: Bool {
		elementCount == 0
	}
	
	static var `default`: TestViewState {
		TestViewState(elementCount: 0)
	}
}

struct ViewModel: MvRxViewModel {
	let viewState: MvRxViewState<TestViewState>
	
	init() {
		viewState = MvRxViewState(initialState: .default)
	}
	
	func increaseCount(by count: Int) {
		viewState.set { $0.elementCount += 1 }
	}
}
