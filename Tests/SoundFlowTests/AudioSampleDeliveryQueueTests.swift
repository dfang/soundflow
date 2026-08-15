import Foundation
import XCTest
@testable import SoundFlow

final class AudioSampleDeliveryQueueTests: XCTestCase {
    func testStopAndDrainWaitsForAcceptedDelivery() async {
        let deliveryQueue = AudioSampleDeliveryQueue(label: "test.audio-delivery")
        let deliveryStarted = expectation(description: "delivery started")
        let allowDeliveryToFinish = DispatchSemaphore(value: 0)
        let deliveryFinished = ThreadSafeFlag()
        let stopReturned = ThreadSafeFlag()

        let generation = deliveryQueue.start()
        deliveryQueue.enqueue(for: generation) {
            {
                deliveryStarted.fulfill()
                allowDeliveryToFinish.wait()
                deliveryFinished.set()
            }
        }
        await fulfillment(of: [deliveryStarted], timeout: 1.0)

        let stopTask = Task.detached {
            deliveryQueue.stopAndDrain()
            stopReturned.set()
        }
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(stopReturned.value)

        allowDeliveryToFinish.signal()
        await stopTask.value
        XCTAssertTrue(deliveryFinished.value)
        XCTAssertTrue(stopReturned.value)
    }

    func testStoppedQueueDiscardsLateDelivery() {
        let deliveryQueue = AudioSampleDeliveryQueue(label: "test.audio-delivery")
        let delivered = ThreadSafeFlag()

        let generation = deliveryQueue.start()
        deliveryQueue.stopAndDrain()
        let accepted = deliveryQueue.enqueue(for: generation) {
            {
                delivered.set()
            }
        }
        deliveryQueue.stopAndDrain()

        XCTAssertFalse(accepted)
        XCTAssertFalse(delivered.value)
    }

    func testStopWaitsForInFlightPreparationAndNextGenerationRejectsStaleCallback() async {
        let deliveryQueue = AudioSampleDeliveryQueue(label: "test.audio-delivery")
        let preparationStarted = expectation(description: "callback preparation started")
        let stopStarted = expectation(description: "stop started")
        let allowPreparationToFinish = DispatchSemaphore(value: 0)
        let firstDeliveryFinished = ThreadSafeFlag()
        let staleDeliveryFinished = ThreadSafeFlag()
        let nextDeliveryFinished = ThreadSafeFlag()
        let stopReturned = ThreadSafeFlag()
        let firstGeneration = deliveryQueue.start()

        let callbackTask = Task.detached {
            deliveryQueue.enqueue(for: firstGeneration) {
                preparationStarted.fulfill()
                allowPreparationToFinish.wait()
                return {
                    firstDeliveryFinished.set()
                }
            }
        }
        await fulfillment(of: [preparationStarted], timeout: 1.0)

        let stopTask = Task.detached {
            stopStarted.fulfill()
            deliveryQueue.stopAndDrain()
            stopReturned.set()
        }
        await fulfillment(of: [stopStarted], timeout: 1.0)
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(stopReturned.value)

        allowPreparationToFinish.signal()
        let acceptedFirstCallback = await callbackTask.value
        XCTAssertTrue(acceptedFirstCallback)
        await stopTask.value
        XCTAssertTrue(firstDeliveryFinished.value)

        let nextGeneration = deliveryQueue.start()
        let acceptedStaleCallback = deliveryQueue.enqueue(for: firstGeneration) {
            {
                staleDeliveryFinished.set()
            }
        }
        let acceptedNextCallback = deliveryQueue.enqueue(for: nextGeneration) {
            {
                nextDeliveryFinished.set()
            }
        }
        deliveryQueue.stopAndDrain()

        XCTAssertFalse(acceptedStaleCallback)
        XCTAssertFalse(staleDeliveryFinished.value)
        XCTAssertTrue(acceptedNextCallback)
        XCTAssertTrue(nextDeliveryFinished.value)
    }
}

private final class ThreadSafeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    var value: Bool {
        lock.withLock { storage }
    }

    func set() {
        lock.withLock {
            storage = true
        }
    }
}
