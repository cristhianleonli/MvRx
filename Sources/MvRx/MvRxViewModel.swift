import RxSwift

public protocol MvRxViewModel {
    associatedtype ViewState: Equatable
    var viewState: MvRxViewState<ViewState> { get }
}

public extension MvRxViewModel {
    func stateOf<T: Equatable>(_ extractor: @escaping (ViewState) -> T) -> Observable<T> {
        return viewState.observable
            .map { extractor($0) }
            .distinctUntilChanged()
            .observeOn(MainScheduler.instance)
    }
    
    func getState<T: Equatable>(whenThisElementChange: @escaping (ViewState) -> T) -> Observable<ViewState> {
        return viewState.observable
            .map { whenThisElementChange($0) }
            .distinctUntilChanged()
            .withLatestFrom(viewState.observable)
            .observeOn(MainScheduler.instance)
    }
}
