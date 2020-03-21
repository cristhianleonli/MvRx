import RxSwift
import RxCocoa
import Foundation

public class MvRxViewState<S: Equatable> {
    public typealias StateReducer = (inout S) -> Void
    public typealias StateBlock = (S) -> Void
    
    /**
     * The subject is where state changes should be pushed to.
     */
    private let subject: BehaviorSubject<S>
    private let disposeBag = DisposeBag()
    
    /**
     * A subject that is used to flush the setState and getState queue. The value emitted on the subject is
     * not used. It is only used as a signal to flush the queues.
     */
    private let flushQueueSubject = BehaviorSubject<Void>(value: ())
    
    private let jobs = Jobs<S>()
    
    public let observable: Observable<S>
    
    /**
     * This is automatically updated from a subscription on the subject for easy access to the
     * current state.
     */
    private var state: S {
        // value must be present here, since the subject is created with initialState
        return try! subject.value()
    }
    
    public init(initialState: S) {
        self.subject = BehaviorSubject(value: initialState)
        self.observable = self.subject.distinctUntilChanged()
        
        let scheduler = MainScheduler.instance
        flushQueueSubject.observeOn(scheduler)
            // We don't want race conditions with setting the state on multiple background threads
            // simultaneously in which two state reducers get the same initial state to reduce.
            .bind { [unowned self] _ in
                self.flushQueues()
            }
            // Ensure that state updates don't get processes after dispose.
            .disposed(by: disposeBag)
    }
    
    /**
     * Get the current state. The block of code is posted to a queue and all pending setState blocks
     * are guaranteed to run before the get block is run.
     */
    public func get(_ block: @escaping StateBlock) {
        jobs.enqueueGetStateBlock(block)
        flushQueueSubject.onNext(())
    }
    
    /**
     * Call this to update the state. The state reducer will get added to a queue that is processes
     * on a background thread. The state reducer's receiver type is the current state when the
     * reducer is called.
     *
     * An example of a reducer would be `{ copy(myProperty = 5) }`. The copy comes from the copy
     * function on a Kotlin data class and can be called directly because state is the receiver type
     * of the reducer. In this case, it will also implicitly return the only expression so that is
     * all of the code required.
     */
    public func set(_ stateReducer: @escaping StateReducer) {
        jobs.enqueueSetStateBlock(stateReducer)
        flushQueueSubject.onNext(())
    }
    
    /**
     * Flushes the setState and getState queues.
     *
     * This will flush he setState queue then call the first element on the getState queue.
     *
     * In case the setState queue calls setState, we call flushQueues recursively to flush the setState queue
     * in between every getState block gets processed.
     */
    private func flushQueues() {
        flushSetStateQueue()
        guard let block = jobs.dequeueGetStateBlock() else {
            return
        }
        block(state)
        flushQueues()
    }
    
    /**
     * Coalesce all updates on the setState queue and clear the queue.
     */
    private func flushSetStateQueue() {
        guard let blocks = jobs.dequeueAllSetStateBlocks() else {
            return
        }
        
        let newState = blocks.reduce(state, { (state, reducer) -> S in
            var newState = state
            reducer(&newState)
            return newState
        })
        subject.onNext(newState)
    }
    
    private class Jobs<S> {
        private let queue = DispatchQueue(label: "mvrx.jobs")
        
        private var getStateQueue: [StateBlock] = []
        private var setStateQueue: [StateReducer] = []
        
        func enqueueGetStateBlock(_ block: @escaping StateBlock) {
            queue.sync {
                getStateQueue.append(block)
            }
        }
        
        func enqueueSetStateBlock(_ block: @escaping StateReducer) {
            queue.sync {
                setStateQueue.append(block)
            }
        }
        
        func dequeueGetStateBlock() -> StateBlock? {
            return queue.sync {
                if getStateQueue.isEmpty {
                    return nil
                }
                return getStateQueue.removeFirst()
            }
        }
        
        func dequeueAllSetStateBlocks() -> [StateReducer]? {
            return queue.sync {
                // do not allocate empty queue for no-op flushes
                if setStateQueue.isEmpty {
                    return nil
                }
                let queue = setStateQueue
                setStateQueue = []
                return queue
            }
        }
    }
}
