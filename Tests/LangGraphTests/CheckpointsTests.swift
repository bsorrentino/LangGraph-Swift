import XCTest
@testable import LangGraph

final class CheckpointsTests: XCTestCase {
    

    func testMemoryCheckpointSaver() async throws {
        
        let saver = MemoryCheckpointSaver()
        
        let config = RunnableConfig()
        
        let checkpoints = saver.list(config: config)
        
        XCTAssertTrue(checkpoints.isEmpty, "Expected empty list")
        
        
        let checkpoint1 = Checkpoint(state: [:], nodeId: "node1", nextNodeId: "node2")
        
        let config1 = try saver.put(config: config, checkpoint: checkpoint1)
        
        let checkpoints2 = saver.list(config: config)
        
        XCTAssertEqual(checkpoints2.count, 1, "Expected one checkpoint")
        XCTAssertEqual(config1.checkpointId, checkpoint1.id, "Expected checkpoint ID to match")
        XCTAssertEqual(config1.threadId, config.threadId, "Expected checkpoint threadId to match")
        XCTAssertEqual(config1.nextNode, config.nextNode, "Expected checkpoint nextNode to match")

    }
}
