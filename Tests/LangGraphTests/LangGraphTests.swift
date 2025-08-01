import XCTest
@testable import LangGraph
import Testing



func compareAsEquatable(_ value: Any, _ expectedValue: Any) -> Bool {
    if let value1 = value as? Int, let value2 = expectedValue as? Int {
        return value1 == value2
    }
    if let value1 = value as? String, let value2 = expectedValue as? String {
        return value1 == value2
    }
    if let values2 = expectedValue as? [Any] {
        if let values1 = value as? [Any] {
            if values1.count == values2.count {
                for ( v1, v2) in zip(values1, values2) {
                    return compareAsEquatable( v1, v2 )
                }
            }
        }
    }
    return false
}

func assertDictionaryOfAnyEqual( _ expected: [String:Any], _ current: [String:Any] ) {
    XCTAssertEqual(expected.count, current.count, "the dictionaries have different size")
    for (key, value) in current {
        XCTAssertTrue( compareAsEquatable(value, expected[key]!) )
        
    }
    
}

func dictionaryOfAnyEqual( _ expected: [String:Any], _ current: [String:Any] ) -> Bool {
    if( expected.count != current.count ) {
        return false // "the dictionaries have different size"
    }
    for (key, value) in current {
        if( !compareAsEquatable(value, expected[key]!) ) {
            return false // "values for \(key) do not match"
        }
    }
    return true
}



struct BinaryOpState : AgentState {
    var data: [String : Any]
    
    init() {
        data = ["add1": 0, "add2": 0 ]
    }
    
    init(_ initState: [String : Any]) {
        data = initState
    }
    var op:String? {
        data["op"] as? String
    }

    var add1:Int? {
        data["add1"] as? Int
    }
    var add2:Int? {
        data["add2"] as? Int
    }
}


// XCTest Documentation
// https://developer.apple.com/documentation/xctest

// Defining Test Cases and Test Methods
// https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
final class LangGraphTests: XCTestCase {
    

    }
    func testValidation() async throws {
            
        let workflow = StateGraph { BaseAgentState($0) }
        
        XCTAssertThrowsError( try workflow.compile() ) {error in 
            print( error )
            XCTAssertTrue(error is StateGraphError, "\(error) is not a GraphStateError")
        }
        
        try workflow.addEdge(sourceId: START, targetId: "agent_1")

        XCTAssertThrowsError( try workflow.compile() ) {error in
            print( error )
            XCTAssertTrue(error is StateGraphError, "\(error) is not a GraphStateError")
        }
        
        try workflow.addNode("agent_1") { state in
            
            print( "agent_1", state )
            return ["prop1": "test"]
        }
        
        XCTAssertNotNil(try workflow.compile())
        
        try workflow.addEdge(sourceId: "agent_1", targetId: END)
        
        XCTAssertNotNil(try workflow.compile())
        
        XCTAssertThrowsError( try workflow.addEdge(sourceId: END, targetId: "agent_1") ) {error in
            print( error )
            XCTAssertTrue(error is StateGraphError, "\(error) is not a GraphStateError")
        }
        
        XCTAssertThrowsError(try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")) { error in
            
            XCTAssertTrue(error is StateGraphError, "\(error) is not a GraphStateError")
            if case StateGraphError.duplicateEdgeError(let msg) = error {
                print( "EXCEPTION:", msg )
            }
            else {
                XCTFail( "exception is not expected 'duplicateEdgeError'")
            }
            
        }

        try workflow.addNode("agent_2") { state in
            
            print( "agent_2", state )
            return ["prop2": "test"]
        }
        
        try workflow.addEdge(sourceId: "agent_2", targetId: "agent_3")

        XCTAssertThrowsError( try workflow.compile() ) {error in
            XCTAssertTrue(error is StateGraphError, "\(error) is not a GraphStateError")
            if case StateGraphError.missingNodeReferencedByEdge(let msg) = error {
               print( "EXCEPTION:", msg )
            }
            else {
                XCTFail( "exception is not expected 'duplicateEdgeError'")
            }

        }
        
        XCTAssertThrowsError(
            try workflow.addConditionalEdge(sourceId: "agent_1", condition:{ _ in return "agent_3"}, edgeMapping: [:])
        ) { error in
            
            XCTAssertTrue(error is StateGraphError, "\(error) is not a GraphStateError")
            if case StateGraphError.edgeMappingIsEmpty = error {
               print( "EXCEPTION:", error  )
            }
            else {
                XCTFail( "exception is not expected 'duplicateEdgeError'")
            }

        }
        
    }

    func testRunningOneNode() async throws {
            
        let workflow = StateGraph { BaseAgentState($0) }
        try workflow.addEdge( sourceId: START, targetId: "agent_1")
        try workflow.addNode("agent_1") { state in
            
            print( "agent_1", state )
            return ["prop1": "test"]
        }
        
        try workflow.addEdge(sourceId: "agent_1", targetId: END)
        
        let app = try workflow.compile()
        
        let result = try await app.invoke( .args([ "input": "test1"]) )
        
        let expected = ["prop1": "test", "input": "test1"]
        assertDictionaryOfAnyEqual( expected, result.data )
        
    }


    func testRunningTreeNodes() async throws {
            
        let workflow = StateGraph { BinaryOpState($0) }
        
        try workflow.addNode("agent_1") { state in
            
            print( "agent_1", state )
            return ["add1": 37]
        }
        try workflow.addNode("agent_2") { state in
            
            print( "agent_2", state )
            return ["add2": 10]
        }
        try workflow.addNode("sum") { state in
            
            print( "sum", state )
            guard let add1 = state.add1, let add2 = state.add2 else {
                throw CompiledGraphError.executionError("agent state is not valid! expect 'add1', 'add2'")
            }
            
            return ["result": add1 + add2 ]
        }

        try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")
        try workflow.addEdge(sourceId: "agent_2", targetId: "sum")

        try workflow.addEdge( sourceId: START, targetId: "agent_1")
        try workflow.addEdge(sourceId: "sum", targetId: END )

        let app = try workflow.compile()
        
        let result = try await app.invoke( .args([ : ]) )
        
        assertDictionaryOfAnyEqual( ["add1": 37, "add2": 10, "result":  47 ], result.data )

    }

    func testRunningFourNodesWithCondition() async throws {
            
        let workflow = StateGraph { BinaryOpState($0) }
        
        try workflow.addNode("agent_1") { state in
            
            print( "agent_1", state )
            return ["add1": 37]
        }
        try workflow.addNode("agent_2") { state in
            
            print( "agent_2", state )
            return ["add2": 10]
        }
        try workflow.addNode("sum") { state in
            
            print( "sum", state )
            guard let add1 = state.add1, let add2 = state.add2 else {
                throw CompiledGraphError.executionError("agent state is not valid! expect 'add1', 'add2'")
            }
            
            return ["result": add1 + add2 ]
        }
        try workflow.addNode("mul") { state in
            
            print( "mul", state )
            guard let add1 = state.add1, let add2 = state.add2 else {
                throw CompiledGraphError.executionError("agent state is not valid! expect 'add1', 'add2'")
            }
            
            return ["result": add1 * add2 ]
        }

        let choiceOp:EdgeCondition<BinaryOpState> = { state in
            
            guard let op = state.op else {
                return "noop"
            }
            
            switch( op ) {
            case "sum":
                return "sum"
            case "mul":
                return "mul"
            default:
                return "noop"
            }
        }
        
        try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")
        try workflow.addConditionalEdge(sourceId: "agent_2",
                                        condition: choiceOp,
                                        edgeMapping: ["sum":"sum", "mul":"mul", "noop": END] )
        try workflow.addEdge(sourceId: "sum", targetId: END)
        try workflow.addEdge(sourceId: "mul", targetId: END)
        
        try workflow.addEdge(sourceId: START, targetId: "agent_1")

        let app = try workflow.compile()
        
        let resultMul = try await app.invoke( .args([ "op": "mul" ]) )
        
        assertDictionaryOfAnyEqual(["op": "mul", "add1": 37, "add2": 10, "result": 370 ], resultMul.data)
        
        let resultAdd = try await app.invoke( .args([ "op": "sum" ]) )
        
        assertDictionaryOfAnyEqual(["op": "sum", "add1": 37, "add2": 10, "result": 47 ], resultAdd.data)
    }

    struct AgentStateWithAppender : AgentState {
        
        static var schema: Channels = {
            ["messages": AppenderChannel<String>( default: { [] })]
        }()
        
        var data: [String : Any]
        
        init(_ initState: [String : Any]) {
            data = initState
        }
        var messages:[String]? {
            value("messages")
        }
    }

    func testAppender() async throws {
        
        let workflow = StateGraph( channels: AgentStateWithAppender.schema ) { AgentStateWithAppender($0) }
        
        try workflow.addNode("agent_1") { state in
            
            print( "agent_1", state )
            return ["messages": "message1"]
        }
        try workflow.addNode("agent_2") { state in
            
            print( "agent_2", state )
            return ["messages": ["message2", "message3"] ]
        }
        try workflow.addNode("agent_3") { state in
            print( "agent_3", state )
            return ["result": state.messages?.count ?? 0]
        }

        try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")
        try workflow.addEdge(sourceId: "agent_2", targetId: "agent_3")

        try workflow.addEdge(sourceId: START, targetId: "agent_1")
        try workflow.addEdge(sourceId: "agent_3", targetId: END)

        let app = try workflow.compile()
        
        let result = try await app.invoke( .args([ : ]) )
        
        print( result.data )
        assertDictionaryOfAnyEqual( ["messages": [ "message1", "message2", "message3"], "result":  3 ], result.data )

    }

    func testWithStream() async throws {
            
        let workflow = StateGraph( channels: AgentStateWithAppender.schema ) { AgentStateWithAppender( $0 ) }
        
        try workflow.addNode("agent_1") { state in
            ["messages": "message1"]
        }
        try workflow.addNode("agent_2") { state in
            ["messages": ["message2", "message3"] ]
        }
        try workflow.addNode("agent_3") { state in
            ["result": state.messages?.count ?? 0]
        }

        try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")
        try workflow.addEdge(sourceId: "agent_2", targetId: "agent_3")

        try workflow.addEdge(sourceId: START, targetId: "agent_1")
        try workflow.addEdge(sourceId: "agent_3", targetId: END)

        let app = try workflow.compile()
                
        let nodesInvolved =
            try await app.stream(.args([ : ]) ).reduce([] as [String]) { partialResult, output in
                                    
                    print( "-------------")
                    print( "Agent Output of \(output.node)" )
                    print( output.state )
                    print( "-------------")

                    return partialResult + [output.node ]
            }
        
        XCTAssertEqual( ["agent_1", "agent_2", "agent_3"], nodesInvolved)
    }

    func testWithStreamAnCancellation() async throws {
            
        let workflow = StateGraph( channels: AgentStateWithAppender.schema ) { AgentStateWithAppender($0) }
        
        try workflow.addNode("agent_1") { state in
            try await Task.sleep(nanoseconds: 500_000_000)
            return ["messages": "message1"]
        }
        try workflow.addNode("agent_2") { state in
            try await Task.sleep(nanoseconds: 500_000_000)
            return ["messages": ["message2", "message3"] ]
        }
        try workflow.addNode("agent_3") { state in
            try await Task.sleep(nanoseconds: 500_000_000)
            return ["result": state.messages?.count ?? 0]
        }

        try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")
        try workflow.addEdge(sourceId: "agent_2", targetId: "agent_3")

        try workflow.addEdge(sourceId: START, targetId: "agent_1")
        try workflow.addEdge(sourceId: "agent_3", targetId: END)

        let app = try workflow.compile()
            
        let task = Task {
                    
            return try await app.stream( .args([ : ]) ).reduce([] as [String]) { partialResult, output in
                
                print( "-------------")
                print( "Agent Output of \(output.node)" )
                print( output.state )
                print( "-------------")
                
                return partialResult + [output.node ]
            }
            
        }
        
        Task {
            try await Task.sleep(nanoseconds: 1_150_000_000) // Sleep for 1/2 second
            task.cancel()
            print("Cancellation requested")
        }
        
        let nodesInvolved = try await task.value
        
        XCTAssertEqual( ["agent_1", "agent_2" ], nodesInvolved)
    }

    
    func testWithSubgraph() async throws {
        
        let childWorkflow = StateGraph( channels: AgentStateWithAppender.schema ) {
            AgentStateWithAppender( $0 )
        }
        
        try childWorkflow.addNode("child:agent_1") { state in
            ["messages": "child::message1"]
        }
        try childWorkflow.addNode("child:agent_2") { state in
            ["messages": ["child::message2"] ]
        }
        try childWorkflow.addNode("child:agent_3") { state in
            ["messages": "child::message3", "result": state.messages?.count ?? 0]
        }

        try childWorkflow.addEdge(sourceId: "child:agent_1", targetId: "child:agent_2")
        try childWorkflow.addEdge(sourceId: "child:agent_2", targetId: "child:agent_3")

        try childWorkflow.addEdge(sourceId: START, targetId: "child:agent_1")
        try childWorkflow.addEdge(sourceId: "child:agent_3", targetId: END)


        let workflowParent = StateGraph( channels: AgentStateWithAppender.schema ) {
            AgentStateWithAppender( $0 )
        }
        
        try workflowParent.addNode("agent_1") { state in
            ["messages": "parent:message1"]
        }
        try workflowParent.addNode("agent_2") { state in
            ["messages": ["parent:message2", "parent:message2.1"] ]
        }
        try workflowParent.addNode("agent_3") { state in
            ["messages": "parent::message3", "result": state.messages?.count ?? 0]
        }
        try workflowParent.addNode("subgraph", subgraph: childWorkflow.compile())

        try workflowParent.addEdge(sourceId: "agent_1", targetId: "agent_2")
        try workflowParent.addEdge(sourceId: "agent_2", targetId: "subgraph")
        try workflowParent.addEdge(sourceId: "subgraph", targetId: "agent_3")

        try workflowParent.addEdge(sourceId: START, targetId: "agent_1")
        try workflowParent.addEdge(sourceId: "agent_3", targetId: END)

        let app = try workflowParent.compile()
                
        let initValue:( lastState:AgentStateWithAppender?, nodesInvolved:[String]) = ( nil, [] )
        
        let result =
            try await app.stream( .args([ : ]) ).reduce( initValue, { partialResult, output in
                                    
                    print( "-------------")
                    print( "Agent Output of \(output.node)" )
                    print( output.state )
                    print( "-------------")

                return ( output.state,  partialResult.1 + [output.node ] )
            })
        
        XCTAssertEqual( ["agent_1",
                         "agent_2",
                         "child:agent_1",
                         "child:agent_2",
                         "child:agent_3",
                         "subgraph",
                         "agent_3"],
                        result.nodesInvolved)
        XCTAssertNotNil(result.lastState )
        XCTAssertEqual( 6, result.lastState!.value("result") )
        XCTAssertNotNil(result.lastState!.messages )
        XCTAssertEqual( 7, result.lastState!.messages!.count )
        XCTAssertEqual( ["parent:message1",
                         "parent:message2",
                         "parent:message2.1",
                            "child::message1",
                            "child::message2",
                            "child::message3",
                         "parent::message3"],
                        result.lastState!.messages)
}

@Test("Codable State Data")
func testCodableStateData() async throws {
    
    let state: [String: Any] = [
        "name": "Alice",
        "age": 30,
        "metadata": ["active": true, "tags": ["swift", "ios"]] as [String: Any],
        "invalid": URLSession.shared // non-Encodable
    ]
    
    let data = try encodeStateData(encoder: JSONEncoder(), state: state )
    
    let decodedState = try decodeStateData(decoder: JSONDecoder(), from: data)
    
    #expect(decodedState.count == state.count - 1)
    #expect(decodedState["name"] as? String == "Alice")
    #expect(decodedState["age"] as? Int == 30)
    #expect(decodedState["invalid"]  == nil)
    let metadata = (decodedState["metadata"] as? [String: Any])
    #expect( metadata != nil)
    #expect( metadata!.count  == 2)
    #expect( metadata!["active"] as? Bool  == true)
    #expect( (metadata!["tags"] as? [String]) == ["swift", "ios"])


}

@Test
func testRunningWithCheckpoint() async throws {
    let saver = MemoryCheckpointSaver()
    
    let workflow = StateGraph { BinaryOpState($0) }
    
    try workflow.addNode("agent_1") { state in
        print( "agent_1", state )
        return ["add1": 37]
    }
    try workflow.addNode("agent_2") { state in
        print( "agent_2", state )
        return ["add2": 10]
    }
    try workflow.addNode("sum") { state in
        print( "sum", state )
        guard let add1 = state.add1, let add2 = state.add2 else {
            throw CompiledGraphError.executionError("agent state is not valid! expect 'add1', 'add2'")
        }
        
        return ["result": add1 + add2 ]
    }

    try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")
    try workflow.addEdge(sourceId: "agent_2", targetId: "sum")

    try workflow.addEdge( sourceId: START, targetId: "agent_1")
    try workflow.addEdge(sourceId: "sum", targetId: END )
    
    let app = try workflow.compile( config: CompileConfig(checkpointSaver: saver) )
    
    let runnableConfig = RunnableConfig()
    
    let initValue:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )
    
    let result = try await app.stream( .args([:]), config: runnableConfig ).reduce( initValue, { partialResult, output in
        
        print( output )
        
        return ( output.state,  partialResult.1 + [output.node ] )
    })
    
    #expect( dictionaryOfAnyEqual(  ["add1": 37, "add2": 10, "result":  47 ],
                                    result.lastState!.data) )


    #expect( saver.list(config: runnableConfig).count == 4 )
    
    saver.list(config: runnableConfig).forEach { print( $0 ) }
    
    let lastCheckpoint = saver.last(config: runnableConfig)
    
    #expect( lastCheckpoint?.nodeId == "sum" )
    #expect( lastCheckpoint?.nextNodeId == END )

}

@Test
func testRunningWithInterruption() async throws {
    // Create a memory-based checkpoint saver
    let saver = MemoryCheckpointSaver()
    
    // Build the workflow with an initial state
    let workflow = try StateGraph { BinaryOpState($0) }
    
    // Add node "agent_1" that returns "add1": 37
    .addNode("agent_1") { state in
        print( "agent_1", state )
        return ["add1": 37]
    }
    // Add node "agent_2" that returns "add2": 10
    .addNode("agent_2") { state in
        print( "agent_2", state )
        return ["add2": 10]
    }
    // Add node "sum" that sums add1 and add2
    .addNode("sum") { state in
        print( "sum", state )
        guard let add1 = state.add1, let add2 = state.add2 else {
            throw CompiledGraphError.executionError("agent state is not valid! expect 'add1', 'add2'")
        }
        return ["result": add1 + add2 ]
    }
    // Define the edges between nodes
    .addEdge(sourceId: "agent_1", targetId: "agent_2")
    .addEdge(sourceId: "agent_2", targetId: "sum")
    .addEdge( sourceId: START, targetId: "agent_1")
    .addEdge(sourceId: "sum", targetId: END )
    
    // Compile the workflow, instructing it to interrupt before executing "sum"
    let app = try workflow.compile( config: CompileConfig(checkpointSaver: saver, interruptionsBefore: ["sum"]) )
    
    let runnableConfig = RunnableConfig()
    
    let initValue:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )
    
    // Start workflow execution — it will stop before running "sum"
    let result = try await app.stream( .args([:]), config: runnableConfig ).reduce( initValue, { partialResult, output in
        print( output )
        return ( output.state,  partialResult.1 + [output.node ] )
    })
    
    // Verify that "add1" and "add2" are present but not "result"
    #expect( dictionaryOfAnyEqual( ["add1": 37, "add2": 10], result.lastState!.data ) )

    // Check number of checkpoints saved
    #expect( saver.list(config: runnableConfig).count == 3 )
    
    saver.list(config: runnableConfig).forEach { print( $0 ) }
    
    // Retrieve last checkpoint and verify its position
    let lastCheckpoint = try #require( saver.last(config: runnableConfig) )
    #expect( lastCheckpoint.nodeId == "agent_2" )
    #expect( lastCheckpoint.nextNodeId == "sum" )

    // Resume from last checkpoint and complete execution
    let runnableConfig2 = runnableConfig.with { $0.checkpointId = lastCheckpoint.id }
    let initValue2:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )
    let result2 = try await app.stream( .resume, config: runnableConfig2 ).reduce( initValue2, { partialResult, output in
        print( output )
        return ( output.state,  partialResult.1 + [output.node ] )
    })

    // Verify that "result" has now been computed
    #expect( dictionaryOfAnyEqual(  ["add1": 37, "add2": 10, "result":  47 ],
                                    result2.lastState!.data) )
    
    // Release the checkpoint to clean up
    try saver.release(config: runnableConfig2)

    // Start a new run in a different thread
    let runnableConfig3 = RunnableConfig( threadId: "T1" )
    let initValue3:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )
    let result3 = try await app.stream( .args([:]), config: runnableConfig3 ).reduce( initValue3, { partialResult, output in
        print( output )
        return ( output.state,  partialResult.1 + [output.node ] )
    })

    // This run is also interrupted before "sum"
    #expect( dictionaryOfAnyEqual(  ["add1": 37, "add2": 10,  ],
                                    result3.lastState!.data) )
    
    // Resume the third run with updated state: change add2 from 10 to 13
    let lastCheckpoint4 = try #require( saver.last(config: runnableConfig3) )
    var runnableConfig4 = runnableConfig3.with { $0.checkpointId = lastCheckpoint4.id }
    runnableConfig4 = try await app.updateState(config: runnableConfig4, values: ["add2": 13] )
    
    // Resume and complete execution with updated value
    let initValue4:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )
    let result4 = try await app.stream( .resume, config: runnableConfig4 ).reduce( initValue4, { partialResult, output in
        print( output )
        return ( output.state,  partialResult.1 + [output.node ] )
    })
    
    // Verify that "result" now reflects the updated input
    #expect( dictionaryOfAnyEqual(  ["add1": 37, "add2": 13, "result": 50 ],
                                    result4.lastState!.data) )
}



