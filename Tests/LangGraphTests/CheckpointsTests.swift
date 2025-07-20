import Testing
import XCTest
@testable import LangGraph

final class CheckpointsTests: XCTestCase {}

@Test
func testMemoryCheckpointSaver() async throws {
    
    let saver = MemoryCheckpointSaver()
    
    let config = RunnableConfig()
    
    let checkpoints = saver.list(config: config)
    
    #expect(checkpoints.isEmpty, "Expected empty list")
    
    let checkpoint1 = Checkpoint(state: [:], nodeId: "node1", nextNodeId: "node2")
    
    let config1 = try saver.put(config: config, checkpoint: checkpoint1)
    
    let checkpoints2 = saver.list(config: config)
    
    #expect(checkpoints2.count==1, "Expected one checkpoint")
    #expect(config1.checkpointId == checkpoint1.id, "Expected checkpoint ID to match")
    #expect(config1.threadId == config.threadId, "Expected checkpoint threadId to match")
    #expect(config1.nextNodeId == config.nextNodeId, "Expected checkpoint nextNode to match")
    
    let checkpoint2 = saver.get(config: config1)
    
    #expect( checkpoint2 != nil, "Expected non-null checkpoint")
    #expect( checkpoint2! == checkpoint1, "Expected checkpoint to match")
    
    let checkpoint3 = try checkpoint2!.updateState(values: ["prop2": "value2"], channels: [:])

    #expect( checkpoint2!.state.isEmpty, "Expected empty checkpoint state")
    #expect( checkpoint3.state["prop2"] as? String == "value2", "Expected checkpoint state to match")
    
    let encoder = JSONEncoder()
    
    let data = try encoder.encode(checkpoint3)
    
    let decoder = JSONDecoder()
    
    let checkpoint4 = try decoder.decode(Checkpoint.self, from: data)
    
    #expect( checkpoint4 == checkpoint3, "Expected checkpoint to match")
    
}
