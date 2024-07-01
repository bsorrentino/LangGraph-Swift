import XCTest
@testable import LangGraph


// XCTest Documentation
// https://developer.apple.com/documentation/xctest

// Defining Test Cases and Test Methods
// https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
final class LangGraphTests: XCTestCase {
    

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
            if let value1 = value as? (any AppendableValueProtocol) {
                if value1.array.count == values2.count {
                    for ( v1, v2) in zip(value1.array, values2) {
                        return compareAsEquatable( v1, v2 )
                    }
                }

            }
        }
        return false
    }
    
    func assertDictionaryOfAnyEqual( _ expected: [String:Any], _ current: [String:Any] ) {
        XCTAssertEqual(current.count, expected.count, "the dictionaries have different size")
        for (key, value) in current {
            
            XCTAssertTrue( compareAsEquatable(value, expected[key]!) )
            
        }

    }
    func testValidation() async throws {
            
        let workflow = StateGraph { BaseAgentState() }
        
        XCTAssertThrowsError( try workflow.compile() ) {error in 
            print( error )
            XCTAssertTrue(error is GraphStateError, "\(error) is not a GraphStateError")
        }
        
        try workflow.setEntryPoint("agent_1")

        XCTAssertThrowsError( try workflow.compile() ) {error in
            print( error )
            XCTAssertTrue(error is GraphStateError, "\(error) is not a GraphStateError")
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
            XCTAssertTrue(error is GraphStateError, "\(error) is not a GraphStateError")
        }
        
        XCTAssertThrowsError(try workflow.addEdge(sourceId: "agent_1", targetId: "agent_2")) { error in
            
            XCTAssertTrue(error is GraphStateError, "\(error) is not a GraphStateError")
            if case GraphStateError.duplicateEdgeError(let msg) = error {
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
            XCTAssertTrue(error is GraphStateError, "\(error) is not a GraphStateError")
            if case GraphStateError.missingNodeReferencedByEdge(let msg) = error {
               print( "EXCEPTION:", msg )
            }
            else {
                XCTFail( "exception is not expected 'duplicateEdgeError'")
            }

        }
        
        XCTAssertThrowsError(
            try workflow.addConditionalEdge(sourceId: "agent_1", condition:{ _ in return "agent_3"}, edgeMapping: [:])
        ) { error in
            
            XCTAssertTrue(error is GraphStateError, "\(error) is not a GraphStateError")
            if case GraphStateError.edgeMappingIsEmpty = error {
               print( "EXCEPTION:", error  )
            }
            else {
                XCTFail( "exception is not expected 'duplicateEdgeError'")
            }

        }
        
    }

    func testRunningOneNode() async throws {
            
        let workflow = StateGraph { BaseAgentState() }
        try workflow.setEntryPoint("agent_1")
        try workflow.addNode("agent_1") { state in
            
            print( "agent_1", state )
            return ["prop1": "test"]
        }
        
        try workflow.addEdge(sourceId: "agent_1", targetId: END)
        
        let app = try workflow.compile()
        
        let result = try await app.invoke(inputs: [ "input": "test1"] )
        
        let expected = ["prop1": "test", "input": "test1"]
        assertDictionaryOfAnyEqual( expected, result.data )
        
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

    func testRunningTreeNodes() async throws {
            
        let workflow = StateGraph { BinaryOpState() }
        
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

        try workflow.setEntryPoint("agent_1")
        workflow.setFinishPoint("sum")

        let app = try workflow.compile()
        
        let result = try await app.invoke(inputs: [ : ] )
        
        assertDictionaryOfAnyEqual( ["add1": 37, "add2": 10, "result":  47 ], result.data )

    }

    func testRunningFourNodesWithCondition() async throws {
            
        let workflow = StateGraph { BinaryOpState() }
        
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
        
        try workflow.setEntryPoint("agent_1")

        let app = try workflow.compile()
        
        let resultMul = try await app.invoke( inputs: [ "op": "mul" ] )
        
        assertDictionaryOfAnyEqual(["op": "mul", "add1": 37, "add2": 10, "result": 370 ], resultMul.data)
        
        let resultAdd = try await app.invoke( inputs: [ "op": "sum" ] )
        
        assertDictionaryOfAnyEqual(["op": "sum", "add1": 37, "add2": 10, "result": 47 ], resultAdd.data)
    }

    struct AgentStateWithAppender : AgentState {
        var data: [String : Any]
        
        init() {
            self.init( ["messages": AppendableValue<String>()] )
        }
        
        init(_ initState: [String : Any]) {
            data = initState
        }
        var messages:[String]? {
           appendableValue("messages")
        }
    }

    func testAppender() async throws {
            
        let workflow = StateGraph { AgentStateWithAppender() }
        
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

        try workflow.setEntryPoint("agent_1")
        workflow.setFinishPoint("agent_3")

        let app = try workflow.compile()
        
        let result = try await app.invoke(inputs: [ : ] )
        
        print( result.data )
        assertDictionaryOfAnyEqual( ["messages": [ "message1", "message2", "message3"], "result":  3 ], result.data )

    }

    func testWithStream() async throws {
            
        let workflow = StateGraph { AgentStateWithAppender() }
        
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

        try workflow.setEntryPoint("agent_1")
        workflow.setFinishPoint("agent_3")

        let app = try workflow.compile()
                
        let nodesInvolved =
            try await app.stream(inputs: [:] ).reduce([] as [String]) { partialResult, output in
                                    
                    print( "-------------")
                    print( "Agent Output of \(output.node)" )
                    print( output.state )
                    print( "-------------")

                    return partialResult + [output.node ]
            }
        
        XCTAssertEqual( ["agent_1", "agent_2", "agent_3"], nodesInvolved)
    }

    func testWithStreamAnCancellation() async throws {
            
        let workflow = StateGraph { AgentStateWithAppender() }
        
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

        try workflow.setEntryPoint("agent_1")
        workflow.setFinishPoint("agent_3")

        let app = try workflow.compile()
            
        let task = Task {
                    
            return try await app.stream(inputs: [:] ).reduce([] as [String]) { partialResult, output in
                
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

}
